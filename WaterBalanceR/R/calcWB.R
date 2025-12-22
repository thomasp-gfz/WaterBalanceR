# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

#' Calculate Water Balance from UAV or PlanateScope NDVI Data
#'
#' Calculate Water Balance using DJI Phantom 4 Multispectral or PlanetScope NDVI data.
#' Reference Evapotranspiration can be used either from German Weather Service (DWD) or Arable Mark 2 ground stations from your site.
#' Precipitation is gathered from either the German Weather Service (DWD) product "RADOLAN" or FURUNO WR 2120, if available.
#' @param mypath Path to your project main folder (string). The main folder needs to contain the subfolders "NDVI_Files" containing your NDVI-files for your AOI.
#' @param shape_site shapefile of AOI (string)
#' @param target_res Resolution of product (integer). Default is 5 m, but can be turned down to at least 3 m.
#' @param last_NDVI_0 Number of day with day (DOI, integer) with NDVI = 0, i.e. last day before germination.
#' @param ET_ref Either csv-file with reference ET for every day of vegetation period or recent date (read.csv(paste(mypath,"/ET0_Arable_2021.csv",sep=""),sep=",")) or leave at NA. When using the list, the first column needs to be ascending numerized (integer) from one on with empty header. The second column contains the reference ET value for the certain DOY (float) with header "V1". The third column needs to be the date (format "YYYY-MM-DD", e.g. "2021-05-01). When left NA (default), the reference ET is automatically downloaded from either German Weather Servcice (DWD, default) or Arable, if you have an account. This decision needs to be made in the next step.
#' @param ET_ref_dl If you do not have any reference ET data, leave "ET_ref" as "NA" and choose here between "DWD" to download from German Weather Service ("DWD") or "Arable" to download from your Arable account ("string"). If you choose to download from your Arable Account, you need to put in your Arable login data.
#' @param output_year Number of year, you are processing (format: "YYYY", e.g. 2021, integer).
#' @param precip_source Choose either "RADOLAN" (default, string) or "FURUNO" (string) depending on the source you would like to use.
#' @param path_WR_precip Choose the path to your precipitation data (string). This should be a folder containing shapefiles with precipitation data for every day during the vegetation period you are interested in. If you leave it an NA (default), precipitation data is downloaded from German Weather Service (DWD).
#' @param irrig_sf Path to shapefile containing the irrigation data (string), e.g. st_read(paste(mypath,"/Shapefile/Buffer_36m_all_interp.shp",sep="")). The shapefile needs to contain the following coloumns: Drck_mn (water pressure, float), Dtm_Uh_ (Date and time, string, format: "YY-MM-DD hh:mm:ss"), timedif (time difference between steps in hours, float), dst_gps (spatial distance between in m the logs of sprinkler, float), gschwn_ (speed of sprinkler in m/s, float), Brg_GPS (irrigation amount, mm, float), Dstnz_k (cumulated spatial distance between logs in m, float), DOY (day of year, integer), geometry (geometric geometry). You can also generate this shapefile by 1st using the function "DownloadRaindancer" to download all of your irrigation data that was logged by raindancer. Take note, that irrigation data can only be downloaded from the last 12 days. So you should downoad regularly. In the 2nd step you can use the function "DownloadRaindancerCombineCharts" to combine the downloaded charts and process them to the needed shapefile. The resulting shapefile is being updated witht every iteration of download.
#' @param irrigation_efficiency Choose irrigation efficiency, float between 0 and 1 (default). Here, irrigation efficiency is meant to be as the fraction of water that was infiltrated in the soil from the amount that was applied.
#' @param save_shape Save results as shapefile? (TRUE or FALSE, default: TRUE)
#' @param save_geotiff Save results as geotiff? (TRUE or FALSE, default: TRUE)
#' @param save_RDATA Save results as RDATA? (TRUE or FALSE, default: TRUE)
#' @param arable_user Your user name for your Arable account (string). Only necessary, if you chose "ET_ref_dl" with "Arable". Else: leave at NA.
#' @param arable_pass Your password for your Arable account (string). Only necessary, if you chose "ET_ref_dl" with "Arable". Else: leave at NA.
#' @return Shapefiles, Geotiffs and/or RDATA-files with maps showing the water balance
#' @importFrom RCurl getURL
#' @export

# -----------------------------------------------------------------------------
# calcWB(): Main driver to compute daily and cumulative water balance layers
# from NDVI (UAV/Planet/S2), reference ET (DWD/Arable), precipitation (RADOLAN
# or FURUNO), and optional irrigation shapefile. Outputs (optionally) GeoTIFFs,
# shapefiles, and an .RData bundle. Uses a linear (or polynomial) NDVI->Kc
# relationship and pixel-wise water balance: P + Irr - ETc.
# -----------------------------------------------------------------------------

