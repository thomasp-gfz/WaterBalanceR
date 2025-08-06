## SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
## SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
## SPDX-License-Identifier: AGPL-3.0-only
## DOI: https://doi.org/10.5281/zenodo.15046338
## This software is part of an active research project and currently under peer review at the Journal of Open Source Software (JOSS). Please cite appropriately if reused.


# WaterBalanceR

An R package for processing maps that show the daily, spatially distributed water balance of starch potatoes. NDVI data must be derived from either preprocessed DJI Phantom 4 Multispectral data, PlanetScope satellite data, or Sentinel-2 satellite data.

## Aim of Model and extensibility

Water is often a limited resource in agriculture and therefore needs to be conserved as effectively as possible. In northeastern Germany, starch potatoes typically require around 80–120 mm of irrigation during the growing season, depending on climatic conditions. However, farmers may over- or underestimate the water needs of the crop, creating potential for optimizing irrigation practices. The model output provides high spatial resolution — by default 5 meters — enabling site-specific irrigation based on the water demand at the pixel level. The package was developed within the BMEL-funded project "AgriSens-DEMMIN 4.0" based on a three-year time series of experiments conducted in the DEMMIN region in northeastern Germany. The results of the experiments and the resulting models are currently being published in the journal Remote Sensing (MDPI). Although the experiments were conducted in NE Germany, input data is available for the entire country, making it possible to apply the package across all of Germany. The underlying model principle is also applicable worldwide but should be validated at additional sites to ensure robustness. This opens up an opportunity to further develop the package with respect to spatial transferability. Currently, the package is only applicable to starch potatoes. However, due to its modular structure, it can be extended to other crops as well. These two aspects — spatial transferability and extension on other crop types — could form the basis for future research.

## How to install the package?

The package includes the file install_WaterBalanceR.R. Open this file in R or RStudio and modify the line wd <- to reflect the local path where your downloaded version of WaterBalanceR is saved. Then, run the script. When prompted to install the required packages, confirm the installation. Once all dependencies are installed, the model should be ready to use. To test the model, you can use the included sample dataset, which is located in the sample_data subfolder. Before running the model, copy this folder to your preferred working directory.

## Using sample data

### What do we have here?

The "sample_data" folder consists of
- a set of NDVI-sample data (folder "NDVI-Files") including DJI Phantom 4 Multispectral data (nomenclature: "[YYYYMMDD]_P4M1.tif") and/or PlanetScope data (nomenclature: "[YYYYMMDD]_Plan.tif") and/or Sentinel-2 data (nomenclature: "[YYYYMMDD]_Sen2.tif"). 
- a set of shapefiles (folder "Shapefile") including "sample_2023.shp", which contains a polygon of a sample site, that spatially fits to the one from the NDVI files, and "Buffer_36m_all_interp.shp", which contains irrigation data according to the sample site, and "Buffer_5_WB.shp", which contains a set of sample spots within the AOI (polygon circles with a diameter of 5m), that we can use to get further details for the area, that these spots are covering.
- a "DWD_ET0_2023.csv" file containing reference ET from German Weather Service, so it does not have to be downloaded
- a Folder "Radolan_2023_processed_daily" containing daily precipitation data from German Weather Service, so it does not have to be downloaded
- an R-file "run_calcWB_2023_sample.R" including an example configuration for running the water balance model.

### How do we configure the "run_calcWB_2023_sample.R"?

As `mypath=`you should use your preferred working directory, where you copied your sample data. The rest of the scripts can stay unchanged. Further information about the configuration possibilies can be found below.
The script can be subdivided into three parts:
- 1st: empty Environment and configuration
- 2nd: run the actual model (`calcWB()`) to create maps as shapefiles and/or geotiffs showing the waterbalance and other results for your AOI.
- 3rd: create plots, that show additional information about the sample spots within the AOI, that you are interested in (shapefile: "Buffer_5_WB.shp").To get These resulting maps, you need to run the "calcWBplots()" after using the resulting .RData - file from "calcWB()".

As a result you get a Folder named after the given configuration, e.g. "radolan_1_132_5", which means "radolan" = source of precipitation, "1" = irrigation Efficiency, "132" = last day of NDVI being 0, "5" = spatial Resolution in meter.


## Input data and configuration - further details

