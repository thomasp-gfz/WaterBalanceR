# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

# Test: calcWB runs successfully for all configurations and produces output files

# --- 1 Base configuration ---
sample_path = system.file("sample_data", package = "WaterBalanceR")
mypath = file.path(tempdir(), "WaterBalanceR_example") #set up temporary directory
dir.create(mypath, showWarnings = FALSE, recursive = TRUE)
library(fs)
dir_copy(sample_path,mypath,overwrite=TRUE)

shape_site = file.path(mypath, "Shapefile/sample_2023.shp")
irrig_sf = file.path(mypath, "Shapefile/Buffer_36m_all_interp.shp")
buffer20 = file.path(mypath, "Shapefile/Buffer_5_WB.shp")
output_year = 2023
last_NDVI_0 = 132
irrigation_efficiency = 1
plant_doy=109
ET_ref = read.csv(file.path(mypath, "DWD_ET0_2023.csv"), sep = ",")
ET_ref_dl="DWD"

# --- 2 Configurations to test ---
configs <- list(
  list(
    name = "RADOLAN_highres",
    precip_source = "radolan",
    path_WR_precip = file.path(mypath, "Radolan_2023_processed_daily"),
    target_res = 5
  ),
  list(
    name = "FURUNO_highres",
    precip_source = "furuno",
    path_WR_precip = file.path(mypath, "Furuno_2023_processed_daily"),
    target_res = 5
  )
)

results=list(NA)
for (i in 1:length(configs)){
  # --- 3 Helper: Run one configuration ---

  message("\n🔧 Running config: ", configs[[i]]$name)
  t_start <- Sys.time()

  test_wb <- tryCatch({
    WaterBalanceR::calcWB(
      mypath = mypath,
      shape_site = shape_site,
      target_res = configs[[i]]$target_res,
      last_NDVI_0 = last_NDVI_0,
      ET_ref = ET_ref,
      ET_ref_dl = ET_ref_dl,
      output_year = output_year,
      path_WR_precip = configs[[i]]$path_WR_precip,
      precip_source = configs[[i]]$precip_source,
      irrig_sf = irrig_sf,
      irrigation_efficiency = irrigation_efficiency,
      save_shape = TRUE,
      save_geotiff = TRUE,
      save_RDATA = TRUE,
      arable_user = "username",
      arable_pass = "password"
    )
  }, error = function(e) e)

  # --- 4 Verify model ran successfully ---
  testthat::expect_false(inherits(test_wb, "error"),
                         info = paste("calcWB() failed for config:", configs[[i]]$name)
  )

  # --- 5 Verify expected outputs ---
  output_prefix <- file.path(
    mypath,
    paste0(configs[[i]]$precip_source, "_", irrigation_efficiency, "_132_", configs[[i]]$target_res)
  )

  expected_rdata <- file.path(
    output_prefix,
    paste0("WBR_", configs[[i]]$precip_source, "_",irrigation_efficiency, "_132_", configs[[i]]$target_res, ".RData")
  )

  # --- 6 Optional plot check (non-blocking) ---
  test_wb_plot <- tryCatch({
    WaterBalanceR::calcWBplots(
      source_path=expected_rdata,
      plant_doy=plant_doy,
      buffer20 = buffer20,
      shape_site = shape_site)
  }, error = function(e) e)

  testthat::expect_true(
    file.exists(expected_rdata),
    info = paste("Missing RData file for config:", configs[[i]]$name)
  )

  expected_tifs <- list.files(paste0(output_prefix,"/wallpapers"), pattern = "\\.png$", full.names = TRUE)
  testthat::expect_true(
    length(expected_tifs) > 0,
    info = paste("No GeoTIFFs found for config:", configs[[i]]$name)
  )

  t_end <- Sys.time()
  runtime <- round(as.numeric(difftime(t_end, t_start, units = "secs")), 1)

  message("Finished config: ", configs[[i]]$name, runtime, " sec)")

  results[[i]]=list(
    config = configs[[i]]$name,
    output = expected_rdata,
    n_tifs = length(expected_tifs),
    runtime_sec = runtime
  )

}
# --- 7 Save summary for manual inspection ---
result_df <- do.call(rbind, lapply(results, as.data.frame))
saveRDS(result_df, file = file.path(tempdir(), "test_calcWB_results.rds"))

message("🗂️ Test summary written to: ", file.path(tempdir(), "test_calcWB_results.rds"))

# --- 8 Summary expectations ---
testthat::expect_true(
  all(sapply(results, function(x) x$n_tifs > 0)),
  info = "At least one configuration produced no GeoTIFF outputs."
)

testthat::expect_true(
  all(sapply(results, function(x) file.exists(x$output))),
  info = "At least one configuration did not generate an RData output."
)


