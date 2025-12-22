# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

#change download path
download_path_source="C:/Users/user/Downloads" #Path to Firefox standard download folder (string)
download_path_target="C:/Users/user/target_path" #Target path (string) of processed irrigation data containing -RData file and Shapefiles
Kundennummer="clientnumber" #client number (string)
Benutzername="username" #username (string)
passwort="password" #Password (string)
nozzle_diameter="25_4" #Nozzle diameter [mm] of Nelson SR50 nozzle mounted n sprinkler canon (string, alternatives: "17_8", "20_3", "22_9", "25_4", "27_5", "30_9", "33_0")

WaterBalanceR::DownloadRaindancer(sourcepath=download_path_source,
                                  targetpath=download_path_target,
                                  port=4486L,
                                  client=Kundennummer,
                                  user=Benutzername,
                                  pass=passwort,
                                  waitfor=5,
                                  nozzle_diameter="25_4",
                                  target_crs=32633,
                                  ff_vis="no")



WaterBalanceR::DownloadRaindancerCombineCharts(sourcepath=paste(download_path_target,"/downloaded_files/",sep=""),
                                               targetpath=paste(download_path_target,"/Beregnung_Shapefile/",sep=""),
                                               start_date=paste(substr(Sys.Date(),1,4),"-01-01",sep=""),
                                               nozzle_diameter="25_4")


