# RSZA-DEPR Environmental Monitoring
# Interpolation of CTD Casts in the RSP and AMAALA Areas
# Version 3
# Last updated: 2024-08-21

# Load required libraries
library(readr)
library(dplyr)
library(readxl)
library(writexl)
library(sf)
library(ggplot2)
library(terra)
library(gstat)
library(tmap)
library(raster)
library(sp)
library(stringr)
library(tidyr)

# Set working directory
setwd("C:/Users/YourUsername/Desktop/001DATA")

# Load accessory files
load("M:/SEZ DES/Science and Monitoring (SM)/Workstreams/Environmental Monitoring/Marine/002ANALYSIS/GIS/gis_geo.RData")
ama_geo <- st_read("C:/Users/YourUsername/Downloads/AMAALA boundary.kml", quiet = TRUE)
ama_geo_xy <- st_zm(ama_geo, what = "ZM")
ama_sp <- as(ama_geo_xy, "Spatial")

# Function to process Excel files
process_excel_files <- function() {
  files <- list.files(path = ".", pattern = "CTD.*cast.*\\.xlsx$", ignore.case = TRUE, recursive = TRUE, full.names = FALSE)
  
  for (file in files) {
    data <- read_excel(file)
    csv_file <- sub("\\.xlsx$", ".csv", file)
    write.csv(data, csv_file, row.names = FALSE)
    file.remove(file)
  }
}

# Function to filter metadata
filter_metadata <- function(meta, area, quarter, month) {
  meta %>%
    mutate(Year = year(Date), Month = month(Date)) %>%
    filter(`Project area` == area, Quarter == quarter, Month == month, !is.na(FILENAME)) %>%
    select(c(1,3,5,12,13,14,25,26)) %>%
    mutate_at(vars(Latitude, Longitude), ~ as.numeric(., na.rm = TRUE))
}

# Function to plot CTD locations
plot_ctd_locations <- function(ctd_files, ama_geo) {
  ggplot() +
    geom_point(data = ctd_files, aes(x = Longitude, y = Latitude, color = Project), 
               position = position_jitter(width = 0.001, height = 0.001), alpha = 0.5) +
    geom_sf(data = ama_geo, fill = NA, size = 1) +
    geom_sf(data = islands_geo, fill = "grey", size = 1) +
    geom_sf(data = shores_geo, fill = "grey", size = 1) +
    coord_sf(xlim = c(35.57, 36.3), ylim = c(26.4, 27.3), expand = FALSE) +
    labs(title = "CTD locations by Project", x = "Longitude", y = "Latitude", color = "Project") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

# Function to process CTD files
process_ctd_files <- function(filenames) {
  pattern <- paste0(filenames, collapse = "|")
  file_list <- list.files(path = ".", pattern = pattern, recursive = TRUE, full.names = TRUE)
  
  colnames.csv <- c("Date","Time","Time.frac","Site","Cond","Depth","nLF_cond","ODO_sat","ODO_cb","ODO_mgL",
                    "ORP_mv","psi","psu","SpCond","TDS","Turbid","TSS","pH","pHmV","Temp","Posit","Batt","Pwr")
  
  csv_files <- lapply(file_list, function(x) {
    df <- read.csv(x, stringsAsFactors = FALSE)
    setNames(df, colnames.csv)
  })
  
  file_names <- sapply(file_list, function(x) {
    elements <- unlist(strsplit(basename(x), "_"))
    elements[3]
  })
  
  combined_data <- dplyr::bind_rows(setNames(csv_files, file_names), .id = "Site")
  combined_data <- combined_data %>% select(1:23)
  combined_data$Date <- as.Date(combined_data$Date, "%Y-%m-%d")
  
  saveRDS(combined_data, "CTD_Data_ama_may23.rds")
}

# Function for IDW interpolation and plotting
idw_interpolation_plot <- function(data, variable, title, palette, ama_sp, filter_condition = NULL) {
  P <- data
  if (!is.null(filter_condition)) {
    P <- subset(P, eval(parse(text = filter_condition)))
  }
  coordinates(P) <- c("Longitude", "Latitude")
  crs(P) <- crs("EPSG:4326")
  
  grd <- as.data.frame(spsample(ama_sp, "regular", n = 50000))
  names(grd) <- c("X", "Y")
  coordinates(grd) <- c("X", "Y")
  gridded(grd) <- TRUE
  fullgrid(grd) <- TRUE
  proj4string(grd) <- proj4string(P)
  
  P.idw <- gstat::idw(as.formula(paste(variable, "~ 1")), P, newdata = grd, idp = 3.5)
  r <- raster(P.idw)
  r.m <- mask(r, ama_sp)
  
  plot <- tm_shape(r.m, bbox = ama_sp) +
    tm_raster(n = 6, palette = palette, stretch.palette = TRUE,
              title = title, style = "equal", contrast = c(0.1, 0.5)) +
    tm_shape(P) + tm_dots(size = 0.02) +
    tm_shape(ama_sp) + tm_borders() +
    tm_shape(shores_geo) + tm_polygons() +
    tm_legend(legend.outside = TRUE, legend.text.size = 1, legend.title.size = 1.5) +
    tm_grid(ticks = TRUE, lines = FALSE, labels.size = 0.8) +
    tm_xlab("Longitude", size = 1.2) +
    tm_ylab("Latitude", size = 1.2)
  
  return(plot)
}

# Function to plot specific sampling points
plot_specific_points <- function(P, ama_sp, point_ids) {
  P_sub <- P[P@data$Site %in% point_ids, ]
  
  plot_points <- tm_shape(P_sub, bbox = ama_sp) + tm_dots(size = 1, color = "red") +
    tm_shape(ama_sp) + tm_borders(lty = "dashed") +
    tm_shape(shores_geo) + tm_polygons() +
    tm_legend(legend.outside = TRUE, legend.text.size = 1, legend.title.size = 1.5) +
    tm_grid(ticks = TRUE, lines = FALSE, labels.size = 1) +
    tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
    tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)
  
  return(plot_points)
}

