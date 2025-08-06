---
title: 'WaterBalanceR: An R-Package for Estimating Water Balance for Starch Potatoes in Germany Based on NDVI Values Provided by Sentinel-2, PlanetScope or DJI Phantom 4 Multispectral UAV'
tags:
  - R
  - irrigation 
  - water balance 
  - potatoes 
  - starch potatoes 
  - DEMMIN 
  - NE Germany 
  - Sentinel-2 
  - PlanetScope 
  - DJI Phantom 4 Multispectral 
  - Arable Mark 2 
  - Multispectral, NDVI
authors:
  - name: Thomas Piernicke
    orcid: 0009-0006-9760-5162
    corresponding: true
    affiliation: "1"
  - name: Matthias Kunz
    orcid: 0000-0002-0541-3424
    affiliation: "1"
  - name: Sibylle Itzerott
    orcid: 0000-0002-4879-8838
    affiliation: "1"
  - name: Christopher Conrad
    orcid: 0000-0002-0807-7059
    affiliation: "2"
affiliations:
 - name: GFZ Helmholtz Centre for Geosciences, 14473 Potsdam, Germany
   index: 1
   ror: 04z8jg394
 - name: Martin-Luther-University, 06108 Halle-Wittenberg, Germany
   index: 2
   ror: 05gqaka33
date: 06 August 2025
bibliography: paper.bib
---

# Summary

**WaterBalanceR** is an R package developed within the BMEL-funded project *AgriSens-DEMMIN 4.0* [@GFZ:2021] and is distributed under the AGPL-3.0-only license. It enables the calculation of spatially distributed, daily water balance maps for starch potatoes at a precision farming scale. This is achieved by combining NDVI data derived from multispectral UAV DJI Phantom 4M, PlanetScope or Sentinel-2 imagery with freely available meteorological data and reference evapotranspiration from the German Weather Service (DWD) [@DWD:2023], using the FAO56 Penman-Monteith method [@Allen:1998] along with specified or downloaded irrigation amounts.

Although originally based on a three-year time series of experiments conducted in the DEMMIN area in northeastern Germany [@Heinrich:2018], the package is applicable across Germany and potentially worldwide. Its modular structure allows for easy extension to other crops. The related experiments and resulted models are currently being published in the open-access journal *Remote Sensing* (MDPI). Results can be exported as shapefiles (`.shp`) for further analysis or as PNGs (`.png`) for quick visual inspection, making it a reproducible and practical tool for researchers and practitioners in precision agriculture.

# Statement of Need

Efficient water management is crucial in agriculture, especially under increasing climatic uncertainty and water scarcity. Potato cultivation in Germany requires significant supplemental irrigation, and from an economic pont of view, irrigated potatoes currently yield the highest additional returns among arable crops due to both increased yields and high market prices [@Bernhardt:2025; @Lüttger:2005; @Pfleger:2010; @Fricke:2022].

The amount of supplemental water needed is highly intra site-specific. Farmers may over- or underestimate crop water demand, creating potential for optimization at the precision farming level [@Wenzel:2022; @Lakhiar:2024; @Delgado:2019; @Cecilia:2022]. **WaterBalanceR** addresses this gap by offering a high-resolution, data-driven decision support tool for intra site-specific irrigation planning, i.e. giving as much water as necessary to cover the plants needs, but as less as possible to avoid any water waste.

By leveraging NDVI data from UAVs and satellites, the package calculates daily water balances at a default spatial resolution of 5 meters. This granularity enables precise irrigation targeting, which can improve yields while conserving water. Although initially developed for DEMMIN, the package is applicable throughout Germany using nationwide available datasets, and (with further validation) globally. Its spatial resolution of up to 3 meters allows optimization of both sprinkler and drip irrigation systems.

Due to its modular architecture, the tool can be easily adapted to other crops in future research. **WaterBalanceR**  serves both applied agricultural decision-making and scientific model development, meeting the growing need for scalable, open-source tools in digital and precision farming.

# Comparison to Existing Software

There are already several software solutions that support irrigation decision-making in agriculture. In Germany, public and partly freely available tools include:

- **AMBAV** [@Löpmeier:1983]
- **ISABEL** [@DWD:2018]
- **Agrowetter Beregnung** (based on the Geisenheimer method, not freely available) [@DWD:2004]

These services are provided by the German Weather Service (DWD). Commercial offerings include:

