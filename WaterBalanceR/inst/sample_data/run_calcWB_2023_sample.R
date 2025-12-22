# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

### 0.1 copy sample directory to temporary directory ----
sample_path = system.file("sample_data", package = "WaterBalanceR")
mypath = file.path(tempdir(), "WaterBalanceR_example") #set up temporary directory
dir.create(mypath, showWarnings = FALSE, recursive = TRUE)
library(fs)
dir_copy(sample_path,mypath,overwrite=TRUE)

### 0.2 configuration ----
shape_site = paste(mypath,"/Shapefile/sample_2023.shp",sep="") #path to shapefile of AOI
target_res=5 #spatial resolution of results, must be >=5
last_NDVI_0=132 #last day with NDVI==0, so with no visible vegetation
ET_ref=read.csv(paste(mypath,"/DWD_ET0_2023.csv",sep=""),sep=",") #csv file with with daily reference ET or leave at NA. If NA, then...
ET_ref_dl="DWD" #...choose from "DWD" or "Arable" to download reference ET
path_WR_precip=paste(mypath,"/Radolan_2023_processed_daily",sep="") #folder with shapefiles of daily precipitation for AOI, either from FURUNO or RADOLAN or leave at "NA".
precip_source="radolan" #choose "radolan" or "furuno". if line above is NA, then choose "radolan" to automatically download und process RADOLAN data
irrig_sf=paste(mypath,"/Shapefile/Buffer_36m_all_interp.shp",sep="") #path to shapefile with irrigation amounts from Raindanceruser portal
irrigation_efficiency=1 #0.775 #choose irrigation efficiency. If unsure, leave at 1
output_year=2023 #Year of interest "YYYY"
save_shape=TRUE #save results as shapefile?
save_geotiff=TRUE #save results as geotiff?
save_RDATA=TRUE #save results as RDATA?
arable_user="username" #user name for arable account, if you choose to download reference ET from Arable
arable_pass="password" #password for arable account, if you choose to download reference ET from Arable

### 1. run model ----
test_wb=WaterBalanceR::calcWB(mypath=mypath,
                              shape_site=shape_site,
                              target_res=target_res,
                              last_NDVI_0=last_NDVI_0,
                              ET_ref=ET_ref,
                              ET_ref_dl=ET_ref_dl,
                              output_year=output_year,
                              path_WR_precip=path_WR_precip,
                              precip_source=precip_source,
                              irrig_sf=irrig_sf,
                              irrigation_efficiency=irrigation_efficiency,
                              save_shape=save_shape,
                              save_geotiff=save_geotiff,
                              save_RDATA=save_RDATA,
                              arable_user=arable_user,
                              arable_pass=arable_pass)

### 2. plot procedure ----
buffer20 = file.path(mypath, "Shapefile", "Buffer_5_WB.shp")

WaterBalanceR::calcWBplots(
  source_path = file.path(
    mypath,
    paste0(
      precip_source, "_", irrigation_efficiency, "_",
      last_NDVI_0, "_", target_res, "/",
      "WBR_", precip_source, "_", irrigation_efficiency, "_",
      last_NDVI_0, "_", target_res, ".RData"
    )
  ),
  plant_doy = 109,
  buffer20 = buffer20,
  shape_site = shape_site
)

