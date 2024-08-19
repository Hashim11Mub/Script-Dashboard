

# RSZA-DEPR
# Environmental Monitoring

#################################################################
# INTERPOLATION OF CTD CASTS IN THE RSP AND AMAALA AREAS        #  
# V 2.0                                                         #
# Previous version V1.0                                         #
#
#################################################################

# Raul Vilela 
# Raul.VilelaPerez@RedSeaGlobal.com
# 15.05.2024

# Supporting documentation
# https://rpubs.com/Dr_Gurpreet/interpolation_idw_R
# https://mgimond.github.io/Spatial/interpolation-in-r.html
# https://rspatial.org/terra/analysis/4-interpolation.html
# https://cran.r-project.org/web/packages/ipdw/vignettes/ipdw2.html

# 1. Set writing directory and load libraries -----------------------------
  #setwd("M:/SEZ DES/Science and Monitoring (SM)/Workstreams/Environmental Monitoring/Marine/001DATA")

setwd("C:/Users/RPerez/Desktop/001DATA")

  library(readr)
  library(dplyr)
  library(readxl)
  library(stringr)
  library(tibble)
  library(writexl)
  library(lubridate)
  library(sf)
  library(kml)
  library(ggplot2)


# Load accesory files 

load("M:/SEZ DES/Science and Monitoring (SM)/Workstreams/Environmental Monitoring/Marine/002ANALYSIS/GIS/gis_geo.RData")


# 2. Process files --------------------------------------------------------


# Look for xlsx files, transform to csv and remove xlsx
files <- list.files(path = ".", pattern = "CTD.*cast.*\\.xlsx$", ignore.case = TRUE, recursive = TRUE, full.names = FALSE)


for (file in files) {
  # Read the xlsx file
  data <- read_excel(file)
  
  # Create a csv filename by replacing the xlsx extension
  csv_file <- sub("\\.xlsx$", ".csv", file)
  
  # Write the data frame to a CSV file
  write.csv(data, csv_file, row.names = FALSE)
}

for (file in files) {
file.remove(file)
}

###########

  # Check out for available dates in the meta table

    meta <- read_excel("META_EnvironmentalData.xlsx", sheet= "CTDCast") # space in SiteID removed
    names(meta)

# list areas, quarter and areas
    meta_summary <- meta %>% filter(!is.na(FILENAME)) %>% 
      mutate(Year = year(Date), Month = month(Date)) %>%
      group_by(`Project area`, Project, Year, Quarter, Date) %>%
      summarize(Count = n(), .groups = 'drop')

    print(meta_summary)

# Specify Area and Quarter
    A <- "AMA" # "AMA" "RSP"
    Q <- "Q2 2023"
    unique(meta$Quarter)
    
# Review
    meta_filtered_summary <- meta  %>% 
      filter(`Project area` == A, Quarter == Q)  %>%
      group_by(`Project area`, Project, Quarter, Date) %>%
      summarize(Count = n(), .groups = 'drop')
    meta_filtered_summary

  # for Q3 2023, data was collected in September (64 stations) and July (73 stations)
    M <- 5
    
    names(meta)

    CTDfiles <-  meta  %>% 
      mutate(Month = month(Date)) %>%
      filter(`Project area` == A, Quarter == Q, Month == M) %>% 
      filter(!is.na(FILENAME)) %>% 
      dplyr::select (c(1,3,5,12, 13, 14, 25, 26))   %>% 
      mutate_at(vars(Latitude, Longitude), ~ as.numeric(., na.rm = TRUE))

    unique(CTDfiles$Date)
    unique(CTDfiles$FILENAME)

  # Plotting the map
    ama_geo <- st_read("C:/Users/RPerez/Downloads/AMAALA boundary.kml", quiet = TRUE)
  
    map_plot <- ggplot() +
      geom_point(data = CTDfiles, aes(x = Longitude, y = Latitude, color = Project), 
                 position = position_jitter(width = 0.001, height = 0.001), alpha = 0.5) +
      geom_sf(data = lagoon_geo, fill= NA, size= 1) +
      geom_sf(data = ama_geo, fill= NA, size= 1) +
      geom_sf(data = islands_geo, fill= "grey", size= 1) +
      geom_sf(data = shores_geo, fill= "grey", size= 1) +
      # coord_sf(xlim = c(36.45, 37.1), ylim = c(25.35, 25.9), expand = FALSE) +  #RSP
      coord_sf(xlim = c(35.57, 36.3), ylim = c(26.4, 27.3), expand = FALSE) +   #AMA
      labs(title = "CTD locations by Project",
           x = "Longitude",
           y = "Latitude",
           color = "Project") +
      theme_minimal() + 
    theme(axis.text.x = element_text(angle = 45, hjust = 1))  
    
    map_plot

