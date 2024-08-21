# RSZ-DEPR Environmental Monitoring
# Interpolation of CTD Casts in the RSP Area
# Version 2
# Last updated: 2024-08-21

# Load required libraries
library(readr)
library(dplyr)
library(readxl)
library(stringr)
library(writexl)
library(sf)
library(terra)
library(raster)
library(gstat)
library(sp)
library(tmap)
library(ggplot2)
library(oce)

# Set working directory
setwd("C:/Users/RPerez/Desktop/CTDCastsOct2023/CTDCastsOct2023")

# Load accessory files
load("../../../002ANALYSIS/GIS/gis_geo.RData")

# Function to process Excel files
process_excel_files <- function() {
  list <- list.files(path = ".", pattern = "CTD.*Cast", recursive = TRUE, full.names = FALSE)
  list_of_dataframes <- lapply(list, function(file) read_excel(file, sheet = 1))
  
  # Split dataframes based on number of columns
  split_list <- lapply(list_of_dataframes, function(df) {
    if (ncol(df) <= 22) "small" else "large"
  })
  
  small_dfs <- list_of_dataframes[sapply(split_list, function(x) x == "small")]
  large_dfs <- list_of_dataframes[sapply(split_list, function(x) x == "large")]
  
  # Standardize column names
  colnames.large.df <- c("Date","Time","Time.frac","Site","Cond","Depth","nLF_cond","ODO_sat","ODO_cb","ODO_mgL",
                         "ORP_mv","psi","psu","SpCond","TDS", "Turbidity", "TSS","pH","pHmV","Temp","Posit","Batt","Pwr")
  large.files <- large_dfs %>% 
    lapply(setNames, colnames.large.df) %>% 
    dplyr::bind_rows(.id = "SensorID") %>%
    dplyr::select(1:16, 19:24)
  
  colnames.small.df <- c("Date","Time","Time.frac","Site","Cond","Depth","nLF_cond","ODO_sat","ODO_cb","ODO_mgL",
                         "ORP_mv","psi","psu","SpCond","TDS","pH","pHmV","Temp","Posit","Batt","Pwr")
  small.files <- small_dfs %>% 
    lapply(setNames, colnames.small.df) %>% 
    dplyr::bind_rows(.id = "SensorID")
  
  df.merged <- rbind(small.files, large.files)
  df.merged$station <- sapply(strsplit(df.merged$SensorID, split="[_.]"), "[", 3)
  df.merged$Date <- as.Date(df.merged$Date, "%m/%d/%Y")
  
  saveRDS(df.merged, "CTD_DataOct23.rds")
  return(df.merged)
}

# Function to prepare data for interpolation
prepare_interpolation_data <- function(df, min.depth = 0.5, max.depth = 1.5) {
  df.interp <- df %>% 
    dplyr::select(-c(SensorID, Time, Time.frac, Site, Posit, Batt, Pwr)) %>%
    filter(Date > "2023-01-01", Depth <= max.depth, Depth >= min.depth) %>% 
    group_by(station) %>% 
    summarise_all(mean)
  
  metadata <- read_excel("EnvMon_AllSites.xlsx")
  site.data <- metadata %>% 
    filter(ProjectArea == "RSP") %>% 
    dplyr::select(c(3,13,14)) %>% 
    rename(station = SiteName) %>% 
    na.omit() %>%
    mutate_at(vars(Latitude, Longitude), ~ as.numeric(., na.rm = TRUE))
  
  df.interp.st <- left_join(df.interp, site.data, by = "station")
  write_xlsx(df.interp.st, "ctd_casts_Oct23_05_15.xlsx")
  return(df.interp.st)
}

# Function for IDW interpolation and plotting
idw_interpolation_plot <- function(data, variable, title, palette, lagoon) {
  P <- data[complete.cases(data[c("Latitude", "Longitude")]),]
  coordinates(P) <- c("Longitude", "Latitude")
  crs(P) <- crs("EPSG:4326")
  
  lagoon.sp <- as(lagoon, "Spatial")
  grd <- as.data.frame(spsample(lagoon.sp, "regular", n = 50000))
  names(grd) <- c("X", "Y")
  coordinates(grd) <- c("X", "Y")
  gridded(grd) <- TRUE
  fullgrid(grd) <- TRUE
  proj4string(grd) <- proj4string(P)
  
  P.idw <- gstat::idw(as.formula(paste(variable, "~ 1")), P, newdata = grd, idp = 3.5)
  r <- raster(P.idw)
  r.m <- mask(r, lagoon)
  
  plot <- tm_shape(r.m, bbox = lagoon) + 
    tm_raster(n = 6, palette = palette, stretch.palette = TRUE,  
              title = title, style = "equal", 
              contrast = c(0.1, 0.5)) + 
    tm_shape(P) + tm_dots(size = 0.02) +
    tm_shape(lagoon_geo) + tm_borders() +
    tm_shape(islands_geo) + tm_polygons() +
    tm_shape(shores_geo) + tm_polygons() +
    tm_legend(legend.outside = TRUE, legend.text.size = 1, legend.title.size = 1.5) +
    tm_grid(ticks = TRUE, lines = FALSE, labels.size = 0.8) + 
    tm_xlab("Longitude", size = 1.2) +
    tm_ylab("Latitude", size = 1.2)
  
  return(plot)
}

