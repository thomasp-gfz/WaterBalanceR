# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

#' Downloads daily precipitation data (RADOLAN) from DWD OpenData for a
#' given AOI and time span. Depending on the date range, it uses either
#' the "recent" or "historical" RADOLAN archives. Data are clipped to the
#' AOI and saved as shapefiles, one per day of year (DOY).
#' @param target_path Path to download and save shapefile for every DOY within timespan of interest
#' @param target_site Path to shapefile containing your AOI (string).
#' @param start_date start date of interest (e.g.: "2021-01-01"). If empty, default is 1st Jan of recent year.
#' @param end_date end date of interest (e.g.: "2021-12-31"). If empty, default is yesterday.
#' @return Shapefiles for every DOY containing precipitation data for your AOI.
#' @export

DownloadRadolanFromDWD=function(target_path = NA,
                          target_site=NA,
                          start_date=NA,
                          end_date=NA){
  # Quiet mode for rdwd package and set timeout for downloads
  options(rdwdquiet=TRUE)
  options(timeout = 3000)

  # Default start: 1st January of current year
  if (is.na(start_date)==T){
  start_date=paste(substr(Sys.Date(),1,4),"-01","-01",sep="")
  }

  # Default end: yesterday
  if (is.na(end_date)==T){
  end_date=Sys.Date()-1
  }

  # Create output directory if not existing
  if(dir.exists(file.path(target_path))==F){
    dir.create(file.path(target_path), showWarnings = FALSE, recursive=TRUE)
  }

  # Case 1: Current year data from "recent" RADOLAN archive
  if(substr(start_date,1,4)==substr(Sys.Date(),1,4) & substr(end_date,1,4)==substr(Sys.Date(),1,4)){
    m=50
    # Loop over years (2-digit), months, days, and fixed hour (23 UTC)
    for (i in as.numeric(substr(start_date,3,4)):as.numeric(substr(end_date,3,4))){
      for (j in as.numeric(substr(start_date,6,7)):as.numeric(substr(end_date,6,7))){
        for(k in 1:as.numeric(lubridate::days_in_month(as.Date(paste(as.numeric(substr(start_date,1,2)),"-",formatC(j, width = 2, format = "d", flag = "0"),"-01",sep=""))))){
          for (l in 23){
            # Build filename for daily RADOLAN binary
            filename=paste("raa01-sf_10000-",
                           i,
                           formatC(j, width = 2, format = "d", flag = "0"),
                           formatC(k, width = 2, format = "d", flag = "0"),
                           formatC(l, width = 2, format = "d", flag = "0"),
                           m,
                           "-dwd---bin.gz",
                           sep="")
            tf=paste(target_path,filename,sep="")

            # Download file from "recent" RADOLAN archive
            try(utils::download.file(paste("https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/radolan/recent/bin/",filename,sep=""), tf))

            # Read and reproject RADOLAN raster to AOI CRS
            read_dwd_raster=rdwd::projectRasterDWD(rdwd::readDWD(tf)$dat,targetproj=terra::crs(paste("epsg:",substr(sf::st_crs(target_site)[[2]],nchar(sf::st_crs(target_site)[[2]])-6,nchar(sf::st_crs(target_site)[[2]])-2),sep=""), describe=FALSE))

            # Crop raster to AOI
            read_dwd_raster=terra::crop(read_dwd_raster,target_site,snap="out")

            # If raster dimension is not 3 (width/height mismatch), aggregate
            if(sum(dim(read_dwd_raster))!=3){
              read_dwd_raster=terra::aggregate(read_dwd_raster)
            }

            # Compute day-of-year string
            doy=formatC(lubridate::yday(paste(substr(start_date,1,4),"-",
                                              formatC(j, width = 2, format = "d", flag = "0"),"-",
                                              formatC(k, width = 2, format = "d", flag = "0"),sep="")), width = 3, format = "d", flag = "0")

            # Save daily raster as shapefile
            sf::st_write(sf::st_as_sf(methods::as(raster::raster(read_dwd_raster),'SpatialPolygonsDataFrame')),paste(target_path,"Radolan_",substr(start_date,1,4),"_",doy,".shp",sep=""),delete_layer=T)

            # Remove temporary download and decompressed file
            file.remove(tf)
            file.remove(substr(tf,1,(nchar(tf)-3)))
          }
        }
      }
    }

    # Case 2: Historical data, same start and end year, URL exists
    } else if(substr(start_date,1,4)<=substr(Sys.Date(),1,4) & substr(end_date,1,4)<=substr(Sys.Date(),1,4) & substr(start_date,1,4)==substr(end_date,1,4) & RCurl::url.exists(paste("https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/radolan/historical/bin/",as.numeric(substr(start_date,1,4)),"/",sep=""))==TRUE){
        for (i in as.numeric(substr(start_date,1,4))){
          for (j in as.numeric(substr(start_date,6,7)):as.numeric(substr(end_date,6,7))){
            # Build monthly TAR archive filename
                filename=paste("SF",
                               i,
                               formatC(j, width = 2, format = "d", flag = "0"),
                               ".tar.gz",
                               sep="")
                tf=paste(target_path,filename,sep="")

                # Download monthly archive
                try(utils::download.file(paste("https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/radolan/historical/bin/",as.numeric(substr(start_date,1,4)),"/",filename,sep=""), tf))

                # Read and reproject
                read_dwd_raster=rdwd::projectRasterDWD(rdwd::readDWD(tf)$dat,targetproj=terra::crs(paste("epsg:",substr(sf::st_crs(target_site)[[2]],nchar(sf::st_crs(target_site)[[2]])-6,nchar(sf::st_crs(target_site)[[2]])-2),sep=""), describe=FALSE))

                # Crop raster
                read_dwd_raster=terra::crop(read_dwd_raster,target_site,snap="out")

                if(sum(dim(read_dwd_raster))!=3){
                  read_dwd_raster=terra::aggregate(read_dwd_raster)
                }

                # Iterate over layers in the monthly stack
                for (k in 1:terra::nlyr(read_dwd_raster)){
                  ref_date=paste(substr(names(read_dwd_raster)[k],1,4),"-",
                                 substr(names(read_dwd_raster)[k],6,7),"-",
                                 substr(names(read_dwd_raster)[k],9,10),sep="")

                  # Keep only daily layers at 23 UTC within date range
                  if(substr(names(read_dwd_raster)[k],12,13)==23 & start_date <= ref_date & end_date >= ref_date){
                    doy=formatC(lubridate::yday(ref_date), width = 3, format = "d", flag = "0")
                    daily_values=sf::st_as_sf(methods::as(raster::raster(read_dwd_raster[[k]]),'SpatialPolygonsDataFrame'))
                    colnames(daily_values)[1]="layer"
                    sf::st_write(daily_values,paste(target_path,"Radolan_",substr(start_date,1,4),"_",doy,".shp",sep=""),delete_layer=T)

                    # Clean up temp files
                    file.remove(tf)
                    unlink(paste(target_path,substr(filename,1,8),sep=""), recursive=TRUE)
                }
          }
          }
      }

      # Case 3: Historical fallback when archive folder not available
    } else if(substr(start_date,1,4)<=substr(Sys.Date(),1,4) & substr(end_date,1,4)<=substr(Sys.Date(),1,4) & substr(start_date,1,4)==substr(end_date,1,4) & RCurl::url.exists(paste("https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/radolan/historical/bin/",as.numeric(substr(start_date,1,4)),"/",sep=""))==FALSE){
      m=50
      # Same nested loop as Case 1, but multiply aggregated raster by 10
      for (i in as.numeric(substr(start_date,3,4)):as.numeric(substr(end_date,3,4))){
        for (j in as.numeric(substr(start_date,6,7)):as.numeric(substr(end_date,6,7))){
          for(k in 1:as.numeric(lubridate::days_in_month(as.Date(paste(as.numeric(substr(start_date,1,2)),"-",formatC(j, width = 2, format = "d", flag = "0"),"-01",sep=""))))){
            for (l in 23){
              filename=paste("raa01-sf_10000-",
                             i,
                             formatC(j, width = 2, format = "d", flag = "0"),
                             formatC(k, width = 2, format = "d", flag = "0"),
                             formatC(l, width = 2, format = "d", flag = "0"),
                             m,
                             "-dwd---bin.gz",
                             sep="")
              tf=paste(target_path,filename,sep="")
              try(utils::download.file(paste("https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/radolan/recent/bin/",filename,sep=""), tf))
              #read_dwd_raster=rdwd::projectRasterDWD(rdwd::readDWD(tf)$dat,targetproj=terra::crs(target_site))
              read_dwd_raster=rdwd::projectRasterDWD(rdwd::readDWD(tf)$dat,targetproj=terra::crs(paste("epsg:",substr(sf::st_crs(target_site)[[2]],nchar(sf::st_crs(target_site)[[2]])-6,nchar(sf::st_crs(target_site)[[2]])-2),sep=""), describe=FALSE))
              read_dwd_raster=terra::crop(read_dwd_raster,target_site,snap="out")

              if(sum(dim(read_dwd_raster))!=3){
                read_dwd_raster=terra::aggregate(read_dwd_raster)*10
              }

              doy=formatC(lubridate::yday(paste(substr(start_date,1,4),"-",
                                                formatC(j, width = 2, format = "d", flag = "0"),"-",
                                                formatC(k, width = 2, format = "d", flag = "0"),sep="")), width = 3, format = "d", flag = "0")
              sf::st_write(sf::st_as_sf(methods::as(raster::raster(read_dwd_raster),'SpatialPolygonsDataFrame')),paste(target_path,"Radolan_",substr(start_date,1,4),"_",doy,".shp",sep=""),delete_layer=T)
              file.remove(tf)
              file.remove(substr(tf,1,(nchar(tf)-3)))
            }
          }
        }
      }
      }else(print("Start year and end year have to be equal."))
}
