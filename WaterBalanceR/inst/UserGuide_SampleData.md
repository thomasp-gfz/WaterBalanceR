# WaterBalanceR – User Guide

## Overview

**WaterBalanceR** is an open-source R package for estimating spatially distributed daily water balance for starch potatoes in Germany.  
It combines NDVI data from UAVs (DJI Phantom 4 Multispectral) or satellites (PlanetScope, Sentinel-2) with meteorological data and irrigation logs to support **precision irrigation management**.

Developed within the **AgriSens-DEMMIN 4.0** project, the package allows site-specific decision-making at high spatial resolution (up to 3–5 m) and is freely available under the **AGPL-3.0-only** license.

---

## Installation

1. Clone or download the WaterBalanceR repository.  
2. Open the file `install_WaterBalanceR.R` in **RStudio**.  
3. Set your working directory in the line:
   ```r
   wd <- "path/to/WaterBalanceR"
   ```
4. Run the script to install dependencies and compile the package.

---

## Sample Data

A folder `sample_data` is included to test the model workflow.

### Contents
- **NDVI-Files/** → Example NDVI data (DJI, PlanetScope, Sentinel-2)
- **Shapefile/** → AOI (`sample_2023.shp`), irrigation data (`Buffer_36m_all_interp.shp`), POIs (`Buffer_5_WB.shp`)
- **Radolan_2023_processed_daily/** → Daily precipitation shapefiles
- **DWD_ET0_2023.csv** → Reference evapotranspiration (ET₀)
- **run_calcWB_2023_sample.R** → Example configuration file

---

## Running the Model

### 1️⃣ Configure
Edit `run_calcWB_2023_sample.R`:
```r
mypath <- "path/to/your/working_directory"
```
All other parameters can stay as in the sample file.

### 2️⃣ Run
Run the script to execute:
- `calcWB()` → Calculates water balance maps and saves results as `.shp`, `.tiff`, and `.RData`
- `calcWBplots()` → Generates visualization plots for selected points (`Buffer_5_WB.shp`)

### 3️⃣ Output
Results are saved in a folder named after your configuration, e.g.:
```
radolan_1_132_5/
```
(= RADOLAN precipitation source, irrigation efficiency 1.0, last NDVI=0 on DOY 132, 5 m resolution)

---

## Main Modules

| Module | Purpose | Key Input | Output |
|--------|----------|------------|---------|
| **calc_wb** | Core water balance computation | NDVI rasters, shapefiles, ET₀, precipitation, irrigation data | `.shp`, `.tiff`, `.RData` |
| **DownloadET0fromDWD** | Download reference ET₀ data | AOI shapefile, year | CSV of daily ET₀ |
| **DownloadET0fromArable** | Download ET₀ from Arable API | AOI shapefile, login credentials | CSV of daily ET₀ |
| **DownloadRadolanfromDWD** | Download precipitation data | AOI shapefile, date range | Precipitation shapefiles |
| **DownloadSentinel2** | Fetch Sentinel-2 imagery from Copernicus | AOI shapefile, date range, credentials | NDVI-ready TIFFs |
| **DownloadRaindancer** | Scrape irrigation logs | Firefox + Java, user credentials | `.xlsx` logs |
| **DownloadRaindancerCombineCharts** | Merge and clean irrigation logs | Downloaded `.xlsx` files | Shapefiles of irrigation data |
| **calcWBplots** | Generate daily maps and time series | `.RData`, AOI & POI shapefiles | `.png` composite maps |

---

## Input Parameters

Abridged from `run_calcWB.R`:

| Parameter | Description | Example |
|------------|-------------|----------|
| `shape_site` | AOI shapefile | `"sample_2023.shp"` |
| `precip_source` | Precipitation source (`"radolan"` or `"furuno"`) | `"radolan"` |
| `path_WR_precip` | Path to precipitation data (optional) | `"Radolan_2023_processed_daily/"` |
| `ET_ref` | Reference ET file (CSV) or NA | `"DWD_ET0_2023.csv"` |
| `irrig_sf` | Irrigation shapefile | `"Buffer_36m_all_interp.shp"` |
| `irrigation_efficiency` | Efficiency of irrigation (0–1) | `1` |
| `target_res` | Output resolution (m) | `5` |
| `last_NDVI_0` | DOY before visible vegetation | `132` |
| `output_year` | Processing year | `2023` |

---

## Visualization

Use:
```r
calcWBplots(
  source_path = "path/to/WBR_radolan_poly_1_132_5.RData",
  plant_doy = 109,
  buffer_20 = "Buffer_5_WB.shp",
  shape_site = "sample_2023.shp"
)
```

Generates:
- Daily composite maps (`/wallpapers/`)
- Time series for NDVI, Kc, ETc, precipitation, irrigation, and water balance

---

## System Requirements

- **OS:** Windows or GNU/Linux  
- **R version:** ≥ 4.4  
- **Dependencies:** `sf`, `raster`, `terra`, `rdwd`, `ggplot2`, `Rselenium`, `httr2`, `openeo`, `tidyverse`, etc. (see full list in README)

---

## Acknowledgements
Developed at **GFZ Helmholtz Centre for Geosciences**, Potsdam, with support from  
**Martin-Luther-University Halle-Wittenberg** and **Arable Labs Inc.**

**Funding:** German Federal Ministry of Food and Agriculture (BMEL)  
Project: *AgriSens-DEMMIN 4.0* (FKZ 28DE114A18 & 28DE114A22)

---

## Citation

If you use *WaterBalanceR*, please cite:

> Piernicke, T., Kunz, M., Itzerott, S., & Conrad, C. (2025).  
> *WaterBalanceR: An R Package for Estimating Water Balance for Starch Potatoes in Germany Based on NDVI Values Provided by Sentinel-2, PlanetScope or DJI Phantom 4 Multispectral UAV.*  
> GFZ Helmholtz Centre for Geosciences, Potsdam. DOI: [10.5281/zenodo.15046338](https://doi.org/10.5281/zenodo.15046338)
