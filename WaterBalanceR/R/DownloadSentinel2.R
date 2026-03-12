# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

#' Downloads Sentinel-2 satellite data from Copernicus.
#' @param target_path Path (string) to destination folder for downloaded csv-files from Raindancer.
#' @param shape_site Path (string) to shapefile of AOI
#' @param start_date You need to define a start date
#' @param end_date You need to define an end date
#' @param limit Limiter (int) for number of entrys in resulting table
#' @importFrom rlang .data
#' @param max_cld Cloud cover (int) as percent of maximum cloud coverage above AOI
#' @return Geotiffs, containing Sentinel-2 data of AOI and every overpass.
#' @export

DownloadSentinel2=function(target_path=NA,
                           shape_site=NA,
                           start_date=NA,
                           end_date=NA,
                           limit=200,
                           max_cld=10){

  # Build ISO-8601 start/stop timestamps for STAC time filter
  start_time=paste(start_date,"T00:00:01Z",sep="")
  stop_time=paste(end_date,"T23:59:59Z",sep="")

  # Reproject AOI to geographic lon/lat (WGS84) for bbox queries (STAC expects lon/lat)
  shape_site=sf::st_transform(shape_site,crs= "+proj=longlat")#UTM2latlon

  # Query Copernicus Data Space STAC API for Sentinel-2 items over AOI/time, sorted by datetime
  #
  items=httr::GET(paste("https://stac.dataspace.copernicus.eu/v1/collections/sentinel-2-l2a/items?bbox=",
                        as.numeric(sf::st_bbox(shape_site)[1]),",",
                        as.numeric(sf::st_bbox(shape_site)[2]),",",
                        as.numeric(sf::st_bbox(shape_site)[3]),",",
                        as.numeric(sf::st_bbox(shape_site)[4]),
                        "&datetime=",
                        start_time,"/",stop_time,
                        "&limit=",limit,
                        "&eo:cloud_cover<",max_cld,
                        "&sortby=datetime",
                        sep=""))

  # cloud coverage and data strip label
  txt  <- httr::content(items, as = "text", encoding = "UTF-8")
  lst <- jsonlite::fromJSON(txt, simplifyVector = FALSE)

  cloud_cover=as.data.frame(matrix(NA,length(lst$features),1))
  for (i in 1:length(lst$features)){
    cloud_cover[i,1]=lst$features[i][[1]]$properties$`eo:cloud_cover`
    cloud_cover[i,2]=lst$features[i][[1]]$properties$`eopf:datastrip_id`
    cloud_cover[i,3]=paste("openEO_",
                           substr(lst$features[i][[1]]$properties$`eopf:datastrip_id`,1,3),
                           "-",
                           substr(lst$features[i][[1]]$properties$`eopf:datastrip_id`,43,46),
                           "-",
                           substr(lst$features[i][[1]]$properties$`eopf:datastrip_id`,47,48),
                           "-",
                           substr(lst$features[i][[1]]$properties$`eopf:datastrip_id`,49,50),
                           "-",
                           substr(lst$features[i][[1]]$properties$`eopf:datastrip_id`,52,57),
                           "Z",
                           sep="")
    cloud_cover[i,4]=lubridate::ymd_hms(substr(cloud_cover$V3[i],12,28))
    cloud_cover[i,5]=substr(cloud_cover$V4[i],1,10)
    cloud_cover[i,6]=substr(cloud_cover$V4[i],12,19)
    cloud_cover[i,7]=substr(cloud_cover$V3[i],8,10)
  }

  # discard duplicates
  cloud_cover_unique <- cloud_cover %>%
    dplyr::distinct(.data$V3, .data$V4, .data$V7, .keep_all = TRUE)

  # only keep last entries per day
  cloud_cover_unique_last <- cloud_cover_unique %>%
    dplyr::group_by(.data$V5) %>%
    dplyr::slice_max(.data$V4) %>%
    dplyr::ungroup()


################
  #Use openEO on Copernicus Data Space to compute NDVI mosaics/clips over AOI & period

  # Connect and authenticate (expects configured credentials in environment / keyring)
  connection = openeo::connect(host = "https://openeo.dataspace.copernicus.eu")
  openeo::login()

  # Discover processes/collections/formats
  processes_list=openeo::list_processes()
  p = openeo::processes()
  collections = openeo::list_collections()
  formats = openeo::list_file_formats()

  # Load Sentinel-2 L2A (B04=red, B08=NIR, SCL=scene classification) for AOI/time
  data = p$load_collection(id = collections$`SENTINEL2_L2A`,
                           spatial_extent = list(west=as.numeric(sf::st_bbox(shape_site)[1]),
                                                 south=as.numeric(sf::st_bbox(shape_site)[2]),
                                                 east=as.numeric(sf::st_bbox(shape_site)[3]),
                                                 north=as.numeric(sf::st_bbox(shape_site)[4])),
                           temporal_extent = c(substr(start_time,1,10), substr(stop_time,1,10)),
                           bands=c("B04","B08","SCL"))

  # Compute NDVI via a reduce over the band dimension: (NIR - RED) / (NIR + RED)
  spectral_reduce = p$reduce_dimension(data = data, dimension = "bands",reducer = function(data,context) {
    B04 = data[1]
    B08 = data[2]
    return((B08-B04)/(B08+B04))
  })

  # Save as GeoTIFF (openEO back-end will produce per-date files)
  result = p$save_result(data = spectral_reduce,format = formats$output$GTiff, options = list(red="R",NIR="NIR"))

  # Create and start an openEO batch job for processing
  job = openeo::create_job(graph = result, title = "S2A_cloud", description = "S2A-cloud")

  # Ensure output directory exists
  if(dir.exists(target_path)==F){
    dir.create(target_path)
  }

  # Start the job; log messages from the back-end
  openeo::start_job(job = job, log = TRUE)

  # Poll for completion; once results are available, download to target_path
  while(1==1){
    Sys.sleep(10)
    if(invisible(class(openeo::list_results(job = job))=="ResultList")){
      invisible(openeo::download_results(job = job, folder = target_path))
      break
    }
  }

##################
# Post-process downloaded files:
# 1) Remove any files whose dates do not pass the cloud-cover filter above
  for (i in 1:nrow(cloud_cover_unique_last)){
    if (cloud_cover_unique_last$V1[i]>max_cld){
      test_file=paste0("openEO_",substr(cloud_cover_unique_last$V3[i],12,21),"Z.tif")
      file.remove(paste0(target_path,test_file))
    }
  }

# 2) Rename remaining files to the naming expected by your WB workflow: YYYYMMDD_Sen2.tif
Sys.sleep(20)
file_names=dir(target_path)
for (i in 1:length(file_names)){
  file.rename(paste0(target_path,file_names[i]),
              paste0(target_path,substr(file_names[i],8,11),substr(file_names[i],13,14),substr(file_names[i],16,17),"_Sen2.tif"))
}
# Final status message with number of files available after filtering/renaming

message(paste("Sentinel-2 Download successfully finished. Downloaded ",length(list.files(target_path)), " files.",sep=""))
}














