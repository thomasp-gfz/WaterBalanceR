=======
History
=======

0.1.15 (2025-08-06)
------------------

General settings:
* Revised README.md
* Add Citation.cff
* Add paper.md, paper.bib and figures of workflow and example of results

0.1.14 (2025-08-04)
------------------

General settings:
* Revised README.md


0.1.13 (2025-07-16)
------------------

General settings:
* New models in calcWB.R
* removed possibility to choose "modeltype" (linear or poly) in calcWB.R and in sample data set


0.1.12 (2025-06-03)
------------------

General settings:
* Conversion of date-time vector in DownloadRaindancerCombineCharts.R

0.1.11 (2025-04-14)
------------------

General settings:
* New DOI: https://doi.org/10.5281/zenodo.15046338


0.1.10 (2025-04-11)
------------------

General settings:

* Correction of documentation within scripts
* Renaming Sentinel-2 files after downloading according to needs for running the water balance model
* Add packages magrittr, jsonlite, dplyr, readxl, scales, methods to dependencies 
* Add dynamic irrigation calculation, depending on nozzle diameter and water pressure
* New DOI: https://doi.org/10.5281/zenodo.15210105


0.1.9 (2025-03-19)
------------------

General settings:

* Changed package name to "WaterBalanceR"
* Added DOI: https://doi.org/10.5281/zenodo.15046339

0.1.8 (2025-02-20)
------------------

General settings:

* Added Licens AGPL-3.0-only to package and scripts

0.1.7 (2025-02-07)
------------------

General settings:

* Changed in DownloadRadolanFromDWD.R substr-function of Spatraster names
* Changed in DownloadRadolanFromDWD.R index for days in loop for recent year to download precipitation
* Added in DownloadRadolanFromDWD.R calculation "read_dwd_raster=terra::aggregate(read_dwd_raster)*10" for Radolan data, that is from the former year but still noted as recent
* Added Sentinel-2 as NDVI data source to Readme
* Fixed Bug in readWBplots.R(): set same CRS to buffer20.shp and NDVI-Rasterstacks as shape_site.shp

0.1.6 (2025-01-23)
------------------

General settings:

* Changed function for downloading ET_ref from DWD from raster::raster() to sf::st_read() and added mean() function to calculate ET_ref, if site is covered by more than one pixel.
* Changed function for downoading Radolan data from DWD from terra::crs() to sf::st_crs() and aggregate pixels, when site covered by more than one pixel
* correction of naming of layers in downloaded radolan files ("lyr_1" --> "layer") in script calcWB.R
* excluded "method_NDVI" parameter from Readme, run_calcWB_2023_sample.R and calcWB.R

0.1.5 (2024-11-29)
------------------

General settings:

* Added solid line at y = 0 in water balance plot for calcWBplots()
* Added Sentinel-2 as usable data source
* Removed calculation using NDVI-correlation values directly given by Arable

0.1.4 (2024-11-01)
------------------

General settings:

* Revised README - "How to install the package?" and "How to use sample data?"
* Added .csv file containing ReferenceET and .shp files containing precipitation data to sample files, so they do not have to be downloaded and the processing runs faster
* Fixed bug, that caused the shapefiles to have no crs.
* Fixed bug, that caused the shapefiles and geotiffs to have the wrong resolution


0.1.3 (2024-10-22)
------------------

General settings:

* Fixed some naming inconsistencies in results
* Added how-to-use sample data in README


0.1.2 (2024-10-18)
------------------

General settings:

* Fixed some minor bugs and naming of variables


0.1.1 (2024-10-17)
------------------

General settings:

* Added sample data


0.1.0 (2024-10-10)
------------------

General settings:

* initial commit
* create package
* add source code to the package