# Find and download CTD files in shared folder
    
    filenames <- unique(CTDfiles$FILENAME)
    sort(filenames)
    # Build a regular expression pattern to match any of the specified filenames
    pattern <- paste0(filenames, collapse = "|")
    
    # List all matching files in the directory and subdirectories
    file_list <- list.files(path = ".", pattern = pattern, recursive = TRUE, full.names = TRUE)

    # check that the list match the filenames in META
    vector2_clean <- str_remove_all(file_list, ".*/|\\.xlsx$")
    
    # Create data frames
    df1 <- tibble(name1 = filenames)
    df2 <- tibble(name2 = vector2_clean)
    
    # Perform the comparison using a cross join and filter to find matches
    results <- df1 %>%
      cross_join(df2) %>%
      filter(str_detect(name2, name1)) %>%
      dplyr::select(name1, name2)
    
    # Extract matched and unmatched
    matched <- unique(results$name1)
    non_matched <- setdiff(filenames, matched)

    
    # Load all the matching CSV files into a list of data frames
    csv_files <- lapply(file_list, function(x) read.csv(x, stringsAsFactors = FALSE))
    
    
    # check number of columns in dataframes (21 or 23)
    
    cols21 <- sapply(csv_files, ncol) == 21 
    cols23 <- sapply(csv_files, ncol) == 23 
    dfs21 <- csv_files[cols21]
    names(csv_files[cols21])
    dfs23 <- csv_files[cols23]
    names(csv_files[cols23])
    
      
    remove_columns <- function(df) {
        df <- df[, -c(16, 17)]
      return(df)
    }
    
    csv_files[cols23] <- lapply(csv_files[cols23], remove_columns)
    
    
    # first, we standarized column names to avoid further problems
    
    # Define column names
    colnames.csv <- c("Date","Time","Time.frac","Site","Cond","Depth","nLF_cond","ODO_sat","ODO_cb","ODO_mgL",
                      "ORP_mv","psi","psu","SpCond","TDS","Turbid","TSS","pH","pHmV","Temp","Posit","Batt","Pwr")
    
    colnames.csv21 <- c("Date","Time","Time.frac","Site","Cond","Depth","nLF_cond","ODO_sat","ODO_cb","ODO_mgL",
                      "ORP_mv","psi","psu","SpCond","TSS","pH","pHmV","Temp","Posit","Batt","Pwr")
    
    
    # Read CSV files, set column names, and prepare for binding
    csv_files <- lapply(file_list, function(x) {
      df <- read.csv(x, stringsAsFactors = FALSE)
      setNames(df, colnames.csv)
    })
    
    # Extract the third element from file names as IDs
    file_names <- sapply(file_list, function(x) {
      elements <- unlist(strsplit(basename(x), "_"))
      elements[3]
    })
    
    # Bind rows with specific elements of file names as IDs
    combined_data <- dplyr::bind_rows(setNames(csv_files, file_names), .id = "Site")
    combined_data <- combined_data %>% dplyr::select(1:23)
    
    combined_data$Date <- as.Date(combined_data$Date,"%Y-%m-%d")
    
    saveRDS(combined_data , "CTD_Data_ama_may23.rds")
    #write.csv2(csv.df , "CTD_DataAug22.csv")
    
    
    # Get file ready for plotting (subset by depth range and date)
    combined_data <- readRDS("../../../002ANALYSIS/CTD_DataFeb23.rds")
 
    # Summarize by depth range
    min.depth <-  0.5  # specify depth range
    max.depth <- 1.5
    
    names(combined_data)
    df.interp <-  combined_data %>% remove_rownames() %>% 
      dplyr::select (-c(1,2,3,21,22,23)) %>% # for 23 columns
      #dplyr::select (-c(1,2,3,19, 20, 21,22)) %>% # for 21 columns
      filter(Depth <= max.depth & Depth >= min.depth) %>% group_by(Site) %>% summarise_all(mean)
    
    df.interp[duplicated(df.interp[,1]),] # find duplicated stations 
    
    
    site.data <-  meta  %>% filter(`Project area`== "AMA") %>% dplyr::select (c(12,13,14)) %>% rename(Site = SITE) %>% na.omit  %>%
      mutate_at(vars(Latitude, Longitude), ~ as.numeric(., na.rm = TRUE))
    # mutate_if(is.character, as.numeric)  
    
    # Ensure both dataframes are tibbles for dplyr functionality
    df.interp <- as_tibble(df.interp)
    site.data <- as_tibble(site.data)
    
    # Merge df.interp with site.data using a left join on the 'Site' column
    distinct_site_data <- site.data %>%
      group_by(Site) %>%
      slice(1) %>%
      ungroup()
    
    # Now perform the left join
    df.interp.st <- df.interp %>%
      left_join(distinct_site_data, by = "Site")
    
    # Display the structure of the combined data to verify the join
    str(df.interp.st)
    
    
    write_xlsx( df.interp.st, "ctd_casts_SST_ama_may23.xlsx")
    
    
    # 3. IDW interpolation ----------------------------------------------------
    
    # Once that the aggregated table has been saved, we can start directly from here to perform the interpolation
    
    library(sf)
    library(terra)
    require(rgdal)
    library(raster)
    library(gstat) # Use gstat's idw routine
    library(sp)    # Used for the spsample function
    library(tmap) # for plotting
    
    # Read the excel file with the aggregated parameters by station and depth range (as defined in section 2)
    df.interp.st <- read_xlsx("ctd_casts_SST_oct23.xlsx")

    P <- df.interp.st
    P <- P[complete.cases(P$Latitude),]
    coordinates(P) <-  c("Longitude", "Latitude") # mirar porque CTD 122 no copia las coordenadas
    crs(P) <- crs("EPSG:4326")
    
    # Load accesory files
    load("../../../002ANALYSIS/GIS/gis_geo.RData")
    ama_geo <- st_read("C:/Users/RPerez/Downloads/AMAALA boundary.kml", quiet = TRUE)
    ama_geo_xy <- st_zm(ama_geo, what = "ZM")

    ama_sp <- as(ama_geo_xy, "Spatial")
    
    # Create prediction grid
    # For the entire lagoon
    
    lagoon <- st_zm(lagoon_geo)
    lagoon.sp <- as(lagoon, "Spatial")
    grd <- as.data.frame(spsample(lagoon.sp, "regular", n=50000))  #for rsp
     grd <- as.data.frame(spsample(ama_sp, "regular", n=50000)) #for ama
    
    # For the extension of the sampling points
    # grd <- as.data.frame(spsample(P, "regular", n=50000))
    
    # Process prediction grid
    names(grd)       <- c("X", "Y")
    coordinates(grd) <- c("X", "Y")
    gridded(grd)     <- TRUE  # Create SpatialPixel object
    fullgrid(grd)    <- TRUE  # Create SpatialGrid object
    
    # Add P's projection information to the empty grid
    proj4string(grd) <- proj4string(P)
    
    tmaptools::palette_explorer() # available palettes for plotting
    
    # 3.1. SST plot -----------------------------------------------------------
    summary(P$Temp)
    P.filter <- subset(P, Temp > 25)
    # Interpolate the grid cells using a power value (idp) of 3.5
    names(P)
    P.idw <- gstat::idw(Temp ~ 1, P.filter, newdata=grd, idp=3.5)
    
    # Transform to raster object then clip to lagoon
    r <- raster(P.idw)
    r.m <- mask(r, lagoon)
    r.m <- mask(r, ama_sp)
    plot(r.m)
    
    plot_SST <- tm_shape(r.m, bbox = ama_sp) + #lagoon
      tm_raster(n=6,palette = "-RdBu", stretch.palette = TRUE,  #"-RdBu"
                title="May 2023 \nSea Surface Temperature \n[°C]", style= "equal", #Sea Surface Temperature \n(C)
                contrast = c(0.1, 0.5)) + 
      tm_shape(P.filter) + tm_dots(size=0.02) +
      #tm_shape(lagoon_geo) +  tm_borders() +
      #tm_shape(islands_geo)  + tm_polygons() +
      tm_shape(ama_sp)  + tm_borders() +
      tm_shape(shores_geo)  + tm_polygons() +
      tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
      tm_grid(ticks = TRUE, lines=FALSE, labels.size = 0.8) + 
      tm_xlab("Longitude", size = 1.2, rotation = 0, space = 0) +
      tm_ylab("Latitude", size = 1.2, rotation = 90, space = 0)
    
    # Export to jpeg
    plot_SST
    tmap_save(plot_SST, "../../../002ANALYSIS/sst_interp_Feb23.jpeg", width=1920, height=1080)
    
    # 3.2. O2 plot -----------------------------------------------------------
    
    # Interpolate the grid cells using a power value (idp) of 3.5
    names(P)
    P.idw <- gstat::idw(ODO_mgL ~ 1, P, newdata=grd, idp=3.5)
    
    # Transform to raster object then clip to lagoon
    r <- raster(P.idw)
    r.m <- mask(r, ama_sp)
    # plot(r.m)
    
    plot_O2 <- tm_shape(r.m, bbox = ama_sp) + 
      tm_raster(n=6,palette = "Purples", stretch.palette = TRUE,  
                title="May 2023 \nDissolved oxygen \n[mg/L]", style= "equal", 
                contrast = c(0.1, 0.5)) + 
      tm_shape(P) + tm_dots(size=0.02) +
      #tm_shape(lagoon_geo) +  tm_borders() +
      #tm_shape(islands_geo)  + tm_polygons() +
      tm_shape(ama_sp)  + tm_borders() +
      tm_shape(shores_geo)  + tm_polygons() +
      tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
      tm_grid(ticks = TRUE, lines=FALSE, labels.size = 0.8) + 
      tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
      tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)
    
    # Export to jpeg
    plot_O2
    tmap_save(plot_O2, "../../../002ANALYSIS/O2_interp_Feb23.jpeg", width=1920, height=1080)
    
    # 3.3. pH plot -----------------------------------------------------------
    
    summary(P$pH)
    P.filter <- subset(P, pH > 7)
    
    # Interpolate the grid cells using a power value (idp) of 3.5
    names(P)
    P.idw <- gstat::idw(pH ~ 1, P.filter, newdata=grd, idp=3.5)
    
    # Transform to raster object then clip to lagoon
    r <- raster(P.idw)
    r.m <- mask(r, ama_sp)
    plot(r.m)
    
    plot_pH <- tm_shape(r.m, bbox = ama_sp) + 
      tm_raster(n=6,palette = "PuRd", stretch.palette = TRUE,  
                title="May 2023 \n pH", style= "equal", 
                contrast = c(0.1, 0.5)) + 
      tm_shape(P.filter) + tm_dots(size=0.02) +
      #tm_shape(lagoon_geo) +  tm_borders() +
      #tm_shape(islands_geo)  + tm_polygons() +
      tm_shape(ama_sp)  + tm_borders() +
      tm_shape(shores_geo)  + tm_polygons() +
      tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
      tm_grid(ticks = TRUE, lines=FALSE, labels.size = 0.8) + 
      tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
      tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)
    
    # Export to jpeg
    plot_pH
    tmap_save(plot_pH, "../../../002ANALYSIS/pH_interp_Feb23.jpeg", width=1920, height=1080)
    
    
    # 3.4. PSU plot -----------------------------------------------------------
    
    # Interpolate the grid cells using a power value (idp) of 3.5
    names(P)
    range(P$psu)
    
    P.filter <- subset(P, psu > 35)
    
    hist(P$psu)
    summary(P$psu)
    P.idw <- gstat::idw(psu ~ 1, P.filter, newdata=grd, idp=3.5)
    
    # Transform to raster object then clip to lagoon
    r <- raster(P.idw)
    r.m <- mask(r, ama_sp)
    plot(r.m)
    
    plot_psu <- tm_shape(r.m, bbox = ama_sp) + 
      tm_raster(n=6,palette = "YlGn", stretch.palette = TRUE,  
                title="May 2023 \nPSU", style= "equal", 
                contrast = c(0.1, 0.5)) + 
      tm_shape(P.filter) + tm_dots(size=0.02) +
      #tm_shape(lagoon_geo) +  tm_borders() +
      #tm_shape(islands_geo)  + tm_polygons() +
      tm_shape(ama_sp)  + tm_borders() +
      tm_shape(shores_geo)  + tm_polygons() +
      tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
      tm_grid(ticks = TRUE, lines=FALSE, labels.size = 0.8) + 
      tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
      tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)
    
    # Export to jpeg
    plot_psu
    tmap_save(plot_psu, "../../../002ANALYSIS/psu_interp_Feb23.jpeg", width=1920, height=1080)
    
    
    # 3.4b. TDS plot -----------------------------------------------------------
    tmaptools::palette_explorer()
    # Interpolate the grid cells using a power value (idp) of 3.5
    names(P)
    range(P$TDS)

    hist(P$TDS)
    P.idw <- gstat::idw(TDS ~ 1, P.filter, newdata=grd, idp=3.5)
    
    # Transform to raster object then clip to lagoon
    r <- raster(P.idw)
    r.m <- mask(r, ama_sp)
    plot(r.m)
    
    plot_tds <- tm_shape(r.m, bbox = ama_sp) + 
      tm_raster(n=6,palette = "YlOrBr", stretch.palette = TRUE,  
                title="May 2023 \nTotal Dissolved Solids \n [mg/L]", style= "equal", 
                contrast = c(0.1, 0.5)) + 
      tm_shape(P.filter) + tm_dots(size=0.02) +
      #tm_shape(lagoon_geo) +  tm_borders() +
      #tm_shape(islands_geo)  + tm_polygons() +
      tm_shape(ama_sp)  + tm_borders() +
      tm_shape(shores_geo)  + tm_polygons() +
      tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
      tm_grid(ticks = TRUE, lines=FALSE, labels.size = 0.8) + 
      tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
      tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)
    
    # Export to jpeg
    plot_tds
    tmap_save(plot_psu, "../../../002ANALYSIS/psu_interp_Feb23.jpeg", width=1920, height=1080)
    
    # stats
    nrow(df.interp.st)
    summary(df.interp.st)
    unique(CTDfiles$Date)
    
    nrow(P.filter)
    summary(P.filter)
    
    # 3.5. Only sampling points plot -----------------------------------------------------------

    
    #RSP
    class(P)
    P_sub <- P[P@data$Site %in% c("OWS006", "OWS024"), ]
    P_sub <- P[P@data$Site %in% c("UMQ002", "SHI003"), ] 
    
    #AMA   
    P_sub <- P[P@data$Site %in% c("OWS178", "OWS184", "OWS161", "OWS075"), ] 
    
    
    plot_points <- tm_shape(P_sub, bbox = lagoon) + tm_dots(size=1, color="red") +
      #tm_shape(lagoon_geo) +  tm_borders(lty = "dashed") +
      tm_shape(ama_sp)  + tm_borders(lty = "dashed") +
     # tm_shape(islands_geo)  + tm_polygons() +
      tm_shape(shores_geo)  + tm_polygons() +
      tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
      tm_grid(ticks = TRUE, lines=FALSE, labels.size = 1) + 
      tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
      tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)
    plot_points
    # Export to jpeg    
    tmap_save(plot_points, "../analysis/points_interp.jpeg", width=1920, height=1080)
    
    
    #locations and stations
    P_sf <- st_as_sf(P)
    P_sub_sf <- st_as_sf(P_sub)
    coords <- st_coordinates(P_sub_sf)
    
    # Add coordinates to the data frame for easier access
    P_sub_sf$X <- coords[,1]  # Longitude
    P_sub_sf$Y <- coords[,2]  # Latitude
    
    # Plotting the data using ggplot2 with labels
    #RSP
    xlim <- c(36.45, 37.1)  # Replace with actual longitude bounds
    ylim <- c(25.24, 26)    # Replace with actual latitude bounds
    
    #AMA
    xlim <- c(35.57, 36.3)
    ylim <- c(26.4, 27.3)
    
    class(P)

    ggplot() +
      geom_sf(data = lagoon_geo, fill = NA,  color= "grey",alpha = 0.5) + # Polygon for lagoons with semi-transparent blue fill
     # geom_sf(data = ama_geo, fill = NA,  color= "grey",alpha = 0.5) + # Polygon for lagoons with semi-transparent blue fill
      
      geom_sf(data = islands_geo, fill = "grey") + # Polygon for islands with green fill
      geom_sf(data = shores_geo, fill = "grey", color = "black") +  # Lines for shores with brown color
      geom_sf(data = P_sf, color = "black", size = 1) +
    #  geom_sf(data = P_sub_sf, color = "red", size = 2) +
     # geom_text(data=P_sub_sf, aes(label = Site, x = X, y = Y), nudge_x = 0.015, nudge_y = 0.015, check_overlap = TRUE) +
      theme_minimal(base_size = 14) +
      labs(title = "CTD profiles locations (October 2023)",
           x = "Longitude",  # Custom x-axis label
           y = "Latitude",   # Custom y-axis label
           #  size = "Ar [mg/Kg]" 
      ) + # Custom legend title for 'size'
      theme(legend.position = "right") +
      coord_sf(xlim = xlim, ylim = ylim, expand = FALSE)  # Set custom map extent
    
    
    ###########
    
    # anual trend
    CTD_summary23 <- read_excel("CTD_summary23.xlsx")
    
    library(tidyr)
    library(ggplot2)
    library(dplyr)
    library(tidyr)
    
    # Create the data frame
    data <- data.frame(
      Month = c(2, 7, 9, 10),
      min_temp = c(19.04, 30.02, 30.17, 28.7),
      avg_temp = c(20.62, 31.21, 31.79, 30.32),
      max_temp = c(23.26, 32.28, 32.79, 31.1),
      min_psu = c(40.4, 40.74, 40.5, 40.48),
      avg_psu = c(41.89, 42.25, 42.35, 42.34),
      max_psu = c(43.11, 45.26, 45.24, 44.48),
      min_dO = c(6.71, 5.22, 5.31, 5.71),
      avg_dO = c(7.03, 5.75, 5.66, 6.33),
      max_dO = c(7.23, 6.04, 6.48, 7.48),
      min_pH = c(7.9, 8.08, 8.34, 8.04),
      avg_pH = c(8.01, 8.24, 8.56, 8.12),
      max_pH = c(8.06, 8.28, 8.68, 8.17),
      min_dS = c(35.62, 36.44, 36.24, NA),
      avg_dS = c(36.57, 37.7, 37.83, NA),
      max_dS = c(37.39, 40.07, 39.98, NA)
    )
    
    # Reshape the data frame to a long format
    data_long <- data %>%
      pivot_longer(cols = -Month, names_to = c("Stat", "Parameter"), names_sep = "_") %>%
      filter(!is.na(value))
    
    # Print the transformed data to verify
    print(data_long)
    
    # Create the plot with facets for each parameter
    ggplot(data_long, aes(x = factor(Month), y = value, color = Stat, group = Stat)) +
      geom_point() +
      geom_smooth(method = "loess", se = FALSE) +  # Using loess method for smooth lines
      scale_color_manual(values = c("min" = "blue", "avg" = "green", "max" = "red")) +
      labs(y = "Value", x = "Month", color = "Statistics") +
      facet_wrap(~ Parameter, scales = "free_y") +
      theme_minimal() +
      ggtitle("Parameter Values over Months")
    
    ##### END #####
    # Below is just experimental coding for future enhancement of the interpolation plots using ggplot library
    # No finished yet
    
    # ggplot
    library(ggplot2)
    lagoon.sf <- st_as_sf(lagoon)
    islands.sf <- st_as_sf(islands)
    
    ggplot(r.m) +  
      geom_raster( aes(fill=value)) #+ 
    geom_sf (data=islands.sf) #+
    coord_equal()
    
    ggplot() +
      geom_raster(data = r.m , aes(x = x, y = y, fill = value)) + 
      coord_quickmap()
    
    
    #2nd order polynomial interpolation
    
    # Define the 2nd order polynomial equation
    f.2 <- as.formula(Temp..C ~ X + Y + I(X*X)+I(Y*Y) + I(X*Y))
    
    P <- df.interp.sp
    # Add X and Y to P
    P$X <- coordinates(P)[,1]
    P$Y <- coordinates(P)[,2]
    
    # Run the regression model
    lm.2 <- lm( f.2, data=P)
    
    # Use the regression model output to interpolate the surface
    dat.2nd <- SpatialGridDataFrame(grd, data.frame(var1.pred = predict(lm.2, newdata=grd))) 
    
    # Clip the interpolated raster to Texas
    r   <- raster(dat.2nd)
    r.m <- mask(r, lagoon)
    
    # Plot the map
    tm_shape(r.m) + 
      tm_raster(n=10, palette="RdBu", auto.palette.mapping=FALSE,
                title="Predicted precipitation \n(in inches)") +
      tm_shape(P) + tm_dots(size=0.2) +
      tm_shape(lagoon) +  tm_borders() +
      tm_shape(islands)  + tm_polygons() +
      tm_legend(legend.outside=TRUE)
    
    
    
    