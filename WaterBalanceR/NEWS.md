# WaterBalanceR – History / NEWS

## 0.1.19 (2025-12-15)

**General settings:**

- Revision of "DownloadSentinel2.()"
- Revision of Description regarding acronyms
- Added Reference to Description
- Information Messages written to console can no be suppressed ("print()" --> "message()" or "warning()" or "stop()")
- Omitted any default path in writing functions. Using tempdir() instead now.
- Writing TRUE and FALSE instead of T and F
- using on.exit() now to reset temporary settings when the function is exited

---

## 0.1.18 (2025-11-28)

**General settings:**

- adjusting sample data set

---

## 0.1.17 (2025-11-19)

**General settings:**

- Updated `calcWB()` to write `stars` objects  
- Updated `calcWB()` and `calcWBplots()` to read paths as strings (`"buffer20"`, `"shape_site"`, `"irrig_sf"`)  
- Moved sample dataset to `WaterBalanceR/inst/sample_data`  
- Created vignettes and test file `test_calcWB.R`
- "DownloadRaindancer.R" can now srape data in a hidden mode
- revised Description and CITATION files

---

## 0.1.16 (2025-09-26)

**General settings:**

- Updated model to calculate Kc from NDVI for Arable Mark 2 stations  
- Revised license file  
- Revised documentation within scripts  
- Published paper on underlying experiment and modelling:  
  [https://doi.org/10.3390/rs17183227](https://doi.org/10.3390/rs17183227)

---

## 0.1.15 (2025-08-06)

**General settings:**

- Revised `README.md`  
- Added `CITATION.cff`  
- Added `paper.md`, `paper.bib`, and workflow/result figures

---

## 0.1.14 (2025-08-04)

**General settings:**

- Revised `README.md`

---

## 0.1.13 (2025-07-16)

**General settings:**

- Added new models in `calcWB.R`  
- Removed parameter `modeltype` (linear/poly) from `calcWB.R` and sample dataset

---

## 0.1.12 (2025-06-03)

**General settings:**

- Improved conversion of date-time vectors in `DownloadRaindancerCombineCharts.R`

---

## 0.1.11 (2025-04-14)

**General settings:**

- Added new DOI: [https://doi.org/10.5281/zenodo.15046338](https://doi.org/10.5281/zenodo.15046338)

---

## 0.1.10 (2025-04-11)

**General settings:**

- Corrected internal documentation  
- Renamed Sentinel-2 files after download for water balance model compatibility  
- Added dependencies: `magrittr`, `jsonlite`, `dplyr`, `readxl`, `scales`, `methods`  
- Added dynamic irrigation calculation (based on nozzle diameter and water pressure)  
- Added new DOI: [https://doi.org/10.5281/zenodo.15210105](https://doi.org/10.5281/zenodo.15210105)

---

## 0.1.9 (2025-03-19)

**General settings:**

- Renamed package to **WaterBalanceR**  
- Added DOI: [https://doi.org/10.5281/zenodo.15046339](https://doi.org/10.5281/zenodo.15046339)

---

## 0.1.8 (2025-02-20)

**General settings:**

- Added AGPL-3.0-only license to package and scripts

---

## 0.1.7 (2025-02-07)

**General settings:**

- Fixed `substr()` behavior for SpatRaster names in `DownloadRadolanFromDWD.R`  
- Corrected day index for recent year in `DownloadRadolanFromDWD.R`  
- Added calculation for `read_dwd_raster = terra::aggregate(read_dwd_raster) * 10` for previous-year RADOLAN data  
- Added Sentinel-2 as NDVI data source to README  
- Fixed CRS mismatch bug in `calcWBplots.R()` (between `buffer20.shp`, NDVI raster stacks, and `shape_site.shp`)

---

## 0.1.6 (2025-01-23)

**General settings:**

- Replaced `raster::raster()` with `sf::st_read()` for ET_ref downloads and averaged values across overlapping pixels  
- Updated RADOLAN data download: switched from `terra::crs()` to `sf::st_crs()` and added pixel aggregation  
- Fixed layer naming in downloaded RADOLAN files (`"lyr_1"` → `"layer"`)  
- Removed `method_NDVI` parameter from documentation and examples

---

## 0.1.5 (2024-11-29)

**General settings:**

- Added horizontal reference line at *y = 0* in water balance plot  
- Added Sentinel-2 as NDVI data source  
- Removed direct NDVI-correlation usage from Arable

---

## 0.1.4 (2024-11-01)

**General settings:**

- Revised `README` ("How to install" and "Using sample data")  
- Added `.csv` (Reference ET) and `.shp` (precipitation) to sample files for faster runs  
- Fixed missing CRS issue in shapefiles  
- Fixed wrong resolution bug in shapefiles and GeoTIFFs

---

## 0.1.3 (2024-10-22)

**General settings:**

- Fixed naming inconsistencies in results  
- Updated README with example usage of sample data

---

## 0.1.2 (2024-10-18)

**General settings:**

- Fixed minor bugs and variable naming

---

## 0.1.1 (2024-10-17)

**General settings:**

- Added sample dataset

---

## 0.1.0 (2024-10-10)

**General settings:**

- Initial commit  
- Created package structure  
- Added source code to package

---
