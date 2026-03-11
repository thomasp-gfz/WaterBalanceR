<!--
SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
SPDX-License-Identifier: AGPL-3.0-only
-->

---
output: github_document
---

# WaterBalanceR <img src="man/figures/logo.png" align="right" width="120"/>

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/WaterBalanceR)](https://CRAN.R-project.org/package=WaterBalanceR)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![R-CMD-check](https://github.com/<USERNAME>/WaterBalanceR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/<USERNAME>/WaterBalanceR/actions)
<!-- badges: end -->

## Overview

**WaterBalanceR** is an R package for computing and visualizing the **daily soil water balance** in agricultural Systems regarding starch potatoes.  
It integrates multiple open and commercial data sources (DWD, Sentinel-2, Raindancer, Arable) to produce a consistent and reproducible modeling workflow.

The package was developed at the **GFZ Helmholtz Centre for Geosciences** to support precision irrigation, drought monitoring, and crop water balance analysis.

---

## Installation

You can install the latest development version directly from GitHub:

```r
# install.packages("devtools")
devtools::install_github("thomasp-gfz/WaterBalanceR_Git/WaterBalanceR")
```

Or from CRAN:

```r
install.packages("WaterBalanceR")
```

---

## Key features

- Automated download and preprocessing of meteorological, satellite and irrigation data  
- Computation of daily water balance components for starch potatoes (precipitation, ET₀, irrigation, deficit)  
- Export to GeoTIFF, shapefile and `.RData` formats  
- Integrated plotting tools for visualization and reporting  
- Fully reproducible and compatible with open DWD data  

---

## Example workflow

```r
library(WaterBalanceR)

# Example data included with the package
mypath <- system.file("sample_data", package = "WaterBalanceR")
shape_site <- file.path(mypath, "Shapefile/sample_2023.shp")
et0_file   <- file.path(mypath, "DWD_ET0_2023.csv")
precip_dir <- file.path(mypath, "Radolan_2023_processed_daily")
irrig_file <- file.path(mypath, "Shapefile/Buffer_36m_all_interp.shp")

# Run the daily water balance model
test_wb <- calcWB(
  mypath = mypath,
  shape_site = shape_site,
  target_res = 10,
  last_NDVI_0 = 132,
  ET_ref = read.csv(et0_file),
  ET_ref_dl = "DWD",
  path_WR_precip = precip_dir,
  precip_source = "radolan",
  irrig_sf = irrig_file,
  irrigation_efficiency = 1.0,
  output_year = 2023,
  save_shape = TRUE,
  save_geotiff = TRUE,
  save_RDATA = TRUE
)

# Visualize results
buffer20 <- file.path(mypath, "Shapefile/Buffer_5_WB.shp")
calcWBplots(
  source_path = file.path(
    mypath, "radolan_1_132_10",
    "WBR_radolan_1_132_10.RData"
  ),
  plant_doy = 109,
  buffer20 = buffer20,
  shape_site = shape_site
)
```

---

## Documentation and vignettes

Comprehensive usage examples and workflows are provided in the package vignettes:

- [**WaterBalanceR Workflow**](vignettes/WaterBalanceR_Workflow.Rmd)  
  End-to-end demonstration using the sample dataset.

- [**WaterBalanceR Data Sources**](vignettes/WaterBalanceR_DataSources.Rmd)  
  Detailed overview of all input data download and preprocessing functions.

After installation, you can view them directly in R:

```r
vignette("WaterBalanceR_Workflow")
vignette("WaterBalanceR_DataSources")
```

---

## Folder structure after model run

```
sample_data/
 ├── radolan_1_132_10/
 │    ├── WBR_radolan_1_132_10.RData
 │    ├── WaterBalance_2023_doy_masked_132.tif
 │    ├── ET0_2023_doy_masked_132.tif
 │    ├── Niederschlag_2023_doy_masked_132.tif
 │    └── Plots/
 │         ├── WB_daily_109.jpg
 │         ├── ET_cumulative_2023.pdf
 │         └── NDVI_series_2023.jpg
```

---

## Citation

If you use **WaterBalanceR** in your work, please cite:

> Piernicke, T. (2025). *WaterBalanceR: Modular soil-water balance modeling workflow.*  
> GFZ German Research Centre for Geosciences, Potsdam.  
> [https://github.com/thomaspiernicke/WaterBalanceR](https://github.com/thomaspiernicke/WaterBalanceR)

---

## License

This package is distributed under the **GNU Affero General Public License (AGPL-3.0)**.  
See the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

Developed at the **GFZ Helmholtz Centre for Geosciences**, Section Hydrology,  
as part of research on **integrated water management and precision agriculture**.

---

## Session info

```r
sessionInfo()
```
