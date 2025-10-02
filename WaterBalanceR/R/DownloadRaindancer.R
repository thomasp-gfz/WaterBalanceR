# SPDX-FileCopyrightText: 2025 GFZ Helmholtz Centre for Geosciences
# SPDX-FileCopyrightText: 2025 Thomas Piernicke <thomasp@gfz.de>
# SPDX-License-Identifier: AGPL-3.0-only

#' Scrapes data from Raindancer user account for all logged sprinklers.
#' Beware: It only downloads the last 10.000 logs (~12 days).
#' Requirements: Java and Firefox must be installed on your machine.
#' @param sourcepath Path (string) to Firefox download folder. Look it up in your Firefox browser.
#' @param targetpath Path (string) to destination folder for downloaded csv-files from Raindancer.
#' @param port You need to open a port to let R and Java scrape the website´s data (default: 4486L).
#' @param client Raindancer client number
#' @param user Raindancer user account
#' @param pass Raindancer password
#' @param waitfor time to wait for loading websites. The quicker your computer and internet connection, the less it can be (integer). Default is 3.
#' @param nozzle_diameter diameter of nozzle in mm (string, e.g. 17_8 = 17.8 mm). Default is "25_4".
#' @param target_crs target crs
#' @return csv file for all irrigation events of all sprinklers, that are logged in Raindancer Account.
#' @export
#' @importFrom magrittr %>%