# Function to plot annual trend
plot_annual_trend <- function(data) {
  data_long <- data %>%
    pivot_longer(cols = -Month, names_to = c("Stat", "Parameter"), names_sep = "_") %>%
    filter(!is.na(value))
  
  ggplot(data_long, aes(x = factor(Month), y = value, color = Stat, group = Stat)) +
    geom_point() +
    geom_smooth(method = "loess", se = FALSE) +
    scale_color_manual(values = c("min" = "blue", "avg" = "green", "max" = "red")) +
    labs(y = "Value", x = "Month", color = "Statistics") +
    facet_wrap(~ Parameter, scales = "free_y") +
    theme_minimal() +
    ggtitle("Parameter Values over Months")
}

# Main execution
main <- function() {
  process_excel_files()
  
  meta <- read_excel("META_EnvironmentalData.xlsx", sheet = "CTDCast")
  ctd_files <- filter_metadata(meta, "AMA", "Q2 2023", 5)
  
  plot_ctd_locations(ctd_files, ama_geo)
  
  process_ctd_files(unique(ctd_files$FILENAME))
  
  combined_data <- readRDS("CTD_Data_ama_may23.rds")
  df.interp <- combined_data %>%
    filter(Depth <= 1.5 & Depth >= 0.5) %>%
    group_by(Site) %>%
    summarise_all(mean)
  
  site.data <- meta %>%
    filter(`Project area` == "AMA") %>%
    select(c(12,13,14)) %>%
    rename(Site = SITE) %>%
    na.omit() %>%
    mutate_at(vars(Latitude, Longitude), ~ as.numeric(., na.rm = TRUE))
  
  df.interp.st <- df.interp %>%
    left_join(site.data %>% group_by(Site) %>% slice(1) %>% ungroup(), by = "Site")
  
  write_xlsx(df.interp.st, "ctd_casts_SST_ama_may23.xlsx")
  
  # Generate plots
  sst_plot <- idw_interpolation_plot(df.interp.st, "Temp", "May 2023 \nSea Surface Temperature \n[°C]", "-RdBu", ama_sp, "Temp > 25")
  o2_plot <- idw_interpolation_plot(df.interp.st, "ODO_mgL", "May 2023 \nDissolved oxygen \n[mg/L]", "Purples", ama_sp)
  ph_plot <- idw_interpolation_plot(df.interp.st, "pH", "May 2023 \n pH", "PuRd", ama_sp, "pH > 7")
  psu_plot <- idw_interpolation_plot(df.interp.st, "psu", "May 2023 \nPSU", "YlGn", ama_sp, "psu > 35")
  tds_plot <- idw_interpolation_plot(df.interp.st, "TDS", "May 2023 \nTotal Dissolved Solids \n [mg/L]", "YlOrBr", ama_sp)
  
  # Save plots
  tmap_save(sst_plot, "sst_interp_May23.jpeg", width = 1920, height = 1080)
  tmap_save(o2_plot, "O2_interp_May23.jpeg", width = 1920, height = 1080)
  tmap_save(ph_plot, "pH_interp_May23.jpeg", width = 1920, height = 1080)
  tmap_save(psu_plot, "psu_interp_May23.jpeg", width = 1920, height = 1080)
  tmap_save(tds_plot, "tds_interp_May23.jpeg", width = 1920, height = 1080)
  
  # Plot specific sampling points
  P <- df.interp.st
  coordinates(P) <- c("Longitude", "Latitude")
  crs(P) <- crs("EPSG:4326")
  specific_points_plot <- plot_specific_points(P, ama_sp, c("OWS178", "OWS184", "OWS161", "OWS075"))
  tmap_save(specific_points_plot, "specific_points_May23.jpeg", width = 1920, height = 1080)
  
  # Annual trend plot
  annual_data <- data.frame(
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
  annual_trend_plot <- plot_annual_trend(annual_data)
  ggsave("annual_trend_plot.jpeg", annual_trend_plot, width = 16, height = 9, units = "in")
}

# Run the main function
main()
