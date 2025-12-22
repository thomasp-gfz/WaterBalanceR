# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

#' Downloads reference evapotranspiration (ET0) from an Arable account and
#' processes the data for a given period. Only devices located within (or
#' inside a 500 m buffer around) the provided shapefile are considered.
#' @param user_name string: "user_name"
#' @param pwd DOY string: "password"
#' @param start_date Start date of download (string: "YYYY-MM-DD")
#' @param end_date End date of download (string: "YYYY-MM-DD")
#' @param shape_site Path to shapefile containing your AOI (string).
#' @return chart containing reference evapotranspiration for every DOY during given timespan
#' @export

DownloadET0fromArable=function(user_name=NA,
                               pwd=NA,
                               start_date=NA,
                               end_date=NA,
                               shape_site=NA){

  # Make target size an sf-object, if it still a character string
  if(inherits(shape_site,"character")==TRUE){
    shape_site=sf::st_read(shape_site)
  }

  ## Request devices from Arable API
  devices=httr::GET("https://api.arable.cloud/api/v2/devices",
                    httr::authenticate(
                      user=user_name,
                      password=pwd,
                      type="basic"
                    ))

  ### Parse device specifications from JSON into a data frame ----
  devices=as.data.frame(jsonlite::fromJSON(httr::content(devices,as="text",encoding="UTF-8")))
  devices$items.name # print device names

  ### Request daily Arable data ----
  daily_Arable_list=list(NA) # store full daily data
  daily_Arable_list_ET0=list(NA) # store only ET0 + coordinates + date
  for (i in 1:length(devices$items.name)){
    # Request daily data from API for each device and date range
    daily_data=httr::GET(paste("https://api.arable.cloud/api/v2/data/daily?device=",devices$items.name[i],"&start_time=",start_date,"&end_time=",end_date,"&limit=10000&temp=C&order=asc&pres=kp&ratio=dec&size=mm&speed=mps&vol=l&volumetric_soil_moisture_unit=millimeter_per_meter",sep=""),
                         httr::authenticate(
                           user=user_name,
                           password=pwd,
                           type="basic"
                         ))

    # Parse JSON into data frame and reorder columns
    daily_Arable_list[[i]]=as.data.frame(jsonlite::fromJSON(httr::content(daily_data,as="text",encoding="UTF-8")))
    daily_Arable_list[[i]]=daily_Arable_list[[i]][,order(names(daily_Arable_list[[i]]))]
    # Extract only ET0, lat, lon, and date
    daily_Arable_list_ET0[[i]]=as.data.frame(cbind(daily_Arable_list[[i]]$et,daily_Arable_list[[i]]$lat,daily_Arable_list[[i]]$long,daily_Arable_list[[i]]$time))
    # Set column names if data are available
    if(nrow(daily_Arable_list_ET0[[i]])>0){
      colnames(daily_Arable_list_ET0[[i]])=c("ET0","lat","lon","date")
    }
  }
  # Assign device names to list elements
  names(daily_Arable_list)=devices$items.name
  names(daily_Arable_list_ET0)=devices$items.name


  ### Prepare list for each date: will contain ET0, date, and device info if inside AOI buffer ----

  diff_date=as.Date(end_date)-as.Date(start_date)
  intersec_points_buff=vector(mode='list', length=as.numeric(diff_date)+1)#create list with

  for(i in 1:length(intersec_points_buff)){
    names(intersec_points_buff)[i]=as.character(as.Date(start_date)+i-1)
    intersec_points_buff[[i]]=as.data.frame(matrix(NA,length(devices$items.name),3))
    colnames(intersec_points_buff[[i]])=c("ET0","date","device")
  }

  # Loop over all devices
  for (j in 1:length(devices$items.name)){

    # Remove rows with missing values
    daily_Arable_list_ET0[[j]]=stats::na.omit(daily_Arable_list_ET0[[j]])#discard NAs

    if(length(daily_Arable_list_ET0[[j]])>0){

      # Convert coordinates to spatial points
      coord_Arable=sp::SpatialPoints(coords = cbind(as.numeric(daily_Arable_list_ET0[[j]]$lon),as.numeric(daily_Arable_list_ET0[[j]]$lat)))#make spatial points out of it
      coord_Arable_sf=sf::st_as_sf(sp::SpatialPoints(coords = cbind(as.numeric(daily_Arable_list_ET0[[j]]$lon),as.numeric(daily_Arable_list_ET0[[j]]$lat))))#make sf out of sp
      sf::st_crs(coord_Arable_sf)=sf::st_crs(shape_site)#4326 # set CRS to AOI CRS
      coord_Arable_sf=sf::st_transform(coord_Arable_sf,sf::st_crs(shape_site)) # reproject to AOI CRS

      # Add ET0, date, and device info as attributes
      coord_Arable_sf$ET0=as.numeric(daily_Arable_list_ET0[[j]]$ET0)#add ET0
      coord_Arable_sf$date=as.Date(daily_Arable_list_ET0[[j]]$date)#add date
      coord_Arable_sf$device=devices$items.name[j]#add device name

      # Create 500 m buffer around AOI
      shape_site_buffer=sf::st_buffer(shape_site,dist=500)#create buffer of 500 m around site
      sf::st_intersects(coord_Arable_sf[1,],shape_site_buffer)#check for intersections of points and buffer of site

      # For each measurement point, check if it lies inside the buffer
      for (i in 1:nrow(coord_Arable_sf)){
        if(length(sf::st_intersects(coord_Arable_sf[i,][[1]],shape_site_buffer)[[1]])==1){
          intersec_points_buff[names(intersec_points_buff)==coord_Arable_sf$date[i]][[1]]$ET0[j]=coord_Arable_sf[i,]$ET0
          intersec_points_buff[names(intersec_points_buff)==coord_Arable_sf$date[i]][[1]]$date[j]=as.character(coord_Arable_sf[i,]$date)
          intersec_points_buff[names(intersec_points_buff)==coord_Arable_sf$date[i]][[1]]$device[j]=devices$items.name[j]
        }
      }
    }
  }

  # Create output data frame: average ET0 per date and DOY
  ET0_Arable=as.data.frame(matrix(NA,length(intersec_points_buff),2))
  colnames(ET0_Arable)=c("ET0","DOY")
  for (i in 1:length(intersec_points_buff)){
    ET0_Arable$ET0[i]=mean(intersec_points_buff[[i]]$ET0,na.rm=T)
    ET0_Arable$DOY[i]=lubridate::yday(names(intersec_points_buff)[i])
  }

  # Interpolate missing values linearly
  ET0_Arable=zoo::na.approx(ET0_Arable,na.rm=F)
  ET0_Arable=as.data.frame(ET0_Arable)

  # Optionally: save as CSV (commented out)
  # write.csv(ET0_Arable,paste(file.path(target_path),"/DWD_ET0_",target_year,".csv",sep=""))

  # Return processed ET0 data
  return(ET0_Arable)

}




