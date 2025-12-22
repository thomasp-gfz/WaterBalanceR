# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

#' Processes downloaded csv-files from using DownloadRaindancer() to a shapefile. The resulting shapefile is being updated every time, this script is being run.
#' @param sourcepath Path (string) to Firefox download folder. Look it up in your Firefox browser.
#' @param targetpath Path (string) to destination folder for downloaded csv-files from Raindancer.
#' @param start_date You need to define a start date (default: 1st Jan of recent year)
#' @param nozzle_diameter diameter of nozzle in mm (string, e.g. 17_8 = 17.8 mm). Default is "25_4".
#' @param target_crs target crs
#' @return A shapefile, that contains all irrigation events, that were download. The shapefile is being opdated every time this script is being run, as long as all configuration parameter stay the same.
#' @export

### 1. Read coordinate logs (Koordinatenprotokolle) and process them ----
DownloadRaindancerCombineCharts=function(sourcepath=NA,
                                         targetpath=NA,
                                         start_date=paste(substr(Sys.Date(),1,4),"-01-01",sep=""),
                                         nozzle_diameter="25_4",
                                         target_crs=32633){
  # Store current wd and restore on exit
  oldwd <- getwd()
  on.exit(setwd(oldwd))

  # List timestamped subfolders produced by DownloadRaindancer()
  date_folders=dir(sourcepath)
  # Load nozzle pressure→radius lookup (from package extdata) based on nozzle_diame
  buffer_dist=system.file("extdata", paste("Nelson_SR50_Nozzle_",nozzle_diameter,"_irrigation_radius.csv",sep=""), package="WaterBalanceR", mustWork=TRUE)
  buffer_dist=utils::read.csv(buffer_dist,header=T,sep=",")

  # Load pressure/speed→application table (mm) for given nozzle_diameter
  irrigation_chart_file_path=system.file("extdata", paste("Nelson_SR50_Nozzle_",nozzle_diameter,"_irrigation_tab.csv",sep=""), package="WaterBalanceR", mustWork=TRUE)
  irrigation_chart=utils::read.csv(irrigation_chart_file_path,header=T,sep=",")
  rownames(irrigation_chart)=irrigation_chart[,1]
  irrigation_chart=irrigation_chart[,-1]
  colnames(irrigation_chart)=as.character(c(10:60))

  # Identify application protocol files (Einsatzprotokoll) in the newest run folder
  my_files_application_protocol=dir(paste(sourcepath,max(date_folders),sep=""))
  application_protocol_file=my_files_application_protocol[grepl("Einsatzprotokoll",my_files_application_protocol)]

  # Prepare container for all coordinate tables across all runs
  coord_tab_all=list(NA)

  # Iterate over each timestamped folder (each scraping run)
  for (j in 1:length(date_folders)){
    my_files=dir(paste(sourcepath,date_folders[j],sep=""))

    # Filter coordinate protocol Excel files
    coord_protocols=my_files[grepl("Koordinatenprotokoll",my_files)]
    coord_protocols_tab=as.data.frame(matrix(NA,length(coord_protocols),3))
    names(coord_protocols_tab)=c("Protocol","Sprinkler Name","Date_Time")

    # Parse filename components: protocol id, sprinkler name, timestamp
    coord_protocols_tab[,1]=substr(coord_protocols,1,20)
    coord_protocols_tab[,2]=substr(coord_protocols,22,nchar(coord_protocols)-23)
    coord_protocols_tab[,3]=as.POSIXct(strptime(substr(coord_protocols,nchar(coord_protocols)-21,nchar(coord_protocols)-5),"%Y-%m-%d_%H%M%S" ))

    coord_tab=list(NA)
    message("Loading Excel Files...")

    # Read each coordinate protocol and attach meta fields
    for(i in 1:nrow(coord_protocols_tab)){ #i = sprinkler
      coord_tab_temp=readxl::read_excel(paste(sourcepath,date_folders[j],"/",coord_protocols[i],sep=""),.name_repair = "unique_quiet") |>
        janitor::clean_names()
      coord_tab_temp$sprinkler=coord_protocols_tab[i,2]
      coord_tab_temp$date_time=coord_protocols_tab[i,3]
      coord_tab_temp$site=NA

      # Remove records with no deployment / no transmission; keep only bar >= 1
      coord_tab_temp=subset(coord_tab_temp,coord_tab_temp$status!="Regner hat keinen Einsatz")
      coord_tab_temp=subset(coord_tab_temp,coord_tab_temp$status!="Regner sendet nicht mehr")
      coord_tab_temp=subset(coord_tab_temp,coord_tab_temp$bar>=1)

      # Parse timestamps and apply start_date filter
      coord_tab_temp$zeitpunkt=as.POSIXct(coord_tab_temp$zeitpunkt, format = "%d.%m.%Y %H:%M:%OS")
      coord_tab_temp=subset(coord_tab_temp,coord_tab_temp$zeitpunkt>=start_date)

      # Read the corresponding application protocol (Einsatzprotokoll) for mapping to "site"
      application_protocol=readxl::read_excel(paste(sourcepath,max(date_folders),"/",application_protocol_file[i],sep=""),.name_repair = "unique_quiet")

      # Match each coordinate row to a site (field) if its timestamp falls within a protocol window (± 480s)
      for(k in 1:nrow(coord_tab_temp)){#k = coordinate table
        for(l in 1:nrow(application_protocol)){#l = application protocol
          if(nrow(application_protocol)>0){#only calculate, when there is at least one irrigation event
            if(is.na(application_protocol$Endzeit[l])==TRUE){#If latest irrigation has not finished yet, complete chart with recent time
              application_protocol$Endzeit[l]=Sys.time()
            }
            if(nrow(coord_tab_temp)>0){
              if(coord_tab_temp$zeitpunkt[k]<=(application_protocol$Endzeit[l]+480) & coord_tab_temp$zeitpunkt[k]>=(application_protocol$Startzeit[l]-480)){
                coord_tab_temp$site[k]=application_protocol$`Schlag/Gasse`[l]
              }
            }
          }
        }
      }
      coord_tab[[i]]=coord_tab_temp
    }
    coord_tab_all[[j]]=coord_tab
  }

  # Bind all coordinate records from all runs into one big table
  coord_tab_all_bound=as.data.frame(do.call(rbind.data.frame,do.call(c, coord_tab_all)))

  # Keep distinct rows across key fields
  coord_tab_all_bound_distinct=dplyr::distinct(coord_tab_all_bound,
                                               coord_tab_all_bound$breitengrad,
                                               coord_tab_all_bound$langengrad,
                                               coord_tab_all_bound$zeitpunkt,
                                               coord_tab_all_bound$sprinkler,
                                               coord_tab_all_bound$site,
                                               coord_tab_all_bound$bar,
                                               coord_tab_all_bound$status)

  # Rename columns to ASCII-friendly names
  colnames(coord_tab_all_bound_distinct)=c("Breitengrad",
                                           "Laengengrad",
                                           "Zeitpunkt",
                                           "Sprinkler",
                                           "Site",
                                           "Bar",
                                           "Status")

  # Drop any remaining NA rows
  coord_tab_all_bound_distinct=stats::na.omit(coord_tab_all_bound_distinct)

  # One table per site (field)
  unique_sites=unique(coord_tab_all_bound_distinct$Site)

  site_irrigation=list(NA)
  if(nrow(coord_tab_all_bound_distinct)==0){
    stop("No irrigation data available, because no irrigation was set up, yet. Stopping script here.")
  } else {
    for (i in 1:length(unique_sites)){
      site_irrigation[[i]]=subset(coord_tab_all_bound_distinct,coord_tab_all_bound_distinct$Site==unique_sites[i])
    }
    names(site_irrigation)=unique_sites

    # Save RData snapshot grouped by site (for provenance)
    save(site_irrigation,file=paste(targetpath,substr(Sys.time(),1,10),"_irrigation_by_site_",start_date,".RData",sep=""))

    ##################################
    # Prepare multiple parallel data containers for raw vs. filtered vs. interpolated series
    site_irrigation_2=site_irrigation
    site_irrigation_2_new=list(NA)
    site_irrigation_2_orig=list(NA)
    site_irrigation_2_new_interp=list(NA)
    site_irrigation_2_orig_interp=list(NA)
    site_irrigation_2_orig_na_omit=list(NA)
    site_irrigation_2_new_interp_na_omit=list(NA)

    csv_list=list(NA)
    csv_list_new=list(NA)
    csv_list_new_orig=list(NA)
    csv_list_new_interp=list(NA)
    csv_list_new_interp_na_omit=list(NA)
    csv_list_new_interp_na_omit_shapes_32633=list(NA)
    csv_list_new_orig_shapes_32633=list(NA)

    Buffer_36m=list(NA)
    Buffer_36m_orig=list(NA)
    Buffer_36m_all_shp=list(NA)
    Buffer_36m_orig_all_shp=list(NA)

    # Process each site separately
    for (i in 1:length(site_irrigation)){
      # Initialize distance column (repeated lines retained as-is)
      site_irrigation_2[[i]]$entfernung=NA
      site_irrigation_2[[i]]$entfernung=NA
      site_irrigation_2[[i]]$entfernung=NA

      # Reverse time order (most recent first → earliest first or vice versa)
      site_irrigation_2[[i]]=site_irrigation_2[[i]][nrow(site_irrigation_2[[i]]):1,]

      # Normalize decimal separators in coordinates
      site_irrigation_2[[i]]$Laengengrad=gsub(",", ".", site_irrigation_2[[i]]$Laengengrad)#Replace , by .
      site_irrigation_2[[i]]$Breitengrad=gsub(",", ".", site_irrigation_2[[i]]$Breitengrad)#Replace , by .

      # Prepare moving-average (filter) placeholders
      site_irrigation_2[[i]]$Laengengrad_mean=NA
      site_irrigation_2[[i]]$Breitengrad_mean=NA
      site_irrigation_2[[i]]$Druck_mean=NA
      site_irrigation_2[[i]]$Datum_Uhrzeit_mean=NA

      # 5-point moving average over windows of 20 observations (centered)
      if (nrow(site_irrigation_2[[i]])>=20){
        j=5
        j_min=j-4
        j_max=j+4#5
        for (k in 1:floor(nrow(site_irrigation_2[[i]])/5)){
          site_irrigation_2[[i]]$Laengengrad_mean[j]=mean(as.numeric(site_irrigation_2[[i]]$Laengengrad[j_min:j_max]),na.rm=T)
          site_irrigation_2[[i]]$Breitengrad_mean[j]=mean(as.numeric(site_irrigation_2[[i]]$Breitengrad[j_min:j_max]),na.rm=T)
          site_irrigation_2[[i]]$Druck_mean[j]=mean(as.numeric(site_irrigation_2[[i]]$Bar[j_min:j_max]),na.rm=T)
          site_irrigation_2[[i]]$Datum_Uhrzeit_mean[j]=as.character(mean(site_irrigation_2[[i]]$Zeitpunkt[j_min:j_max],na.rm=T))
          site_irrigation_2[[i]]$Datum_Uhrzeit_mean=as.POSIXct(strptime(site_irrigation_2[[i]]$Datum_Uhrzeit_mean,"%Y-%m-%d %H:%M:%S" ))
          j=j+5
          j_min=j-4
          j_max=j+4#5
        }

        # Ensure POSIXct after loop
        site_irrigation_2[[i]]$Datum_Uhrzeit_mean=as.POSIXct(strptime(site_irrigation_2[[i]]$Datum_Uhrzeit_mean,"%Y-%m-%d %H:%M:%S" ))

        # Flip a matrix horizontally, if necessary
        if(site_irrigation_2[[i]]$Zeitpunkt[1]>site_irrigation_2[[i]]$Zeitpunkt[length(site_irrigation_2[[i]]$Zeitpunkt)]){
          site_irrigation_2[[i]]=site_irrigation_2[[i]][nrow(site_irrigation_2[[i]]):1,]
        }

        # Split into filtered vs. original frames
        site_irrigation_2_new[[i]]=stats::na.omit(site_irrigation_2[[i]][,9:12])
        site_irrigation_2_orig[[i]]=site_irrigation_2[[i]][,1:7]

        # Compute time deltas (minutes) between successive filtered timestamps
        site_irrigation_2_new[[i]]$timedif=NA
        for (j in 1:(nrow(site_irrigation_2_new[[i]])-1)){
          site_irrigation_2_new[[i]]$timedif[j+1]=(site_irrigation_2_new[[i]]$Datum_Uhrzeit_mean[j+1]-site_irrigation_2_new[[i]]$Datum_Uhrzeit_mean[j])/60
        }

        # Compute time deltas (minutes) for original series
        site_irrigation_2_orig[[i]]$timedif=NA
        for (j in 1:(nrow(site_irrigation_2_orig[[i]])-1)){
          site_irrigation_2_orig[[i]]$timedif[j+1]=(site_irrigation_2_orig[[i]]$Zeitpunkt[j+1]-site_irrigation_2_orig[[i]]$Zeitpunkt[j])/60
        }

        # Distance between successive filtered GPS points (m)
        site_irrigation_2_new[[i]]$dist_gps=NA
        for (j in 1:(nrow(site_irrigation_2_new[[i]])-1)){
          site_irrigation_2_new[[i]]$dist_gps[j+1]=geosphere::distm(c(site_irrigation_2_new[[i]]$Laengengrad[j], site_irrigation_2_new[[i]]$Breitengrad[j]),c(site_irrigation_2_new[[i]]$Laengengrad[j+1], site_irrigation_2_new[[i]]$Breitengrad[j+1]), fun = geosphere::distGeo)
        }
        site_irrigation_2_new[[i]]$geschwindigkeit_gps=site_irrigation_2_new[[i]]$dist_gps/site_irrigation_2_new[[i]]$timedif

        # Distance/speed for original series
        site_irrigation_2_orig[[i]]$dist_gps=NA #for original Data
        for (j in 1:(nrow(site_irrigation_2_orig[[i]])-1)){
          site_irrigation_2_orig[[i]]$dist_gps[j+1]=geosphere::distm(c(site_irrigation_2_orig[[i]]$Laengengrad[j], site_irrigation_2_orig[[i]]$Breitengrad[j]),c(site_irrigation_2_orig[[i]]$Laengengrad[j+1], site_irrigation_2_orig[[i]]$Breitengrad[j+1]), fun = geosphere::distGeo)
        }
        site_irrigation_2_orig[[i]]$geschwindigkeit_gps=site_irrigation_2_orig[[i]]$dist_gps/site_irrigation_2_orig[[i]]$timedif

        # Compute application depth (mm) from pressure & speed using lookup (filtered data)
        site_irrigation_2_new[[i]]$Beregnungshoehe_GPS=NA #for interpolated data
        for (j in 1:nrow(site_irrigation_2_new[[i]])){
          if (is.na(site_irrigation_2_new[[i]]$geschwindigkeit_gps[j])==F & site_irrigation_2_new[[i]]$geschwindigkeit_gps[j]>=10 & as.numeric(site_irrigation_2_new[[i]]$Druck_mean[j])>=3.5){
            geschwindigkeit_gerundet=round(site_irrigation_2_new[[i]]$geschwindigkeit_gps[j])
            druck=round(as.numeric(site_irrigation_2_new[[i]]$Druck_mean[j]),1)
            help_beregnung=as.numeric(irrigation_chart[druck==as.numeric(rownames(irrigation_chart)),geschwindigkeit_gerundet==as.numeric(colnames(irrigation_chart))])
            site_irrigation_2_new[[i]]$Beregnungshoehe_GPS[j]=ifelse(length(help_beregnung)==1,help_beregnung,NA)
          }
        }

        # Same application depth computation for original series (with bounds checks)
        site_irrigation_2_orig[[i]]$Beregnungshoehe_GPS=NA #for original Data
        for (j in 1:nrow(site_irrigation_2_orig[[i]])){
          if (is.na(site_irrigation_2_orig[[i]]$geschwindigkeit_gps[j])==F){
            if(site_irrigation_2_orig[[i]]$geschwindigkeit_gps[j]>=10 &
               site_irrigation_2_orig[[i]]$geschwindigkeit_gps[j]<=60 &
               site_irrigation_2_orig[[i]]$geschwindigkeit_gps[j]!=Inf &
               as.numeric(site_irrigation_2_orig[[i]]$Bar[j])>=3.5){
              geschwindigkeit_gerundet=round(site_irrigation_2_orig[[i]]$geschwindigkeit_gps[j])
              druck=round(as.numeric(site_irrigation_2_orig[[i]]$Bar[j]),1)
              help_beregnung=as.numeric(irrigation_chart[druck==as.numeric(rownames(irrigation_chart)),geschwindigkeit_gerundet==as.numeric(colnames(irrigation_chart))])
              site_irrigation_2_orig[[i]]$Beregnungshoehe_GPS[j]=ifelse(length(help_beregnung)==1,help_beregnung,NA)
            }
          }
        }

        # Cumulative distance along track (filtered)
        site_irrigation_2_new[[i]]$Distanz_kum=NA #for interpolated data
        site_irrigation_2_new[[i]]$Distanz_kum[2]=site_irrigation_2_new[[i]]$dist_gps[2]
        for (j in 3:nrow(site_irrigation_2_new[[i]])){
          site_irrigation_2_new[[i]]$Distanz_kum[j]=site_irrigation_2_new[[i]]$Distanz_kum[j-1]+site_irrigation_2_new[[i]]$dist_gps[j]
        }

        # Cumulative distance (original)
        site_irrigation_2_orig[[i]]$Distanz_kum=NA #for original Data
        site_irrigation_2_orig[[i]]$Distanz_kum[2]=site_irrigation_2_orig[[i]]$dist_gps[2]
        for (j in 3:nrow(site_irrigation_2_orig[[i]])){
          site_irrigation_2_orig[[i]]$Distanz_kum[j]=site_irrigation_2_orig[[i]]$Distanz_kum[j-1]+site_irrigation_2_orig[[i]]$dist_gps[j]
        }

        # Build interpolation skeleton: insert 4 NAs between each record (5× upsampling)
        site_irrigation_2_new_interp[[i]]=as.data.frame(matrix(NA,nrow(site_irrigation_2_new[[i]])*5,ncol(site_irrigation_2_new[[i]])))
        colnames(site_irrigation_2_new_interp[[i]])=colnames(site_irrigation_2_new[[i]])
        j=1
        for (k in 1:nrow(site_irrigation_2_new[[i]])){
          site_irrigation_2_new_interp[[i]][j,]=site_irrigation_2_new[[i]][k,]
          j=j+5
        }

        # Fill the inserted NAs linearly (no-NA method across moving segments)
        m=6
        n=11
        for (k in 1:nrow(site_irrigation_2_new_interp[[i]])){
          for (j in 1:ncol(site_irrigation_2_new_interp[[i]])){
            if (is.na(site_irrigation_2_new_interp[[i]][m,j])==F & is.na(site_irrigation_2_new_interp[[i]][n,j])==F){
              site_irrigation_2_new_interp[[i]][m:n,j]=stats::approx(site_irrigation_2_new_interp[[i]][m:n,j],n=6)$y
            }}
          m=m+5
          n=n+5
        }

        # Ensure POSIXct time for interpolated series
        site_irrigation_2_new_interp[[i]]$Datum_Uhrzeit_mean=as.POSIXct(site_irrigation_2_new_interp[[i]]$Datum_Uhrzeit_mean,origin = '1970-01-01')

        # Drop rows with remaining NAs
        site_irrigation_2_new_interp_na_omit[[i]]=stats::na.omit(site_irrigation_2_new_interp[[i]])

        # Convert filtered-interpolated points → sf, set WGS84, then transform to target CRS
        csv_list_new_interp_na_omit_shapes_32633[[i]]=sf::st_as_sf(site_irrigation_2_new_interp_na_omit[[i]], coords = c("Laengengrad_mean", "Breitengrad_mean"), crs = 4326)
        sf::st_crs(csv_list_new_interp_na_omit_shapes_32633[[i]])=4326
        csv_list_new_interp_na_omit_shapes_32633[[i]]=sf::st_transform(csv_list_new_interp_na_omit_shapes_32633[[i]],target_crs)

        # Original (raw) positions → sf, WGS84 → target CRS
        site_irrigation_2_orig_na_omit[[i]]=subset(site_irrigation_2_orig[[i]],is.na(site_irrigation_2_orig[[i]]$Laengengrad)==F & is.na(site_irrigation_2_orig[[i]]$Breitengrad)==F &site_irrigation_2_orig[[i]]$Laengengrad != "" & site_irrigation_2_orig[[i]]$Breitengrad != "")
        csv_list_new_orig_shapes_32633[[i]]=sf::st_as_sf(site_irrigation_2_orig_na_omit[[i]], coords = c("Laengengrad", "Breitengrad"), crs = 4326)
        sf::st_crs(csv_list_new_orig_shapes_32633[[i]])=4326
        csv_list_new_orig_shapes_32633[[i]]=sf::st_transform(csv_list_new_orig_shapes_32633[[i]],target_crs)

        # Build variable-radius buffers around interpolated points using pressure→radius lookup
        Buffer_36m[[i]]=csv_list_new_interp_na_omit_shapes_32633[[i]]
        ###
        Druck_mean=round(Buffer_36m[[i]]$Druck_mean,1)
        Druck_mean[Druck_mean<3.5]=3.5
        Druck_mean[Druck_mean>6]=6
        buffer_dist_num=NA
        for (k in 1:length(Druck_mean)){
          buffer_dist_num[k]=buffer_dist$irrigation_radius[buffer_dist$water_pressure==Druck_mean[k]]
        }

        Buffer_36m[[i]]=sf::st_buffer(Buffer_36m[[i]], dist = buffer_dist_num)
        ###

        # Compute DOY from interpolated timestamps
        Buffer_36m[[i]]$DOY=lubridate::yday(as.POSIXct(strptime(Buffer_36m[[i]]$Datum_Uhrzeit_mean,"%Y-%m-%d %H:%M:%S" )))

        # Annotate field name on each geometry (interpolated)
        for (j in 1:length(Buffer_36m)){
          if(is.null(Buffer_36m[[j]])==F){
            if(length(Buffer_36m[[j]])>1){
              if(nrow(Buffer_36m[[j]])>0){
                Buffer_36m[[j]]$Schlag=names(site_irrigation_2)[[i]]
              }
            }
          }
        }

        # Same variable-radius buffering for original points using Bar column
        Buffer_36m_orig[[i]]=csv_list_new_orig_shapes_32633[[i]]
        ###
        Druck_mean=round(Buffer_36m_orig[[i]]$Bar,1)
        Druck_mean[Druck_mean<3.5]=3.5
        Druck_mean[Druck_mean>6]=6
        buffer_dist_num=NA
        for (k in 1:length(Druck_mean)){
          buffer_dist_num[k]=buffer_dist$irrigation_radius[buffer_dist$water_pressure==Druck_mean[k]]
        }

        Buffer_36m_orig[[i]]=sf::st_buffer(Buffer_36m_orig[[i]], dist = buffer_dist_num)

        ###

        # DOY from original timestamps
        Buffer_36m_orig[[i]]$DOY=lubridate::yday(as.POSIXct(strptime(Buffer_36m_orig[[i]]$Zeitpunkt,"%Y-%m-%d %H:%M:%S" )))

        # Annotate field name on each original geometry
        for (j in 1:length(Buffer_36m_orig)){
          if(is.null(Buffer_36m_orig[[j]])==F){
            if(length(Buffer_36m_orig[[j]])>1){
              if(nrow(Buffer_36m_orig[[j]])>0){
                Buffer_36m_orig[[j]]$Schlag=names(site_irrigation_2)[[i]]
              }
            }
          }
        }

        # Convert to Spatial for rbind later (interpolated)
        if(nrow(Buffer_36m[[i]])>0){
          Buffer_36m_all_shp[[i]]=methods::as(Buffer_36m[[i]], 'Spatial')
        }

        # Convert to Spatial for rbind later (original)
        if(nrow(Buffer_36m_orig[[i]])>0){
          Buffer_36m_orig_all_shp[[i]]=methods::as(Buffer_36m_orig[[i]], 'Spatial')
        }
      }
    }

    # Merge all site lists into single Spatial* objects (interpolated)

    Buffer_36m_all_shp_2 = Filter(function(y) {
      if (is.null(y) || length(y) == 0) return(FALSE)
      if (isS4(y)) return(TRUE)
      if (is.atomic(y) || is.list(y)) return(!all(is.na(y)))
      TRUE
    }, Buffer_36m_all_shp)

    Buffer_36m_all_shp_2=do.call(rbind,Buffer_36m_all_shp_2)

    # Merge all site lists into single Spatial* objects (original)
    Buffer_36m_orig_all_shp_2 = Filter(function(y) {
      if (is.null(y) || length(y) == 0) return(FALSE)
      if (isS4(y)) return(TRUE)
      if (is.atomic(y) || is.list(y)) return(!all(is.na(y)))
      TRUE
    }, Buffer_36m_orig_all_shp)

    Buffer_36m_orig_all_shp_2=do.call(rbind,Buffer_36m_orig_all_shp_2)

    # Ensure output directory exists
    # (targetpath is the folder where final shapefiles will be written)
    if(dir.exists(file.path(paste(targetpath,sep="")))==F){
      dir.create(file.path(paste(targetpath,sep="")), showWarnings = FALSE, recursive=TRUE)
    }

    # Write both interpolated and original buffers as ESRI Shapefiles
    setwd(paste(targetpath,sep=""))
    suppressWarnings(sf::st_write(sf::st_as_sf(Buffer_36m_orig_all_shp_2), paste(targetpath,"Buffer_36m_all_orig.shp",sep=""), driver = 'ESRI Shapefile', layer = 'Buffer_36m_all_orig', overwrite_layer = T,append=FALSE))
    suppressWarnings(sf::st_write(sf::st_as_sf(Buffer_36m_all_shp_2), paste(targetpath,"Buffer_36m_all_interp.shp",sep=""), driver = 'ESRI Shapefile', layer = 'Buffer_36m_all_interp', overwrite_layer = T,append=FALSE))

  }
}