- [Raindancer](https://www.raindancer.de)
- **ZEPHYR** [@Rickmann:2009]
- [Irricrop by Sencrop](https://sencrop.com/de/beregnung/)
- [GrowSphere by Netafim](https://www.netafim.de/digitale-Landwirtschaft/digital-farming/)

International options include:

- [Arable Labs Inc.](https://www.arable.com/)
- [Pessl Instruments](https://metos.global/de/)

While many of these tools focus on soil moisture conditions for irrigation decision support, which is a more valuable variable than evapotranspiration, since it directly refers to soil conditions, they often lack spatial resolution. Soil moisture sensors are limited to specific points of interest (POIs), and cannot practically be deployed at high densities without interfering with farming practices. As a result, large areas between sensors must be interpolated, risking loss of spatial detail.

Satellite or UAV imagery allows full-field observations, which can resolve this issue. While some providers (e.g. [Pessl Instruments](https://metos.global/en/satellite-imagery/)) already integrate satellite data, their platforms are neither free nor open source. Moreover, cloud cover is a persistent limitation of satellite imagery that can be addressed by integrating UAV imagery.

**WaterBalanceR** fills this gap by offering a free, open-source solution capable of processing both satellite and UAV imagery for water balance modeling at high spatial resolution.

# Functionality

**WaterBalanceR** provides the following core functionalities:

- Calculation of crop coefficient, crop evapotranspiration (ETc), and daily water balance for starch potatoes using NDVI data and FAO56 Penman-Monteith-based ET₀ from DWD \autoref{fig:figure_1}
- Output of water balance and further results as shapefiles (`.shp`) and/or PNGs (`.png`) at a precision farming scale
- Processing of NDVI data from DJI Phantom 4 Multispectral, PlanetScope or Sentinel-2 — freely mixable as input
- Autonomous download and processing of precipitation data:
  - From DWD (RADOLAN)
  - From Furuno X-band radar (if available)
  - From Arable ground stations via API (if deployed on AOI)
- Autonomous download of ET₀ data from DWD or Arable (if deployed on AOI)
- Scraping of irrigation logs (`.xlsx`) from Raindancer portal and processing into shapefiles (requires user account)
- compatibility with other irrigation data (if available as shapefile)
- Optional download of Sentinel-2 imagery (requires user account)

\begin{figure}[htbp]
  \centering
  \includegraphics[width=\textwidth]{figure_1.png}
  \caption{Daily and cumulative maps and time series of NDVI, crop coefficient (Kc), precipitation, irrigation, evapotranspiration (ETc), and water balance for starch potatoes at DOY 182 (73 days after planting). Left: Spatial distribution of variables across the study site. Middle: Time series of key indicators for four selected sample plots. Right: Cumulative values until DOY 182, visualized both spatially and per plot. This figure demonstrates intra-field variability and highlights site-specific irrigation demand and crop water dynamics for precision irrigation management.}
  \label{fig:figure_1}
\end{figure}


# Modules, Routine, and Process Chain

**WaterBalanceR** is composed of eight modular scripts that can be run individually or in sequence using the configuration script `run_calcWB.R` \autoref{fig:figure_2} to calculate and visualize the water balance. Each module corresponds to an R script and function of the same name.

The process chain is initiated through the configuration module `run_calcWB`, which initiates the core module `calc_wb`. This module performs the main processing tasks:

- Loads NDVI data
- Retrieves ET₀ from either `DownloadET0fromDWD` or `DownloadET0fromArable`
- Obtains precipitation data from `DownloadRadolanfromDWD`, or alternatively reads user-supplied RADOLAN or FURUNO shapefiles

Irrigation data can be downloaded and processed using the `DownloadRaindancer` module, generating shapefiles that are compatible with the processing chain. Alternatively, users may provide their own shapefiles containing irrigation depths (in mm).

After preprocessing steps such as resampling, co-registration, correction, and interpolation, the results can be saved as shapefiles, GeoTIFFs or `.RData` files. The `.RData` outputs can be passed to the `calcWBplots` module to generate `.png` visualizations showing intra-site water balance dynamics across the growing season. Optionally, a shapefile of points of interest (POIs) can be included to enable detailed temporal analysis at specific field locations.

\begin{figure}[htbp]
  \centering
  \includegraphics[width=\textwidth]{figure_2.png}
  \caption{Workflow of the WaterBalanceR package showing the integration of remote sensing data (Sentinel-2, PlanetScope, and DJI Phantom 4 Multispectral UAV), meteorological data (from German Weather Service, Arable Mark 2 Ground stations or Raindancer) and irrigation information. The main module handles data download, pre-processing, model-based calculation of daily crop evapotranspiration and water balance, and output generation for decision support. Color-coded elements indicate manual and automatic input, processing steps, and output formats.}
  \label{fig:figure_2}
\end{figure}

# Quality Control and Sample Data

In order to ensure functionality and to release a working R package, the package was tested using `devtools::check()`. Although this resulted in a *"warning"*, it is caused by a non-ASCII-compliant character contained in the Excel files (`.xlsx`) that were scraped from the **Raindancer** website. This issue cannot be resolved at the primary data source but is corrected during the processing stage.

To get familiar with the workflow and test the functionality of the package, a folder containing a sample data set (`sample_data`) is provided in the main branch. It includes:

- A sample set of NDVI files for a site where starch potatoes were cultivated in 2023  
- A folder named `Radolan_2023_processed_daily` containing corresponding RADOLAN precipitation shapefiles  
- A folder named `shapefiles`, which contains:
  - The AOI shapefile (`sample_2023.shp`)  
  - Shapefiles of irrigation data  
    - Original: `Buffer_36m_all_orig.shp`  
    - Interpolated: `Buffer_36m_all_interp.shp`  
  - POI shapefile (`Buffer_5_WB.shp`)  
- `DWD_ET0_2023.csv` containing reference evapotranspiration data for the specified AOI  
- `run_calcWB_2023_sample.R` — the configuration script that runs the water balance model for the sample AOI  
- `run_raindancerscraping.R` — a configuration script to scrape data from the **Raindancer** user portal, if access credentials are available  

The entire folder should be copied to a desired directory to act as a sandbox for testing, as each execution generates and saves results to the local file system.

Additionally, an installation script named `install_WaterBalanceR.R` is available in the main directory and can be used to install the package.

# Acknowledgements

We would like to thank **Arable Labs, Inc.** for providing several Arable Mark 2 and Mark 3 ground stations and for their close cooperation. We also extend our gratitude to the **German Weather Service (DWD)** — especially Falk Böttcher — as well as **Dr. Julia Pöhlitz** and **Jan-Lukas Wenzel** from **Martin-Luther-University Halle-Wittenberg** for their valuable collaboration.

# Funding Information

This work was funded by the **German Federal Ministry of Food and Agriculture** (based on a decision by the German Bundestag) under project numbers FKZ 28DE114A18 and FKZ 28DE114A22 within the scope of the **AgriSens-DEMMIN 4.0** project.

# References