# Function to process CTD casts
process_ctd_casts <- function(df) {
  df.cast <- df %>% 
    dplyr::select(-c(SensorID, Time, Time.frac, Site, Posit, Batt, Pwr)) %>%
    mutate(Depth = -Depth)
  
  unique_categories <- unique(df.cast$station)
  
  list.cast <- list()
  for(i in unique_categories) {
    df <- df.cast %>% dplyr::filter(station == i)
    
    start_index <- which(df$Depth <= -0.5)[1]
    
    data_clean <- df[start_index:nrow(df), ]
    
    turning_point <- which(diff(data_clean$Depth) > 0)[1]
    
    downcast_data <- data_clean[1:turning_point, ]
    
    list.cast[[i]] <- downcast_data
  }
  
  return(list.cast)
}

# Function to plot CTD profiles
plot_ctd_profile <- function(data, station) {
  ggplot() +
    geom_point(data = data, aes(x = Temp, y = Depth, colour = as.factor(Date))) +
    labs(title = paste("CTD Profile for Station", station),
         x = "Temperature (°C)",
         y = "Depth (m)",
         colour = "Date") +
    theme_bw()
}

# Function to perform calibration analysis
calibration_analysis <- function(df, stations) {
  df.calibr <- df %>% 
    filter(station %in% stations, 
           Date > "2023-01-01",
           Depth <= 1.5, Depth >= 0.5)
  
  ggplot(df.calibr, aes(x = as.factor(Date), y = Temp, fill = station)) + 
    geom_boxplot() +
    labs(title = "Temperature Calibration",
         x = "Date",
         y = "Temperature (°C)",
         fill = "Station") +
    theme_bw()
}

# Main execution
main <- function() {
  df.merged <- process_excel_files()
  df.interp.st <- prepare_interpolation_data(df.merged)
  
  lagoon <- st_zm(lagoon_geo)
  
  # Generate plots
  plot_SST <- idw_interpolation_plot(df.interp.st, "Temp", "Sea Surface Temperature (°C)", "-RdBu", lagoon)
  plot_O2 <- idw_interpolation_plot(df.interp.st, "ODO_mgL", "Dissolved oxygen (mg/L)", "Purples", lagoon)
  plot_pH <- idw_interpolation_plot(df.interp.st, "pH", "pH", "PuRd", lagoon)
  plot_psu <- idw_interpolation_plot(df.interp.st %>% filter(psu > 35), "psu", "PSU", "YlGn", lagoon)
  
  # Save plots
  tmap_save(plot_SST, "sst_interp_oct23.jpeg", width = 1920, height = 1080)
  tmap_save(plot_O2, "O2_interp_oct23.jpeg", width = 1920, height = 1080)
  tmap_save(plot_pH, "pH_interp_oct23.jpeg", width = 1920, height = 1080)
  tmap_save(plot_psu, "psu_interp_oct23.jpeg", width = 1920, height = 1080)
  
  # Plot sampling points
  P <- df.interp.st[complete.cases(df.interp.st[c("Latitude", "Longitude")]),]
  coordinates(P) <- c("Longitude", "Latitude")
  crs(P) <- crs("EPSG:4326")
  
  plot_points <- tm_shape(P, bbox = lagoon) + tm_dots(size = 0.2) +
    tm_shape(lagoon) + tm_borders(lty = "dashed") +
    tm_shape(islands_geo) + tm_polygons() +
    tm_legend(legend.outside = TRUE, legend.text.size = 1, legend.title.size = 1.5) +
    tm_grid(ticks = TRUE, lines = FALSE, labels.size = 1) + 
    tm_xlab("Longitude", size = 1.5) +
    tm_ylab("Latitude", size = 1.5)
  
  tmap_save(plot_points, "points_interp.jpeg", width = 1920, height = 1080)
  
  # Process CTD casts
  list.cast <- process_ctd_casts(df.merged)
  
  # Plot CTD profile for a specific station
  station_to_plot <- "OWS005"
  profile_plot <- plot_ctd_profile(list.cast[[station_to_plot]], station_to_plot)
  ggsave(paste0("ctd_profile_", station_to_plot, ".jpeg"), profile_plot, width = 10, height = 8)
  
  # Calibration analysis
  calibration_stations <- c("OWS047", "OWS083", "OWS129")
  calibration_plot <- calibration_analysis(df.merged, calibration_stations)
  ggsave("calibration_plot.jpeg", calibration_plot, width = 12, height = 8)
}

# Run the main function
main()