calcWB=function(mypath,
                shape_site=NA,
                target_res=5,
                last_NDVI_0=NA,
                ET_ref=NA,
                ET_ref_dl="DWD",
                output_year=NA,
                precip_source=precip_source,
                path_WR_precip=NA,
                irrig_sf=NA,
                irrigation_efficiency=1,
                save_shape=TRUE,
                save_geotiff=TRUE,
                save_RDATA=TRUE,
                arable_user=NA,
                arable_pass=NA){

  start.time = Sys.time() # For simple runtime logging

  oldwd <- getwd()
  on.exit(setwd(oldwd))

  target_res=target_res # Explicitly keep target_res as given
  NDVI_List=list.files(paste(mypath,"/NDVI_Files/",sep=""),pattern = "\\.tif$")
  if(any(substr(NDVI_List,10,13)=="Sen2")){
    # Sentinel-2 limitation: native 10 m; enforce 10 m target resolution if S2 is present
    warning("Sentinel-2 images cannot be processed with a resolution of res < 10 m. Target resolution was set to target_res = 10")
    target_res=10
  }
  # Extract DOY from first 8 chars (YYYYMMDD) of filename
  DOY=lubridate::yday(as.POSIXct(strptime(substr(NDVI_List,1,8),"%Y%m%d" )))

  #### 1.create empty lists ----
  # Containers for intermediate rasters/polygons by DOY index
  originals=list(NA)
  plot_list=list(NA)
  cropped=vector(mode="list",length=max(DOY))
  subsetted=vector(mode="list",length=max(DOY))
  subsetted_resampled=vector(mode="list",length=max(DOY))
  aggregated=vector(mode="list",length=max(DOY))
  aggregated_cropped=vector(mode="list",length=max(DOY))
  aggregated_cropped_subsetted=vector(mode="list",length=max(DOY))
  subsetted_aggregated=list(NA)

  message("1. create empty lists done - loading tiffs")

  #### 2. read or calculate NDVI data, rsp. ----
  # Loads NDVI per source:
  # - P4M1 (UAV): direct single-band NDVI GeoTIFF
  # - Plan(et): compute NDVI from band 8 (NIR) and band 6 (red)
  # - Sen2: direct NDVI raster (assumed precomputed)

  setwd(paste(mypath,"/NDVI_Files/",sep=""))
  for (i in 1:length(NDVI_List)){
    if(substr(NDVI_List[[i]],10,13)=="P4M1"){
      originals[[DOY[i]]]=raster::raster(NDVI_List[[i]])
      originals[[DOY[i]]]@data@names=as.character(DOY[i])
    } else if (substr(NDVI_List[[i]],10,13)=="Plan"){
      raster_help_red=raster::raster(NDVI_List[[i]],band = 6)
      raster_help_nir=raster::raster(NDVI_List[[i]],band = 8)
      raster_help_NDVI=(raster_help_nir-raster_help_red)/(raster_help_nir+raster_help_red)
      originals[[DOY[i]]]=raster_help_NDVI
      originals[[DOY[i]]]@data@names=as.character(DOY[i])
    }  else if (substr(NDVI_List[[i]],10,13)=="Sen2"){
      originals[[DOY[i]]]=raster::raster(NDVI_List[[i]])
      originals[[DOY[i]]]@data@names=as.character(DOY[i])
    }
  }

  message("2. Load tiff files as raster done - cropping and resampling...")

  #### 3. resample rasters to site outlines, crop, mask and resample ----
  # Align all NDVI rasters to AOI (crop + mask), then temporally resample each
  # subsequent day to the grid of the previous day to have a common grid chain.


  # Make target size an sf-object, if it still a character string
  if(inherits(shape_site,"character")==TRUE){
    shape_site=sf::st_read(shape_site)
  }

  for (i in 1:length(DOY)){#Crop and mask to shapefile of AOI
    cropped[[DOY[i]]] = terra::crop(originals[[DOY[i]]],shape_site)
    subsetted[[DOY[i]]] = terra::mask(cropped[[DOY[i]]], shape_site)
  }

  subsetted_resampled=subsetted
  for(i in 1:(length(DOY)-1)){#resampling
    subsetted_resampled[[DOY[i+1]]]=terra::resample(subsetted_resampled[[DOY[i+1]]], subsetted_resampled[[DOY[i]]], method='bilinear')
  }

  message("3. Crop, mask and resampling to site outlines done - aggregating files to target resolution...")

  #### 4. Aggregation of tiff files ----
  # Aggregate to target_res using factor relative to current pixel size, re-crop/mask to AOI

  for (i in 1:length(DOY)){
    aggregated[[DOY[i]]]=terra::aggregate(subsetted_resampled[[DOY[i]]],fact=target_res/raster::res(subsetted_resampled[[DOY[i]]]))
    aggregated_cropped[[DOY[i]]] = terra::crop(aggregated[[DOY[i]]],shape_site)
    aggregated_cropped_subsetted[[DOY[i]]] = terra::mask(aggregated_cropped[[DOY[i]]], shape_site)
    aggregated_cropped[[DOY[i]]]=NA # Free intermediate to save memory
  }

  aggregated_cropped_subsetted_2=aggregated_cropped_subsetted

  message("4. Aggregation of tiff files done - correction of NDVI from UAV/satellite to Arable standard...")

  ### 5. Correction of NDVI from UAV or Planet to Arable standard ----
  # Apply empirical transfer functions to harmonize NDVI to “Arable standard”

  for (i in 1:length(NDVI_List)){
    if(substr(NDVI_List[[i]],10,13)=="P4M1"){
      NDVI_source="UAV"

      #UAV polynomial correction
      aggregated_cropped_subsetted_2[[DOY[i]]]=
        (2.12664*aggregated_cropped_subsetted[[DOY[i]]]^3)-
        (3.79245*aggregated_cropped_subsetted[[DOY[i]]]^2)+
        (2.74967*aggregated_cropped_subsetted[[DOY[i]]])-
        0.10009
    } else if(substr(NDVI_List[[i]],10,13)=="Plan"){
      NDVI_source="Planet"

      # Planet quartic correction
      aggregated_cropped_subsetted_2[[DOY[i]]]=
        -1*(9.0673*aggregated_cropped_subsetted[[DOY[i]]]^4)+
        (21.7178*aggregated_cropped_subsetted[[DOY[i]]]^3)-
        (18.7474*aggregated_cropped_subsetted[[DOY[i]]]^2)+
        (7.7683*aggregated_cropped_subsetted[[DOY[i]]])-
        0.8181
    } else if(substr(NDVI_List[[i]],10,13)=="Sen2"){
      NDVI_source="Sen2"

      # Sentinel-2 quadratic correction
      aggregated_cropped_subsetted_2[[DOY[i]]]=
        (-0.987607*aggregated_cropped_subsetted[[DOY[i]]]^2)+
        (1.838723*aggregated_cropped_subsetted[[DOY[i]]])-
        0.001855
    }
  }

  message("5. Correction of NDVI from UAV or Planet to Arable standard done - interpolating cropped NDVI-sets and saving daily values...")

  #### 6. Interpolation of cropped NDVI-sets and saving of daily values ----
  # Create a daily NDVI stack (1..max(DOY)); fill observed days, set others to NA,
  # set pre-germination (last_NDVI_0 and before) to 0, then interpolate time series.

  aggregated_cropped_subsetted_3=unlist(aggregated_cropped_subsetted_2[[DOY[1]]])
  raster::values(aggregated_cropped_subsetted_3)=NA
  aggregated_cropped_subsetted_4 = sapply(1:max(DOY), function(...) aggregated_cropped_subsetted_3)

  for(i in 1:length(aggregated_cropped_subsetted_4)){
    if(is.element(i,DOY)==TRUE){
      aggregated_cropped_subsetted_4[[i]]=raster::setValues(aggregated_cropped_subsetted_3,raster::values(aggregated_cropped_subsetted_2[[i]]))
    }
  }

  # Initialize day of NDVI=0 (pre-germination)
  aggregated_cropped_subsetted_4[[last_NDVI_0]]=aggregated_cropped_subsetted_4[[DOY[1]]]
  for(i in 1:length(aggregated_cropped_subsetted_4[[last_NDVI_0]]@data@values)){
    if(is.na(aggregated_cropped_subsetted_4[[last_NDVI_0]]@data@values[i])==F){
      aggregated_cropped_subsetted_4[[last_NDVI_0]]@data@values[i]=0
    }
  }

  # Fill all preceding days with 0 as well
  for(i in 1:(last_NDVI_0-1)){
    aggregated_cropped_subsetted_4[[i]]=aggregated_cropped_subsetted_4[[last_NDVI_0]]
  }

  # Force two sentinel pixels (1=1, 2=0) to prevent edge-case interpolation issues
  for(i in 1:length(aggregated_cropped_subsetted_4)){
    aggregated_cropped_subsetted_4[[i]]@data@values[1]=1
    aggregated_cropped_subsetted_4[[i]]@data@values[2]=0
  }

  aggregated_cropped_subsetted_5 <- raster::stack(aggregated_cropped_subsetted_4)
  NDVI <- raster::approxNA(aggregated_cropped_subsetted_5)#NDVI Subset

  for(i in 1:DOY[length(DOY)]){
    NDVI[[i]]@data@values[1]=NA
    NDVI[[i]]@data@values[2]=NA
  }

  message("6. Interpolation of cropped NDVI-sets and saving of daily values done - derive reference ET...")

  #### 7. derive ET_ref ----
  # Load ET0 either from provided table (first col dummy index, second ET0, third Date)
  # or download via DWD/Arable. Convert Date column to DOY and keep ET0 + DOY.
  # NOTE: For Arable, requires credentials and correct date range (my_year must exist upstream).
  #ET0 from DWD-Daten

  if(length(ET_ref)!=1){
    ET_ref=ET_ref[,-1]
    ET_ref[,2]=lubridate::yday(ET_ref[,2])
    colnames(ET_ref)=c("ET0","DOY")
    ET0_3=ET_ref
  } else{

    if(ET_ref_dl=="DWD"){
      ET_ref=DownloadET0fromDWD(target_path=mypath,
                                test_site_shp=shape_site,
                                target_year=output_year)
      ET_ref[,2]=lubridate::yday(ET_ref[,2])
      colnames(ET_ref)=c("ET0","DOY")
      ET0_3=ET_ref
    } else if (ET_ref_dl=="Arable"){
      ET0_3=DownloadET0fromArable(user_name=arable_user,
                                  pwd=arable_pass,
                                  start_date=as.Date(paste(output_year,"-",min(DOY,na.rm=T),sep=""), '%Y-%j'),
                                  end_date=as.Date(paste(output_year,"-",max(DOY,na.rm=T),sep=""), '%Y-%j'),
                                  shape_site=shape_site)
    }
  }

  # Fail fast if ET0 data is missing
  if (all(is.na(ET0_3[,1])) ==TRUE){
    stop("No reference ET data available from Arable for your desired timespan. Please choose ET_ref_dl=DWD for configuration.")
  }

  # Clean ET0: replace "NaN" as NA, then linearly interpolate gaps
  ET0_3[ET0_3[,1]=="NaN",1]=NA
  ET0_3[,1]=zoo::na.approx(ET0_3[,1],na.rm=F)

  message("7. derive reference ET done - calculate precipitation...")

  #### 8.1 calculation of precipitation from FURUNO ----
  # Load daily WR polygon layers; if missing day, reuse earliest with zero layer.
  if(precip_source=="furuno"){
    WR_precip_List=list.files(path=path_WR_precip,pattern = "\\.shp$")
    WR_precip=vector(mode='list', length=366)
    precipitation_daily=vector(mode='list', length=366)
    for (i in 1:length(WR_precip)){
      WR_precip[[i]]=NA
      precipitation_daily[[i]]=NA
    }

    for (i in min(substr(WR_precip_List,13,15)):max(substr(WR_precip_List,13,15))){#i=137:237
      WR_precip[[i]]=try(raster::shapefile(paste(path_WR_precip,"/",WR_precip_List[substr(WR_precip_List,13,15)==formatC(i, width = 3, format = "d", flag = "0")],sep="")))
      #if (class(WR_precip[[i]])!="SpatialPolygonsDataFrame"){
      if (inherits(WR_precip[[i]],"SpatialPolygonsDataFrame",TRUE)!=1){
        WR_precip[[i]]=try(raster::shapefile(paste(path_WR_precip,"/",WR_precip_List[substr(WR_precip_List,13,15)==formatC(min(substr(WR_precip_List,13,15)), width = 3, format = "d", flag = "0")],sep="")))
        WR_precip[[i]]@data=data.frame(rep(0,nrow(WR_precip[[i]]@data)))
        names(WR_precip[[i]]@data)="layer"
      }
    }
  }

  #### 8.2 calculation of precipitation from Radolan ----
  # If no path provided, auto-download RADOLAN daily sums for NDVI date range,
  # then load daily shapefiles into list and fill gaps as zero layers when needed.


  if(precip_source=="radolan"){

    if(is.na(path_WR_precip)==TRUE){
      DownloadRadolanFromDWD(target_path=paste(mypath,"/Radolan_",output_year,"_processed_daily/",sep=""),
                             start_date=min(as.POSIXct(strptime(substr(NDVI_List,1,8),"%Y%m%d" )),na.rm=T),
                             end_date=max(as.POSIXct(strptime(substr(NDVI_List,1,8),"%Y%m%d" )),na.rm=T),
                             target_site=shape_site)
      path_WR_precip=paste(mypath,"/Radolan_",output_year,"_processed_daily/",sep="")
    }

    WR_precip_List=list.files(path=path_WR_precip,pattern = "\\.shp$")
    WR_precip=vector(mode='list', length=366)
    precipitation_daily=vector(mode='list', length=366)#
    for (i in 1:length(WR_precip)){
      WR_precip[[i]]=NA
      precipitation_daily[[i]]=NA
    }

    for (i in min(substr(WR_precip_List,14,16)):max(substr(WR_precip_List,14,16))){
      WR_precip[[i]]=try(raster::shapefile(paste(path_WR_precip,"/",WR_precip_List[substr(WR_precip_List,14,16)==formatC(i, width = 3, format = "d", flag = "0")],sep="")))
      #if (class(WR_precip[[i]])!="SpatialPolygonsDataFrame"){
      if (inherits(WR_precip[[i]],"SpatialPolygonsDataFrame",TRUE)!=1){
        WR_precip[[i]]=try(raster::shapefile(paste(path_WR_precip,"/",WR_precip_List[substr(WR_precip_List,14,16)==formatC(min(substr(WR_precip_List,14,16)), width = 3, format = "d", flag = "0")],sep="")))
        WR_precip[[i]]@data=data.frame(rep(0,nrow(WR_precip[[i]]@data)))
        names(WR_precip[[i]]@data)="layer"
      }
    }
  }

  message("8. calculation of precipitation done.")

  #### 9. start WB Model ----
  # Compute daily water balance per pixel:
  # WB = precipitation + irrigation - ETc, with Kc derived from NDVI (linear).

  message("9. start WB Model for doy..")

  aspect_KC=1.493374 # Slope of NDVI->Kc relation
  y_Kc=-0.220506 # Intercept of NDVI->Kc relation

  KC=vector(mode='list', length=max(DOY,na.rm=T))
  WB_daily=list(NA)
  ETC_ND_daily=list(NA)
  irrigation_daily=list(NA)
  ETC_daily=list(NA)
  irrigation=list(NA)

  irrig_sf=sf::st_read(irrig_sf)

  for (i in min(DOY,na.rm=T):max(DOY,na.rm=T)){
    subs_help_DOY=subset(ET0_3,ET0_3$DOY==i) # Daily ET0 for day i
    # Subset irrigation features for day i and neighbors (account for spillover)
    subs_beregnung=raster::subset(irrig_sf,irrig_sf$DOY==i)
    subs_beregnung2=raster::subset(irrig_sf,irrig_sf$DOY==(i+1))
    subs_beregnung0=raster::subset(irrig_sf,irrig_sf$DOY==(i-1))
    # Convert NDVI raster to polygons for pixel-wise vector operations
    aggregated_cropped_subsetted_10=sf::st_as_sf(methods::as(NDVI[[i]],'SpatialPolygonsDataFrame'))
    aggregated_cropped_subsetted_10_ETC=sf::st_as_sf(methods::as(NDVI[[i]],'SpatialPolygonsDataFrame'))

    message(i)

    # Rasterize precipitation layer onto NDVI grid (handle projection & extent)
    r_hr <- raster::raster(nrow=nrow(NDVI[[i]]), ncol=ncol(NDVI[[i]]))
    terra::crs(r_hr) <- terra::crs(NDVI[[i]])
    r_hr@extent <- raster::extent(NDVI[[i]])
    if(names(WR_precip[[i]]@data)!="layer"){names(WR_precip[[i]]@data)="layer"}
    rast_res <- terra::rasterize(WR_precip[[i]],r_hr,field="layer")
    if(precip_source=="furuno"){
      crop <- terra::crop(rast_res, NDVI[[i]],snap="out")
    }
    if(precip_source=="radolan"){
      crop <- terra::crop(rast_res, NDVI[[i]])
    }
    precipitation_daily[[i]] <- terra::mask(crop, NDVI[[i]])

    # Compute WB driver: if precip = 0, WB = -ETc; else WB = P - ETc
    if(mean(WR_precip[[i]]@data$layer,na.rm=T)==0){
      aggregated_cropped_subsetted_9_help=((aspect_KC*(NDVI[[i]])+y_Kc)*subs_help_DOY[1,1])*(-1)
    } else{ aggregated_cropped_subsetted_9_help=precipitation_daily[[i]]+(((aspect_KC*(NDVI[[i]])+y_Kc)*subs_help_DOY[1,1])*(-1))
    }

    # Convert back to polygon for writing; store daily WB and ETc layers
    aggregated_cropped_subsetted_10=sf::st_as_sf(methods::as(aggregated_cropped_subsetted_9_help,'SpatialPolygonsDataFrame'))
    colnames(aggregated_cropped_subsetted_10)[1]=paste("X139.",i,sep="")

    aggregated_cropped_subsetted_10_ETC[[1]]=((aspect_KC*(aggregated_cropped_subsetted_10_ETC[[1]])+y_Kc)*subs_help_DOY[1,1])*(-1)#nur ETC
    KC[[i]]=sf::st_as_sf(methods::as(NDVI[[i]],'SpatialPolygonsDataFrame'))
    KC[[i]][[1]]=aspect_KC*KC[[i]][[1]]+y_Kc
    WB_daily[[i]]=aggregated_cropped_subsetted_10
    ETC_ND_daily[[i]]=aggregated_cropped_subsetted_10
    ETC_daily[[i]]=aggregated_cropped_subsetted_10_ETC
    # Add irrigation if present (current day; consider adjacent days to avoid double counting)
    if(length(subs_beregnung$DOY)!=0){#If there is an irrigation event on this day...
      for (j in 1:nrow(aggregated_cropped_subsetted_10)){#...check for every pixel, if...
        if(length(sf::st_intersects(aggregated_cropped_subsetted_10[j,],sf::st_as_sf(subs_beregnung))[[1]])!=0){#...on this day for this pixel there is an irrigation event
          if(length(sf::st_intersects(aggregated_cropped_subsetted_10[j,],sf::st_as_sf(subs_beregnung2))[[1]])!=0){#...and if there is an irrigation event on the following day.
            intersec=sf::st_intersects(aggregated_cropped_subsetted_10[j,],sf::st_as_sf(subs_beregnung))#overlapping points of pixel with irrigation radius for this day
            intersec2=sf::st_intersects(aggregated_cropped_subsetted_10[j,],sf::st_as_sf(subs_beregnung2))#overlapping points of pixel with irrigation radius for the following day
            aggregated_cropped_subsetted_10[j,][[1]]=aggregated_cropped_subsetted_10[j,][[1]]+mean(c(sf::st_as_sf(subs_beregnung)[intersec[[1]],]$Brg_GPS,sf::st_as_sf(subs_beregnung2)[intersec2[[1]],]$Brg_GPS),na.rm=T)*irrigation_efficiency#Berechne Mittlwert der Beregnung auf dieses Pixel von diesem und n?chsten Tag
          }else{#But if there is an irrigation event only today and not tomorrow...
            if(length(sf::st_intersects(aggregated_cropped_subsetted_10[j,],sf::st_as_sf(subs_beregnung0))[[1]])==0){#...check if there was an irrigation on yesterday
              intersec=sf::st_intersects(aggregated_cropped_subsetted_10[j,],sf::st_as_sf(subs_beregnung))#overlapping points of pixel with irrigation radius from today
              aggregated_cropped_subsetted_10[j,][[1]]=aggregated_cropped_subsetted_10[j,][[1]]+mean(sf::st_as_sf(subs_beregnung)[intersec[[1]],]$Brg_GPS,na.rm=T)*irrigation_efficiency#Calculate irrigation amount for this pixel for today
            }
          }
        }
      }

      WB_daily[[i]]=aggregated_cropped_subsetted_10
      irrigation_daily[[i]]=WB_daily[[i]]
      irrigation_daily[[i]][[1]]=irrigation_daily[[i]][[1]] - ETC_ND_daily[[i]][[1]]
      ETC_daily[[i]]=aggregated_cropped_subsetted_10_ETC
    }
  }

  message("9 WB modelling done.")

  # List with irrigation amounts
  # Recompute irrigation component as WB - ETc to ensure consistency
  irrigation_daily=WB_daily
  for (i in min(DOY,na.rm=T):max(DOY,na.rm=T)){
    irrigation_daily[[i]][[1]]=WB_daily[[i]][[1]] - ETC_ND_daily[[i]][[1]]
  }

  #### 10. cumulating daily values ----
  # Create cumulative sums over time for WB, ETc+precipitation, irrigation, ETc, and precipitation.

  message("10. Cumulating daily values to latest date...")

  WB_cumulated=WB_daily
  ETC_ND_cumulated=ETC_ND_daily
  irrigation_cumulated=irrigation_daily
  ETC_cumulated=ETC_daily
  precipitation_cumulated=precipitation_daily
  for (i in (1+min(DOY,na.rm=T)):max(DOY,na.rm=T)){
    WB_cumulated[[i]][[1]]=WB_cumulated[[i]][[1]]+WB_cumulated[[i-1]][[1]]
    WB_cumulated[[i]]$doy=i
    ETC_ND_cumulated[[i]][[1]]=ETC_ND_cumulated[[i]][[1]]+ETC_ND_cumulated[[i-1]][[1]]
    ETC_ND_cumulated[[i]]$doy=i
    irrigation_cumulated[[i]][[1]]=irrigation_cumulated[[i]][[1]]+irrigation_cumulated[[i-1]][[1]]
    irrigation_cumulated[[i]]$doy=i
    ETC_cumulated[[i]][[1]]=ETC_cumulated[[i]][[1]]+ETC_cumulated[[i-1]][[1]]
    ETC_cumulated[[i]]$doy=i

    # Handle missing precip rasters by carrying the first valid raster
    #if(class(precipitation_cumulated[[i]])[1]!="RasterLayer"){
    if (inherits(precipitation_cumulated[[i]],"RasterLayer",TRUE)!=1){
      precipitation_cumulated[[i]]=precipitation_cumulated[[min(DOY,na.rm=T)]]
    }

    precipitation_cumulated[[i]][[1]]=sum(precipitation_cumulated[[i]][[1]],precipitation_cumulated[[i-1]][[1]],na.rm=T)
    precipitation_cumulated[[i]][[1]]$doy=i
  }

  # Standardize attribute names for downstream writers
  colnames(WB_daily[[i]])[1]="values"
  colnames(ETC_ND_daily[[i]])[1]="values"
  colnames(irrigation_daily[[i]])[1]="values"
  colnames(ETC_daily[[i]])[1]="values"
  colnames(WB_cumulated[[i]])[1]="values"
  colnames(ETC_ND_cumulated[[i]])[1]="values"
  colnames(irrigation_cumulated[[i]])[1]="values"
  colnames(ETC_cumulated[[i]])[1]="values"
  precipitation_cumulated[[i]][[1]]@data@names="values"
  colnames(KC[[i]])[1]="values"
  NDVI[[i]]@data@names="values"
  precipitation_daily[[i]]@data@names="values"

  message("10 cumulating daily values to latest date - done")

  #### 11. save as GeoTIFF ----
  # Write per-DOY GeoTIFFs for WB, ETc+precipitation, Irrigation, ETc, their cumulative versions,
  # Kc, cumulative precipitation, NDVI, and daily precipitation. Organized in subfolders.

  message("11. saving as GeoTIFF...")

  if(save_geotiff==TRUE){
    for (i in min(DOY,na.rm=T):max(DOY,na.rm=T)){

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_waterbalance_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_waterbalance_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_waterbalance_DOY"))
      stars::write_stars(stars::st_rasterize(WB_daily[[i]],dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2]), paste("waterbalance_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_precip_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_precip_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_precip_DOY"))
      stars::write_stars(stars::st_rasterize(ETC_ND_daily[[i]],dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2]), paste("ETc_precip_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_Irrigation_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_Irrigation_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_Irrigation_DOY"))
      stars::write_stars(stars::st_rasterize(irrigation_daily[[i]],dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2]), paste("Irrigation_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_DOY"))
      stars::write_stars(stars::st_rasterize(ETC_daily[[i]],dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2]), paste("ETc_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_waterbalance_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_waterbalance_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_waterbalance_cumulated_DOY"))
      stars::write_stars(stars::st_rasterize(WB_cumulated[[i]],dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2])[1], paste("waterbalance_cumulated_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_precip_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_precip_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_precip_cumulated_DOY"))
      stars::write_stars(stars::st_rasterize(ETC_ND_cumulated[[i]],dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2])[1], paste("ETc_precip_cumulated_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_Irrigation_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_Irrigation_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_Irrigation_cumulated_DOY"))
      stars::write_stars(stars::st_rasterize(irrigation_cumulated[[i]],dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2])[1], paste("Irrigation_cumulated_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_ETc_cumulated_DOY"))
      stars::write_stars(stars::st_rasterize(ETC_cumulated[[i]],dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2])[1], paste("ETc_cumulated_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_Kc_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_Kc_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_Kc_DOY"))
      stars::write_stars(stars::st_rasterize(KC[[i]],dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2]), paste("Kc_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_precipitation_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_precipitation_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_precipitation_cumulated_DOY"))
      stars::write_stars(stars::st_rasterize(sf::st_as_sf(methods::as(precipitation_cumulated[[i]],"SpatialPolygonsDataFrame")),dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2])[1], paste("precipitation_cumulated_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_NDVI_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_NDVI_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_NDVI_DOY"))
      stars::write_stars(stars::st_rasterize(sf::st_as_sf(methods::as(NDVI[[i]],"SpatialPolygonsDataFrame")),dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2]), paste("NDVI_DOY_",i,".tif",sep=""))

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_precipitation_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_precipitation_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "geotiff_precipitation_DOY"))
      stars::write_stars(stars::st_rasterize(sf::st_as_sf(methods::as(precipitation_daily[[i]],"SpatialPolygonsDataFrame")),dx=raster::res(aggregated[[length(aggregated)]])[1],dy=raster::res(aggregated[[length(aggregated)]])[2]), paste("precipitation_DOY_",i,".tif",sep=""))
    }
    message("11 saving as GeoTIFF - done")
    # Inform if exact target resolution could not be achieved
    if(raster::res(aggregated[[length(aggregated)]])[1]!=5 | raster::res(aggregated[[length(aggregated)]])[2]!=5){
      message(paste("Target resolution could not be reached due to small site sample. Resolution is instead: ",raster::res(aggregated[[length(aggregated)]])," m",sep=""))}

  }



  #### 12. Saving as Shapefile ----
  # Write per-DOY shapefiles for the same set of layers as in GeoTIFF outputs.

  message("12. saving as Shapefile...")

  if(save_shape==TRUE){

    for (i in min(DOY,na.rm=T):max(DOY,na.rm=T)){

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_waterbalance_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_waterbalance_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_waterbalance_DOY"))

      sf::st_crs(WB_daily[[i]])=sf::st_crs(shape_site)
      sf::st_write(WB_daily[[i]],paste("waterbalance_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_precip_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_precip_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_precip_DOY"))
      sf::st_crs(ETC_ND_daily[[i]])=sf::st_crs(shape_site)
      sf::st_write(ETC_ND_daily[[i]],paste("ETc_precip_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_Irrigation_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_Irrigation_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_Irrigation_DOY"))
      sf::st_crs(irrigation_daily[[i]])=sf::st_crs(shape_site)
      sf::st_write(irrigation_daily[[i]],paste("Irrigation_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_DOY"))
      sf::st_crs(ETC_daily[[i]])=sf::st_crs(shape_site)
      sf::st_write(ETC_daily[[i]],paste("ETc_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_waterbalance_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_waterbalance_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_waterbalance_cumulated_DOY"))
      sf::st_crs(WB_cumulated[[i]])=sf::st_crs(shape_site)
      sf::st_write(WB_cumulated[[i]],paste("waterbalance_cumulated_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_precip_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_precip_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_precip_cumulated_DOY"))
      sf::st_crs(ETC_ND_cumulated[[i]])=sf::st_crs(shape_site)
      sf::st_write(ETC_ND_cumulated[[i]],paste("ETc_precip_cumulated_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_Irrigation_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_Irrigation_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_Irrigation_cumulated_DOY"))
      sf::st_crs(irrigation_cumulated[[i]])=sf::st_crs(shape_site)
      sf::st_write(irrigation_cumulated[[i]],paste("Irrigation_cumulated_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_ETc_cumulated_DOY"))
      sf::st_crs(ETC_cumulated[[i]])=sf::st_crs(shape_site)
      sf::st_write(ETC_cumulated[[i]],paste("ETc_cumulated_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_Kc_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_Kc_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_Kc_DOY"))
      sf::st_crs(KC[[i]])=sf::st_crs(shape_site)
      sf::st_write(KC[[i]],paste("Kc_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_precipitation_cumulated_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_precipitation_cumulated_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_precipitation_cumulated_DOY"))
      precipitation_cumulated_temp=sf::st_as_sf(methods::as(precipitation_cumulated[[i]],'SpatialPolygonsDataFrame'))
      sf::st_crs(precipitation_cumulated_temp)=sf::st_crs(shape_site)
      sf::st_write(precipitation_cumulated_temp,paste("precipitation_cumulated_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_NDVI_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_NDVI_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_NDVI_DOY"))
      NDVI_temp=sf::st_as_sf(methods::as(NDVI[[i]],'SpatialPolygonsDataFrame'))
      sf::st_crs(NDVI_temp)=sf::st_crs(shape_site)
      sf::st_write(NDVI_temp,paste("NDVI_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)

      if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_precipitation_DOY"))==F){
        dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_precipitation_DOY"), showWarnings = FALSE, recursive=TRUE)
      }
      setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_"), "shp_precipitation_DOY"))
      precipitation_daily_temp=sf::st_as_sf(methods::as(precipitation_daily[[i]],'SpatialPolygonsDataFrame'))
      sf::st_crs(precipitation_daily_temp)=sf::st_crs(shape_site)
      sf::st_write(precipitation_daily_temp,paste("precipitation_DOY_",i,".shp",sep=""),delete_layer=T,quiet = T)
    }
    message("12. saving as Shapefile done - saving .RDATA-file")
    if(raster::res(aggregated[[length(aggregated)]])[1]!=5 | raster::res(aggregated[[length(aggregated)]])[2]!=5){
      message(paste("Target resolution could not be reached due to small site sample. Resolution is instead: ",raster::res(aggregated[[length(aggregated)]])," m",sep=""))}

  }

  if(save_RDATA==TRUE){

    # Ensure parent output folder exists and save a compact .RData bundle for re-use
    if(dir.exists(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_")))==F){
      dir.create(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_")), showWarnings = FALSE, recursive=TRUE)
    }

    setwd(file.path(mypath,paste(precip_source,irrigation_efficiency,last_NDVI_0,target_res,sep="_")))

    save(DOY,
         NDVI,
         KC,
         ETC_daily,
         ETC_cumulated,
         precipitation_daily,
         precipitation_cumulated,
         ETC_ND_daily,
         ETC_ND_cumulated,
         irrigation_daily,
         irrigation_cumulated,
         WB_daily,
         WB_cumulated,
         ET0_3,
         file=paste("WBR_",precip_source,"_",as.character(irrigation_efficiency),"_",as.character(last_NDVI_0),"_",as.character(target_res),".RData",sep=""))
    message("13. Saving .RData-file - done")
  }



  end.time = Sys.time()
  message(paste("All results successfully created. Start Time: ",start.time,", End Time: ",end.time,sep=""))

}