The model needs at least NDVI data (GeoTIFF), a shapefile containing the AOI and a shapefile containing the irrigation amount. To show maps and detailed results for certain spots, you can also add a shapefile containting polygons for the spots that you are interested in. The folder "example_data" contains a set of data, that is the minimum required to run the model as well as as a script that is configured accordingly.

### NDVI data
The NDVI data needs to be either processed from DJI Phantom 4 Multispectral UAV using Pixer4Dmapper-othomosaics and/or PlanetScope images and/or Sentinel-2 images. The naming of the files is done by the date of recording [YYYYMMDD] followed by an underscore and the abbrivation of the source, i.e. for an image that was captured by PlanetScope ("Plan") on 15th July 2023, it should be "20230715_Plan.tiff", or for an orthomosaic from DJI Phantom 4 Multispectral ("P4M1"), it should be "20230715_P4M1.tiff" or for an orthomosaic from Sentinel-2 ("Sen2"), it should be "20230715_Sen2.tiff". The timespan of your NDVI data also defines the timespan of dates for your results.

### AOI ("shape_site")
You need a shapefile containing a polygon from your AOI

### Precipitation
Precipitation data is gathered either from German Weather Service (default) or from given X-Band precipitation data, that was processed using WRaINfo (https://doi.org/10.5281/zenodo.7220832 and https://doi.org/10.5334/jors.453). Here, for every day of year (DOY) a shapefile with the daily precipitation distribution is needed.

#### Source of precipitation ("precip_source")
Choose either "RADOLAN" (default, string) or "FURUNO" (string) depending on the source you would like to use.

#### Path to precipitation data ("path_WR_precip")
Choose the path to your precipitation data (string). This should be a folder containing shapefiles with precipitation data for every day during the vegetation period you are interested in. If you leave it an NA (default), precipitation data is downloaded from German Weather Service (DWD).

### Reference Evapotranspiration
Reference ET Data is gathered from German Weather Service (default) or from on-site deployed Arable Mark 2 or Arable Mark 3 stations. Here, you need a working user account with log-in and password. 

#### "ET_ref"
Here you can enter a csv-file containing a chart of DOY (integer) and according values or you can leave it as "NA", which is the default. When using the csv-file, the first column needs to be ascending numerized (integer) from one on with empty header. The second column contains the reference ET value for the certain DOY (float) with header "V1". The third column needs to be the date (format "YYYY-MM-DD", e.g. "2021-05-01). When left ET_ref=NA (default), the reference ET is automatically downloaded from either German Weather Servcice (DWD, default) or Arable, if you have an account. This decision needs to be made in the next step ("ET_ref_dl").

#### "ET_ref_dl"
If you do not have any reference ET data chart, leave "ET_ref = NA" and choose here between "ET_ref_dl = DWD" to download from German Weather Service ("DWD") or "ET_ref_dl = Arable" to download from your Arable account ("string"). If you choose to download from your Arable Account, you need to put in your Arable login data.

### Irrigation
Irrigation is regareded as one shapefile containing irrigation distribution for the certain days, when an irrigation event was applied. Here, a script, that can scrape and process data from your Raindancer user account, is included ("DownloadRaindancer.R"). If you like to run it, you first have to install Java (https://www.java.com) and Firefox on your machine.

#### loading Irrigation data ("irrig_sf")
Path to shapefile containing the irrigation data (string), e.g. st_read(paste(mypath,"/Shapefile/Buffer_36m_all_interp.shp",sep="")). The shapefile needs to contain the following coloumns: Drck_mn (water pressure, float), Dtm_Uh_ (Date and time, string, format: "YY-MM-DD hh:mm:ss"), timedif (time difference between steps in hours, float), dst_gps (spatial distance between in m the logs of sprinkler, float), gschwn_ (speed of sprinkler in m/s, float), Brg_GPS (irrigation amount, mm, float), Dstnz_k (cumulated spatial distance between logs in m, float), DOY (day of year, integer), geometry (geometric geometry). You can also generate this shapefile by 1st using the function "DownloadRaindancer" to download all of your irrigation data that was logged by raindancer. Take note, that irrigation data can only be downloaded from the last 12 days. So you should downoad regularly. In the 2nd step you can use the function "DownloadRaindancerCombineCharts" to combine the downloaded charts and process them to the needed shapefile. The resulting shapefile is being updated witht every iteration of download.

#### Irrigation efficiency ("irrigation_efficiency")
Choose irrigation efficiency, float between 0 and 1 (default). Here, irrigation efficiency is meant to be as the fraction of water that was infiltrated in the soil from the amount that was applied.

### Target resolution ("target_res")
Here, you can name the the target resolution of your resulting map in meter. Default = 5 m.

### Last day with NDVI = 0 ("last_NDVI_0")
Here you need to enter the DOY, when no plants were last visible.

### Processing year ("output_year")
Number of year, you like to process (format: "YYYY", e.g. 2021, integer).

### saving results
Choose, how to save your results:

#### save_shape
Results are saved as shapefiles, Default: TRUE.

#### save_geotiff
Results are saved as geotiffs, Default: TRUE.

#### save_RDATA
Results are saved as .RDATA, Default: TRUE.

### Arable user data ("arable_user" and "arable_pass")
Your user name for your Arable account (string). Only necessary, if you chose "ET_ref_dl" with "Arable". Else: leave at NA.
Your password for your Arable account (string). Only necessary, if you chose "ET_ref_dl" with "Arable". Else: leave at NA.
Here it is necessary, that either Arable Mark 2 or Arable Mark 3 Ground stations are deployed within your AOI during your desired timespan.


### Table 1: Parameters, that need to be configured within the main script “run_calcWB.R” to run calculation of water balance.

| Parameter           | Description                                         | Data Format (or range) | Default values | Alternatives                                    |
|---------------------|-----------------------------------------------------|-----------------------|----------------|------------------------------------------------|
| mypath              | Path to raw data                                    | str                   | NA             |                                                |
| shape_site          | Boundaries of AOI                                   | shapefile             | NA             |                                                |
| target_res          | Target resolution of resulting map                  | integer               | 5              |                                                |
| method_NDVI         | Method of NDVI calculation                           | str                   | "uwdw"         | "direct"                                       |
| modeltype           | Type of modeling NDVI                               | str                   | "poly"         | "linear"                                       |
| last_NDVI_0         | Last day before visible germination                 | integer               | NA             |                                                |
| ET_ref              | Chart with daily reference ET values                | csv-chart             | NA             |                                                |
| ET_ref_dl           | If “ET_ref” is NA, one can download daily ET       | str                   | "DWD"          | "Arable"                                       |
| path_WR_precip      | Path to precipitation data                           | str                   | NA             |                                                |
| precip_source       | If “path_WR_precip” is NA, download precipitation   | str                   | "radolan"      | "furuno"                                       |
| irrig_sf            | Path to shapefile with irrigation buffers           | str                   | NA             |                                                |
| irrigation_efficiency| Irrigation efficiency depending on irrigation method| integer               | 1              | < 1                                            |
| save_shape          | Save results as daily shapefiles?                    | TRUE / FALSE          | TRUE           |                                                |
| save_geotiff        | Save results as daily geotiffs?                      | TRUE / FALSE          | TRUE           |                                                |
| save_RDATA          | Save results as RDATA?                               | TRUE / FALSE          | TRUE           |                                                |
| arable_user         | User name for Arable account, if available           | str                   | NA             |                                                |
| arable_pass         | Password for Arable account, if available             | str                   | NA             |                                                |


## Detailed description of single modules

### Calculation of water balance: calc_wb
This calculation module is the main part of the package, since it reads the multispectral data given by the user, calculates the crop coefficient and water balance based on pre-defined models and steers the regarding functions. All the necessary input data are given by the configuration module. First, it reads the given optical data (.tiff files) and converts them to raster format. Here, the filenames of optical data should be build in the format of “YYYYMMDD_[source of optical data].tiff” with “YYYYMMDD” being the date of record and source of optical data either being “Plan” for PlanetScope Analytic Ortho Scene Products (3B_Analytic_MS_8b) or “Sen2” for Sentinel-2 data or “P4M1” for DJI Phantom 4M data. That means for example “20250401_Plan.tif” is an image that was taken by PlanetScope satellites on 1st April 2025. The first and last date of optical data defines the range of date, that is being processed by the package. Second, a given shapefile is read, that defines the AOI, and a resampling and co-registration of images according to the AOI is done by a bilinear interpolation is done. Third, the co-registered images are aggregated to the target spatial resolution. Here, if Sentinel-2 images are involved, the target spatial resolution cannot be below 10 m. Otherwise an error warning is given. Within the forth step, a temporal interpolation to a daily temporal resolution is performed. Here, according to a linear pattern, every pixel is linearly interpolated between two images. Therefore, the dates of taken images, especially during rapidly progressing development phases, should not be more than 10 days apart. In the fifth step, the actual calculation of crop coefficients, crop evapotranspiration and water balance is performed, while other variables such as irrigation, precipitation and reference evapotranspiration are taken into account. Here, if necessary, data is automatically being downloaded from the CDC open data portal of German Weather Service (DWD), Arable labs user portal or Raindancer user portal, if there are active user accounts. For this purpose, the corresponding functions are called, which are described in more detail below. In a sixth step, daily values are cumulated, so not only single day values are available but also the actual values, that summed up over the vegetation period or the observation time, rsp. In a last step, all results are saved, either as .shp and/or .tiff and/or .RData file for further processing in a created folder named “[modeltype]_[precip_source]_[irrigation_efficiency]_[last_NDVI_0]_[target_resolution]”, e.g. “poly_radolan_1_132_5”. The stored .RData file is named to the corresponding folder with prefix “WBR”, e.g. “WBR_radolan_poly_1_132_5.RData”.

### Download of reference ET from German Weather Service (DWD): DownloadET0fromDWD
To calculate the daily ETc next to the crop coefficient the according daily ET0 is needed (see eq 1). This can either be downloaded from the German Weather Service (DWD) CDC open data portal (https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/evaporation_fao/) or from the Arable Labs user portal. The DWD provides netcdf-files (.nc) including data of a single year per file. The module can either be called by the main module (calc_wb) or can be called as stand-alone. Here, it needs 4 parameters to run (see Table 3). The target path (string) to the destination folder on local harddrive, a polygon shapefile containing boundaries of the AOI, the year of interest (four-digit number as string) and a timeout (integer), that defines the time to wait for the download to finish. The slower the connection, the bigger the timeout should be. The function downloads the necessary netcdf-files, extracts and reprojects them to the target projection, that is given by the shapefile containing the AOI. After processing, the result is a .csv file, that contains two columns with date and according ET0. Any other downloaded files are only temporarily saved and are getting removed after successful calculation.

#### Table 2: Parameters to run “DownloadET0fromDWD.R” to download reference evapotranspiration from German Weather Service (DWD) for the given site and timespan.

| Parameter       | Description                             | Data Format (or range) | Default value | Alternatives |
|-----------------|---------------------------------------|-----------------------|---------------|--------------|
| target_path     | Target path of processed reference ET | str                   | NA            | -            |
| test_site_shape | Boundaries of AOI                      | shapefile             | NA            | -            |
| target_year     | Year of interest                      | str ("2021")          | NA            | -            |
| timeout         | Patience of system to not interrupt download | integer           | 1000          | > 1          |

### Download of reference ET from Arable user portal: DownloadET0fromArable
If there is a user account for the Arable labs user portal is available and at least one Arable Mark 2 or Mark 3 station was installed on the AOI during the observed time span, ET0 data can also be downloaded from here. This is especially recommended, if the AOI is situated outside Germany and no data from German Weather Service is available. The module can also either be called by the main module (calc_wb) or can be called as stand-alone. Here, it needs 4 parameters to run (see Table 4).  A valid Arable user name (string) as well as the according password (string) is needed. Furthermore, a start date and an end date (format: “YYYY MM-DD” as string) need to be defined and a polygon shapefile containing the AOI boundaries needs to be included. Here, an API connection to the Arable user account is set up and the availability of data is requested. If more than one device is deployed, the mean ET0 from these devices for a day is calculated. After processing, the result is a .csv file, that contains two columns with date and according ET0.

#### Table 3: Parameters to run “DownloadET0fromArable.R” to download reference evapotranspiration from Arable user portal, if Arable Mark 2 ground stations are installed on area of interest for the given timespan.

| Parameter  | Description                     | Data Format (or range)     | Default value | Alternatives |
|------------|---------------------------------|---------------------------|---------------|--------------|
| user_name  | Your user name for Arable account | str                       | NA            | -            |
| pwd        | Your password for Arable account | str                       | NA            | -            |
| start_date | Date of first day of interest    | str (e.g. "2021-01-01")   | NA            | -            |
| end_date   | Date of last day of interest     | str (e.g. "2021-12-31")   | NA            | -            |
| Shape_site | Boundaries of AOI                | shapefile                 | NA            | -            |

### Download of precipitation data from DWD: DownloadRadolanfromDWD
Precipitation data can be downloaded using the module DownloadRadolanfromDWD either by calling the module DownloadRadolanfromDWD from calc_wb or as stand-alone module. Here, a target path needs to be defined (string), where there the data shall be saved, and a target site should be loaded as a polygon shapefile containing the boundaries of the AOI. Furthermore, a start date and an end date (format: “YYYY MM-DD” as string) need to be defined as a time span (see Table 5). Depending on it is either recent or historical data, they are downloaded from the German Weather Service (DWD) CDC open data portal (https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/radolan/) as .tar.gz files and reprojected to the given polygon shapefiles projection. The result is saved as a a shapefile containing the precipitation data according and cropped to the AOI. Any other downloaded files are only temporarily saved and are getting removed after successful calculation.

#### Table 4: Parameters to run “DownloadRadolanfromDWD.R” to download precipitation data from German Weather Service (DWD) for the given site and timespan.

| Parameter   | Description                        | Data Format (or range)      | Default value | Alternatives |
|-------------|----------------------------------|----------------------------|---------------|--------------|
| target_path | Target path of processed reference ET | str                      | NA            | -            |
| target_site | Boundaries of AOI                | shapefile                  | NA            | -            |
| start_date  | Date of first day of interest    | str (e.g. "2021-01-01")    | NA            | -            |
| end_date    | Date of last day of interest     | str (e.g. "2021-12-31")    | NA            | -            |

### Download of Sentinel-2 satellite data: DownloadSentinel2
Next to either DJI Phantom 4 Multispectral UAV data and PlanetScope satellite imagery, also Sentinel-2 satellite imagery can be a basis for NDVI input data. In contrast to the other two sources, which must either be created by flying or purchased, the package contains a module here that allows the user to directly download freely available satellite Sentinel-2 L2A data from OpenEO Web Editor (https://openeo.dataspace.copernicus.eu). This module is not directly connected to the main module (calc_wb) and needs to be run separately given certain parameters (see Table 6). For this, a target path (string) needs to be defined first, where the downloaded files will be stored. Additionally, a polygon shapefile containing the boundaries of the AOI must be provided, and the start and end dates of the desired time period must be specified, each as “YYYY-MM-DD” (string). To enhance the number of results in the chart, the limiter should be kept at 1000 (default, integer). Besides, the maximum cloud coverage needs to be defined in percent (integer, default = 10). To run the script, an account at https://dataspace.copernicus.eu needs to be registered, since the connection is secured. Here, every time, a connection is started, the site is loaded in your internet browser, where you need to log in and verify the download. Depending on the amount of requested data, it can last some minutes, until the batch job finishes computing and the download starts. Here, every ten seconds a new download is requested until the download is completed. The downloaded files are saved in the target folder and already named to fit the requirements of the main module (calc_wb).

#### Table 5: Parameters to run “DownloadSentinel2.R” to download Sentinel-2 imagery from Copernicus for the given site and timespan.

| Parameter   | Description                                   | Data Format (or range)         | Default Value | Alternatives |
|-------------|-----------------------------------------------|-------------------------------|---------------|--------------|
| target_path | Target path of downloaded Sentinel-2 data     | str                           | NA            | -            |
| shape_site  | Path to boundaries of AOI                      | str                           | NA            | -            |
| start_date  | Date of first day of interest                  | str (e.g. "2021-01-01")       | NA            | -            |
| end_date    | Date of last day of interest                   | str (e.g. "2021-12-31")       | NA            | -            |
| limit       | Limit of results in chart                       | integer                       | 1000          | > 1          |
| cloudcover  | Percent of maximum cloud coverage on image    | integer                       | 10            | > 0          |

### Downloading Raindancer irrigation data: DownloadRaindancer
The package provides support for irrigation data, that can either be included as a shapefile or be downloaded from Raindancer user portal, if there is a working user account. If provided as a shapefile, the shapefile needs to contain one or more features with irrigation amounts per day, while the column containing irrigation amount needs to be named as “Brg_GPS” (irrigation height in mm, float) and the column containing the according day needs to be named as “DOY” (day of year, integer). If a Raindancer user account is used, the module DownloadRaindancer can automatically scrape the data from the website by downloading all available protocols as .xlsx files, when given certain parameters (see Table 7). It is necessary to have Java and Firefox internet browser installed on the machine. Here, the last 10.000 logs, i.e. roughly the last 12 days of sprinkler action are downloaded. This means, the download should be regularly repeated within a maximum of 12 days during vegetation period to avoid any data gaps. As source path the standard Firefox download path is used (“sourcepath”, string), which can be looked up in the Firefox browser. The downloaded files are copied to a target path (“targetpath”, string), were there are stored in an automatically created sub folder named after download date and time. Furthermore, the client ID (“client”, string), user name (“user”, string) and password (“pass”, string) for a working Raindancer user account need to be given. With “waitfor” a variable containing a waiting time (seconds, integer) needs to be defined, since it is the time, the machine waits for the webpage to be updated. This means, the slower the internet connection, the longer should be the time to wait (default is 3 seconds). The variable “nozzle_diameter” (string) contains the diameter [mm] of the Nelson SR50 nozzle, that is mounted on the sprinkler canon (default “25_4”, i.e. 25.4 mm). When running this module, the module DownloadRaindancerCombineCharts is automatically started in a last step (see section g). 

#### Table 6: Parameters to run “DownloadRaindancer.R” to download irrigation data from Raindancer user portal for all sites and the last 12 days of running the script.

| Parameter        | Description                                                   | Data Format (or range)          | Default Value | Alternatives                                         |
|------------------|---------------------------------------------------------------|--------------------------------|---------------|-----------------------------------------------------|
| sourcepath       | Path to raw data (your standard download path of Firefox)     | str                            | NA            | -                                                   |
| targetpath       | Target path of downloaded files                                | str                            | NA            | -                                                   |
| client           | Your client number for Raindancer                              | str                            | NA            | -                                                   |
| user             | Your user name for Raindancer                                  | str                            | NA            | -                                                   |
| pass             | Your password for Raindancer                                   | str                            | NA            | -                                                   |
| port             | Port to use for download                                       | int                            | 4486L         | -                                                   |
| waitfor          | Waiting time [s] for browser and downloads between clicks     | integer                        | 3             | > 0                                                 |
| nozzle_diameter  | Diameter of sprinkler nozzle [mm]                             | str                            | "25_4"        | "17_8", "20_3", "22_9", "27_9", "30.4", "33_0"      |
| target_crs       | CRS given to module “DownloadRaindancerCombineCharts.R”       | int                            | 32633         | -                                                   |

### Processing downloaded Raindancer irrigation data: DownloadRaindancerCombineCharts
After the irrigation protocol files were downloaded from Raindancer user portal (see section f), they need to be pasted to one single file with no overlapping data and only containing true irrigation actions as well as corrected and transformed to shapefile format. This is processed within the the module DownloadRaindancerCombineCharts given certain parameters (see Table 8). The module needs a source path (“sourcepath”, string), containing the downloaded .xlsx files, which is qual to the target path of the module DownloadRaindancer. However, also here a target path (“targetpath”, string) is required, where there the shapefiles containing the irrigation amounts are saved. Both of the target paths may not be equal. A start date (“startdate”, string) may be defined as the first date, that is taken into account. If left empty, the 1st January of the recent year is defined as base. According to DownloadRaindancer module, here also a sprinkler radius in meters is necessary to be defined (“buffer_dist”, string, default is 36).  During processing, missing values are interpolated and a correction of coordinates to avoid natural GNSS-bias as well as an outlier correction are performed. As results two shapefiles are saved: one containing the uncorrected, original data, including all status updates like non-irrigation events and errors, and the other one containing the corrected and interpolated data, only regarding active irrigation events. Besides, results according to single sites are saved as an .RData file.

#### Table 7: Parameters to run “DownloadRaindancerCombineCharts.R” to paste and process downloaded Raindancer irrigation .xlsx files data to .shp files.

| Parameter       | Description                                 | Data Format (or range)           | Default Value          | Alternatives                                      |
|-----------------|---------------------------------------------|---------------------------------|------------------------|--------------------------------------------------|
| sourcepath      | Path to downloaded files                     | str                             | NA                     | -                                                |
| targetpath      | Target path of processed irrigation buffers | str                             | NA                     | -                                                |
| startdate       | Date of irrigation event                      | str                             | "[recent year]-01-01"  | Date formatted as "YYYY-MM-DD"                    |
| nozzle_diameter | Diameter of sprinkler nozzle [mm]             | str                             | "25_4"                 | "17_8", "20_3", "22_9", "25_4", "27_9", "30.4", "33_0" |
| target_crs      | CRS of resulting shapefiles                   | int                             | 32633                  | -                                                |

### Print final results as graphics: calcWBplots
Module calc_WB precedes module calcWBplots. Within Module calc_WB, all results are stored in the form of Shapefiles and/or GeoTIFFs, as well as in .RData format. These outputs are comprehensive and intended for further geospatial processing or in-depth scientific analysis. For an initial visual and interpretative overview, Module calcWBplots offers a suitable approach by generating daily composite maps throughout the vegetation period (see fig. 2). These maps include spatial distributions of NDVI, crop coefficient (Kc), crop evapotranspiration (ETc), precipitation, irrigation, and the final water balance. Furthermore, an optional input Shapefile containing up to five polygons can be provided. For each polygon, the respective mean values are visualized in detail over the course of the vegetation period. In addition to serving as a quick reference, this compilation also provides added value for end users requiring an accessible summary of key indicators. Parameters needed are “source_path” (string), related to the .RData file, that was created by calc_WB and stores the results from water balance calculations, the “plant_doy” (integer), which is the day of year, when potatoes were planted, the polygons for special POIs on the site (“buffer_20”, string) and the path to shapefile (string) containing boundaries of the AOI. First, mean values of given POIs are calculated for each day and saved as .RData file named after .RData file, that was created by module calc_wb, followed by “mean_data_charts”, e.g. “WBR_radolan_poly_1_132_5_mean_data_charts.RData”. In a second step, the single figures regarding the attributes are created and ordered as ensembles, that are saved as one .png file per day in the created folder “wallpapers”.

#### Table 8: Parameters to run “calcWBplots.R” to plot all the results from calcWB.R in one concise figure containing also certain POIs.

| Parameter   | Description                                       | Data Format (or range) | Default Value | Alternatives |
|-------------|-------------------------------------------------|-----------------------|---------------|--------------|
| source_path | Path to resulting .RData file from calc_WB.R    | str                   | NA            | -            |
| plant_doy   | Day of year, when potatoes were planted          | int                   | NA            | -            |
| buffer_20   | Path to shapefile containing polygons of POIs    | str                   | NA            | -            |
| shape_site  | Path to boundaries of AOI                         | str                   | NA            | -            |

## Further results
Next to the given results from calWB.R, it is useful to run the script "calcWBplots.R" to get Maps containing Maps for every desired DOY. Here, it is necessary to load the .RDATA file resulting from calcWB.R next to some other input data:

### DOY of planting ("plant_doy")
DOY (integer) of planting potatoes.

### Buffer of the spots you are interested in ("buffer20")
Here, you need to load a shapefile, that contains up to 5 polygons of spots, that you are especially interested in (see "example_data")

### Shapefile of AOI ("shape_site")

## Availability

### Operating System:
        - GNU/Linux
        - Windows

### Programming Language:
        - WaterBalanceR has been written in R (Version: 2024.12.0.467+)

### Dependencies:
        - ncdf4: 1.23+
        - raster: 3.6.31+
        - sf: 1.0.19+
        - zoo: 1.8.12+
        - lubridate: 1.9.4+
        - stars: 0.6.7+
        - ggplot2: 3.5.1+
        - tidyr: 1.3.1+
        - rdwd: 1.8.0+
        - dwdradar: 0.2.10+
        - R.utils: 2.12.3+
        - utils: 4.4.2+
        - terra: 1.8.15+
        - foreach: 1.5.2+
        - parallel: 4.4.2+
        - doParallel: 1.0.17+
        - gridExtra: 2.3+
        - httr: 1.4.7+
        - httr2: 1.1.0+
        - devtools: 2.4.5+
        - RColorBrewer: 1.1.3+
        - tidyverse: 2.0.0+
        - Rselenium: 1.7.9+
        - stringr: 1.5.1+
        - rvest: 1.0.4+
        - sp: 2.1.4+
        - geosphere: 1.5.20+
        - RCurl: 1.98.1.16+
        - grDevices: 4.4.2+
        - tidyselect: 1.2.1+
        - openeo: 1.3.1+
        - magrittr: 2.0.3+
        - jsonlite: 1.9.1+
        - dplyr: 1.1.4+
        - readxl: 1.4.5+
        - scales: 1.3.0+
        - methods: 4.4.2+






