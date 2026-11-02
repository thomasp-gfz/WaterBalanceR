# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

#' Downloads daily reference evapotranspiration (ET0) grids from the
#' German Weather Service (DWD) open data portal for a given year,
#' extracts the values for a specified AOI (shapefile), and saves
#' the results as a .csv file with daily ET0 values.
#' @param target_path Path to download and save csv-file with reference ET for your AOI and timespan of interest
#' @param test_site_shp Path to shapefile containing your AOI (string).
#' @param target_year year of interest (integer: 2021)
#' @param timeout time out span for downloading data (default: 10000, exceed, if your interconnection is slow)
#' @return chart containing reference evapotranspiration for every DOY during given timespan
#' @export

DownloadET0fromDWD=function(target_path=NA,
                            test_site_shp=NA,
                            target_year=NA,
                            timeout=1000){

  # Store current timeout option and set a new one for the download
  old_to=getOption('timeout')
  on.exit(options(timeout = old_to))
  options(timeout = timeout)

  message("Download ET_ref data from German Weather Service (DWD)...")

  # Load shapefile as sf object if not already
  if(class(test_site_shp)[1]!="sf"){
    test_site_shp=sf::st_read(test_site_shp)
  }

  # Define base directory for DWD open data (FAO evapotranspiration)
  dir_ET_fao="https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/evaporation_fao/"

  # Create local directory to store downloaded file if it does not exist
  if(dir.exists(file.path(target_path,"ET_fao"))==F){
    dir.create(file.path(target_path,"ET_fao"), showWarnings = FALSE, recursive=TRUE)
  }

  # Build filename for requested year and destination path
  filename_fao=paste("grids_germany_daily_evaporation_fao_",target_year,"_v1.1.nc",sep="")
  tf_fao=paste(file.path(target_path,"ET_fao"),"/",filename_fao,sep="")

  # Download NetCDF file from DWD server
  try(utils::download.file(paste(dir_ET_fao,filename_fao,sep=""), tf_fao,mode = 'wb'))

  message("Download successfully finished. Transforming file format from *.nc to *.csv...")

  ### Process downloaded NetCDF into CSV with daily ET0 values for the AOI
  mypath=paste(target_path,"/ET_fao/",sep="")
  nc_List=list.files(path=mypath,pattern = "\\.nc$")
  nc_List=subset(nc_List,substr(nc_List,37,40)==target_year)

  # Initialize objects
  rast_WR=list(NA)
  rast_WR_center=list(NA)
  rast_WR_center_mask=list(NA)
  cropped=list(NA)

  # Detect variable name: sometimes "et0", sometimes "eta_fao"
  #Varname_ET0=ifelse(class(try(as.data.frame(matrix(NA,raster::raster(paste(mypath,nc_List,sep=""),varname="et0")@file@nbands,2)),silent=T))!="try-error","et0","eta_fao")
  Varname_ET0=terra::varnames(terra::rast(paste(mypath,nc_List,sep="")))

  # Create empty data frame to hold ET0 values and dates
  #ET0=as.data.frame(matrix(NA,raster::raster(paste(mypath,nc_List,sep=""),varname=Varname_ET0)@file@nbands,2))
  ET0=as.data.frame(matrix(NA,terra::nlyr(terra::rast(paste(mypath,nc_List,sep=""))),2))

  ### Extract daily ET0 values (FAO56 method) ----
  #for(i in 1:raster::raster(paste(mypath,nc_List,sep="")[1],varname=Varname_ET0)@file@nbands){
  for(i in 1:terra::nlyr(terra::rast(paste(mypath,nc_List,sep="")))){
    # Read raster band for day i
    #rast_WR[[i]]=raster::raster(paste(mypath,nc_List,sep="")[1],varname=Varname_ET0,band=i)
    rast_WR[[i]]=terra::rast(paste(mypath,nc_List,sep=""))[[i]]

    # Extract date for this band
    #ET0[i,2]=as.character(rast_WR[[i]]@z[[1]])
    ET0[i,2]=as.character(terra::time(rast_WR[[i]]))

    # Reproject raster to CRS of shapefile
    #rast_WR[[i]]=raster::projectRaster(rast_WR[[i]],crs=terra::crs(paste("epsg:",substr(sf::st_crs(test_site_shp)[[2]],nchar(sf::st_crs(test_site_shp)[[2]])-6,nchar(sf::st_crs(test_site_shp)[[2]])-2),sep=""), describe=FALSE))
    rast_WR[[i]]=terra::project(rast_WR[[i]],paste0("EPSG:",substr(sf::st_crs(test_site_shp)[[2]],nchar(sf::st_crs(test_site_shp)[[2]])-6,nchar(sf::st_crs(test_site_shp)[[2]])-2)))
    #crs(rast_WR[[i]])=terra::crs(paste("epsg:",substr(sf::st_crs(test_site_shp)[[2]],nchar(sf::st_crs(test_site_shp)[[2]])-6,nchar(sf::st_crs(test_site_shp)[[2]])-2),sep=""), describe=FALSE)

    # Force CRS definition
    terra::crs(rast_WR[[i]])=terra::crs(paste("epsg:",substr(sf::st_crs(test_site_shp)[[2]],nchar(sf::st_crs(test_site_shp)[[2]])-6,nchar(sf::st_crs(test_site_shp)[[2]])-2),sep=""), describe=FALSE)

    # Crop raster to AOI
    cropped[[i]]=terra::crop(rast_WR[[i]],test_site_shp)

    # Compute mean ET0 value within AOI
    #ET0[i,1]=mean(cropped[[i]]@data@values,na.rm=T)
    ET0[i,1]=mean(terra::values(cropped[[i]]),na.rm=T)/10

    # Release memory
    rast_WR[[i]]=NA

    message(paste("Cropping reference ET raster for DOY: ", i, " from ", terra::nlyr(terra::rast(paste(mypath,nc_List,sep=""))), sep=""))
  }

  # Save results as CSV (daily ET0 values + dates)
  utils::write.csv(ET0,paste(file.path(target_path),"/DWD_ET0_",target_year,".csv",sep=""))

  # Delete temporary NetCDF directory
  unlink(mypath,recursive=TRUE)

  # Return ET0 dataframe
  return(ET0)
  message("Fileformat successfully transformed and saved.")
}
