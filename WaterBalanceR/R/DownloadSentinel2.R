# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

#' Processes downloaded csv-files from using DownloadRaindancer() to a shapefile. The resulting shapefile is being updated every time, this script is being run.
#' @param target_path Path (string) to destination folder for downloaded csv-files from Raindancer.
#' @param shape_site Path (string) to shapefile of AOI
#' @param start_date You need to define a start date
#' @param end_date You need to define an end date
#' @param limit Limiter (int) for number of entrys in resulting table
#' @param cloudcover Cloud cover (int) as percent of maximum cloud coverage above AOI
#' @return A shapefile, that contains all irrigation events, that were download. The shapefile is being opdated every time this script is being run, as long as all configuration parameter stay the same.
#' @export

DownloadSentinel2=function(target_path=NA,
                           shape_site=NA,
                           start_date=NA,
                           end_date=NA,
                           limit=1000,
                           cloudcover=10){

# Build ISO-8601 start/stop timestamps for STAC time filter
start_time=paste(start_date,"T00:00:01Z",sep="")
stop_time=paste(end_date,"T23:59:59Z",sep="")

# Reproject AOI to geographic lon/lat (WGS84) for bbox queries (STAC expects lon/lat)
shape_site=sf::st_transform(shape_site,crs= "+proj=longlat")#UTM2latlon

# Query Copernicus Data Space STAC API for Sentinel-2 items over AOI/time, sorted by datetime
items=httr::GET(paste("https://catalogue.dataspace.copernicus.eu/stac/collections/SENTINEL-2/items?bbox=",
                      as.numeric(sf::st_bbox(shape_site)[1]),",",
                      as.numeric(sf::st_bbox(shape_site)[2]),",",
                      as.numeric(sf::st_bbox(shape_site)[3]),",",
                      as.numeric(sf::st_bbox(shape_site)[4]),
                      "&datetime=",
                      start_time,"/",stop_time,
                      "&limit=",limit,
                      "&sortby=datetime",
                      sep=""))

# Parse STAC response → data.frame; filter by cloud cover and L2A product type
items=as.data.frame(jsonlite::fromJSON(httr::content(items,as="text",encoding="UTF-8")))
items=subset(items,items$features.properties$cloudCover<=cloudcover & items$features.properties$productType=="S2MSI2A")
dates_cloudcover=items$features.properties$datetime


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
job = openeo::create_job(graph = result, title = "S2A", description = "S2A-NDVI")

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
delete_files=invisible(list.files(target_path)[!list.files(target_path) %in% unique(paste("openEO_",substr(dates_cloudcover,1,10),"Z.tif",sep=""))])
file.remove(paste(target_path,delete_files,sep="/"))

# 2) Rename remaining files to the naming expected by your WB workflow: YYYYMMDD_Sen2.tif
Sys.sleep(10)
if (length(list.files(target_path)>0)){
  for(i in 1:length(list.files(target_path))){
    file.rename(list.files(target_path,full.names=T)[i],
                paste(target_path,substr(list.files(target_path)[i],8,11),
                      substr(list.files(target_path)[i],13,14),
                      substr(list.files(target_path)[i],16,17),
                      "_Sen2.tif",sep=""))
  }
}
# Final status message with number of files available after filtering/renaming

print(paste("Sentinel-2 Download successfully finished. Downloaded ",length(list.files(target_path)), " files.",sep=""))
}