DownloadRaindancer=function(sourcepath,
               targetpath,
               port=4486L,
               client,
               user,
               pass,
               waitfor=3,
               nozzle_diameter="25_4",
               target_crs=32633){

  # Start RSelenium driver with Firefox
  driver=RSelenium::rsDriver(browser="firefox",port=port,chromever = NULL, verbose=F, check=F)
  driver$client$closeWindow() # Close initial session window (not needed)
  #rm(driver)

  # Connect to the Selenium remote driver
  remDr <- RSelenium::remoteDriver(browserName="firefox",port=port,remoteServerAddr="localhost")
  remDr$open(silent=T)

  # Navigate to Raindancer login page
  remDr$navigate("https://portal.myraindancer.com/Login/Login.aspx")
  Sys.sleep(waitfor)

  # --- LOGIN SEQUENCE ---

  # Send client number
  clientnr <- remDr$findElement(using = "id", value = "clientnr_field")
  clientnr$clearElement()
  clientnr$sendKeysToElement(list(as.character(client)))

  # Send username
  username <- remDr$findElement(using = "id", value = "username_field")
  username$clearElement()
  username$sendKeysToElement(list(as.character(user)))

  # Send password + press Enter
  passwd <- remDr$findElement(using = "id", value = "password_field")
  passwd$clearElement()
  passwd$sendKeysToElement(list(as.character(pass), "\uE007"))

  # --- SCRAPE SPRINKLER LIST ---
  #get names and links for sprinklers and combine them to a table
  Sys.sleep(waitfor) # wait for dashboard to load

  # Get sprinkler table (HTML element with irrigator grid)
  get_name_rain=remDr$findElement(using="xpath", value="//*[@id='ctl00_CPH_MainContent_IrrigatorGrid_GridData']")

  # Convert HTML table to dataframe
  get_name_rain_tab = rvest::read_html(get_name_rain$getElementAttribute('innerHTML')[[1]]) %>%
    rvest::html_table() %>% .[[1]]

  # Initialize sprinkler metadata table (Name, ID, GUID)
  regner_tabelle=as.data.frame(matrix(NA,nrow(get_name_rain_tab),3))
  names(regner_tabelle)=c("Regner","ID","GUID")
  regner_tabelle[,1]=get_name_rain_tab[,2]

  # Extract sprinkler IDs and GUIDs
  for(j in 0:(nrow(regner_tabelle)-1)){
    get_link_rain=remDr$findElement(using="xpath", value=paste("//*[@id='ctl00_CPH_MainContent_IrrigatorGrid_ctl00__",j,"']",sep=""))
    get_link_rain_tab = rvest::read_html(get_link_rain$getElementAttribute('innerHTML')[[1]])%>%
      rvest::html_nodes("td") %>%
      rvest::html_nodes("p") %>%
      rvest::html_nodes("a") %>%
      rvest::html_attr("href")
    regner_tabelle[(j+1),2]=paste("ctl00_CPH_MainContent_IrrigatorGrid_ctl00__",j,sep="")
    regner_tabelle[(j+1),3]=stringr::str_split(get_link_rain_tab,"=")[[1]][3]
  }

  # --- DOWNLOAD PROTOCOLS FOR EACH SPRINKLER ---

  for (i in 1:nrow(regner_tabelle)){
    # Navigate to sprinkler detail page
    remDr$navigate(paste("https://portal.myraindancer.com/Settings/RainerDetails.aspx?ai=settings&guid=",
                         regner_tabelle[i,3],sep=""))

    # Download usage protocol (Einsatzprotokoll)
    dwld_Einsatzprotokoll_Button = remDr$findElement("id", value="CPH_MainContent_ExportToExcelMission_btn")
    dwld_Einsatzprotokoll_Button$clickElement()

    # Switch to coordinate protocol tab
    switch_coordprotokoll_Button = remDr$findElement("xpath", "//*[@for='coordProtokoll']")
    switch_coordprotokoll_Button$clickElement()

    # Download coordinate protocol
    dwld_coordprotokoll_Button = remDr$findElement("id", value="CPH_MainContent_ExportToExcelCoordinates_btn")
    dwld_coordprotokoll_Button$clickElement()
    print(paste("Download",i,"/",nrow(regner_tabelle),"done",sep=" "))
  }

  # --- LOGOUT ---
  logout_button = remDr$findElement("id", value="navbarLeftLogoutContainer")
  logout_button$clickElement()
  print("logged out")

  # Close Selenium windows and server
  remDr$closeWindow()#close session
  remDr$closeServer()#close Server
  #driver$server$stop()#close Server
  #driver$client$closeServer()#close Server
  driver[["server"]]$stop()
  print("drivers closed")

  # --- FILE MANAGEMENT ---

  # List files in Firefox download folder
  list_downloaded_files=list.files(sourcepath)

  # Filter only relevant recently downloaded files (protocols, last ~10 minutes)
  list_downloaded_files_recent=list_downloaded_files[is.na(stringr::str_match(list_downloaded_files,"Einsatzprotokoll"))==F |
                                                       is.na(stringr::str_match(list_downloaded_files,"Koordinatenprotokoll"))==F &
                                                       (strptime(substr(list_downloaded_files,nchar(list_downloaded_files)-21,nchar(list_downloaded_files)-5),format='%Y-%m-%d_%H%M%S')>Sys.time()-60000)==T]

  # Create timestamped subfolder for file storage
  folder_time=gsub("-","_",gsub(":","_",gsub(" ","_",substr(Sys.time(),1,19))))
  if(dir.exists(file.path(targetpath,"/downloaded_files",folder_time,sep="/"))==F){
    dir.create(file.path(targetpath,"/downloaded_files",folder_time,sep="/"), showWarnings = FALSE, recursive=TRUE)
  }

  # Move files from download folder → target folder
  file.copy(paste(sourcepath,list_downloaded_files_recent,sep="/"),
            paste(targetpath,"/downloaded_files",folder_time,list_downloaded_files_recent,sep="/"))

  # Remove original files from Firefox download folder
  file.remove(paste(sourcepath,list_downloaded_files_recent,sep="/"))
  print("files successfully copied")

  print("Done")

  # --- POSTPROCESSING: COMBINE ALL FILES INTO ONE DATASET ---

  # Create shapefile output folder if missing
  if(dir.exists(file.path(paste(targetpath,"/Beregnung_Shapefile/",sep="")))==F){
    dir.create(file.path(paste(targetpath,"/Beregnung_Shapefile/",sep="")), showWarnings = FALSE, recursive=TRUE)
  }

  # Run function to combine CSVs → shapefiles
  WaterBalanceR::DownloadRaindancerCombineCharts(sourcepath=paste(targetpath,"/downloaded_files/",sep=""),
                                           targetpath=paste(targetpath,"/Beregnung_Shapefile/",sep=""),
                                           start_date=paste(substr(Sys.Date(),1,4),"-01-01",sep=""),
                                           nozzle_diameter=nozzle_diameter,
                                           target_crs=target_crs)
}


