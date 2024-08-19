
# RSZ-DEPR
# Environmental monitoring

#################################################################
# INTERPOLATION OF CTD CASTS IN THE RSP AREA                    #  



# 1. Set writing directory and load libraries -----------------------------
setwd("/Users/hasho0omy/Desktop/RSG/CTD_05_mapping")

library(readr)
library(dplyr)
library(readxl)
library(stringr)
library(tibble)
library(writexl)
library(oce)

# Load accessory files
load("gis_geo.RData")

# 2. Process files --------------------------------------------------------

# Load and process the Excel file
df <- read_excel("RSP_EM_UMQ002_CTD_20231012_Cast.xlsx")

# Standardize column names based on the expected structure
colnames.df <- c("Date", "Time", "Time.frac", "Site", "Cond", "Depth", "nLF_cond", "ODO_sat", "ODO_cb", "ODO_mgL",
                 "ORP_mv", "psi", "psu", "SpCond", "TDS", "pH", "pHmV", "Temp", "Posit", "Batt", "Pwr")

# Assign the new column names to the dataframe
df <- setNames(df, colnames.df)

# Convert Date column to Date type with proper format
df$Date <- as.Date(df$Date, format = "%m/%d/%Y")

# Verify that the Date conversion was successful
if (!inherits(df$Date, "Date")) {
  stop("Date column conversion failed. Please check the format.")
}

# Save the processed data
saveRDS(df, "CTD_DataOct23.rds")

# Continue with further processing
csv.df <- readRDS("CTD_DataOct23.rds")

# Ensure the Date column is correctly formatted
csv.df$Date <- as.Date(csv.df$Date, format = "%m/%d/%Y")

# Verify if the conversion was successful
if (!inherits(csv.df$Date, "Date")) {
  stop("Date column conversion failed. Please check the format.")
}

# Filter out rows where the Date conversion failed
csv.df <- csv.df %>% filter(!is.na(Date))

# Ensure 'station' column is derived from 'Site'
if (!"station" %in% colnames(csv.df)) {
  csv.df <- csv.df %>%
    mutate(station = sapply(strsplit(Site, split = "[_.]"), "[", 1))  # Adjust as needed
}

# Calibration
df.calibr <- csv.df %>%
  remove_rownames() %>%
  dplyr::select(-c(3, 4, 5)) %>%
  filter(Date > as.Date("2023-01-01")) %>%
  filter(Depth <= max.depth & Depth >= min.depth) %>%
  group_by(station) %>%
  summarise(across(everything(), ~ mean(.x, na.rm = TRUE)))

# Test Data
df.test <- csv.df %>%
  remove_rownames() %>%
  dplyr::select(-c(3, 4, 5)) %>%
  filter(Date > as.Date("2023-01-01")) %>%
  filter(Depth <= max.depth & Depth >= min.depth) %>%
  group_by(station, Date) %>%
  summarise(across(everything(), ~ mean(.x, na.rm = TRUE)))

df.test[duplicated(df.test[, 1]), ]  # Find duplicated stations

# Continue processing for interpolation
df.interp <- csv.df %>%
  remove_rownames() %>%
  dplyr::select(-c(1, 3, 4, 5)) %>%
  filter(Date > as.Date("2023-01-01")) %>%
  filter(Depth <= max.depth & Depth >= min.depth) %>%
  group_by(station) %>%
  summarise(across(everything(), mean, na.rm = TRUE))

# Add latitude and longitude from metadata
metadata <- read_excel("EnvMon_AllSites.xlsx")

site.data <- metadata %>%
  filter(ProjectArea == "RSP") %>%
  dplyr::select(c(3, 13, 14)) %>%
  rename(station = SiteName) %>%
  na.omit() %>%
  mutate_at(vars(Latitude, Longitude), ~ as.numeric(., na.rm = TRUE))

df.interp.st <- left_join(df.interp, site.data, by = "station")
names(df.interp.st)

# Save final table for interpolation as Excel
write_xlsx(df.interp.st, "ctd_casts_Oct23_05_15.xlsx")
















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
df.interp.st <- read_xlsx("../Analysis/ctd_stations.xlsx")
df.interp.st <- read_xlsx("ctd_casts_Oct23_05_15.xlsx")
P <- df.interp.st
P <- P[complete.cases(P$Latitude),]
P[47, 16] <- 29.99
P[47, 14] <- 8.16

coordinates(P) <-  c("Longitude", "Latitude") # mirar porque CTD 122 no copia las coordenadas
crs(P) <- crs("EPSG:4326")



























# Create prediction grid
# For the entire lagoon

lagoon <- st_zm(lagoon_geo)
lagoon.sp <- as(lagoon, "Spatial")
grd <- as.data.frame(spsample(lagoon.sp, "regular", n=50000))

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

# Interpolate the grid cells using a power value (idp) of 3.5
names(P)

P.idw <- gstat::idw(Temp ~ 1, P, newdata=grd, idp=3.5)

# Transform to raster object then clip to lagoon
r <- raster(P.idw)
r.m <- mask(r, lagoon)
plot(r.m)

plot_SST <- tm_shape(r.m, bbox = lagoon) + 
  tm_raster(n=6,palette = "-RdBu", stretch.palette = TRUE,  #"-RdBu"
            title="Sea Surface Temperature \n(C)", style= "equal", #Sea Surface Temperature \n(C)
            contrast = c(0.1, 0.5)) + 
  tm_shape(P) + tm_dots(size=0.02) +
  tm_shape(lagoon_geo) +  tm_borders() +
  tm_shape(islands_geo)  + tm_polygons() +
  tm_shape(shores_geo)  + tm_polygons() +
  tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
  tm_grid(ticks = TRUE, lines=FALSE, labels.size = 0.8) + 
  tm_xlab("Longitude", size = 1.2, rotation = 0, space = 0) +
  tm_ylab("Latitude", size = 1.2, rotation = 90, space = 0)

# Export to jpeg
plot_SST
tmap_save(plot_SST, "sst_interp_oct23.jpeg", width=1920, height=1080)



















# 3.2. O2 plot -----------------------------------------------------------

# Interpolate the grid cells using a power value (idp) of 3.5
names(P)
P.idw <- gstat::idw(ODO_mgL ~ 1, P, newdata=grd, idp=3.5)

# Transform to raster object then clip to lagoon
r <- raster(P.idw)
r.m <- mask(r, lagoon)
# plot(r.m)

plot_O2 <- tm_shape(r.m, bbox = lagoon) + 
  tm_raster(n=6,palette = "Purples", stretch.palette = TRUE,  
            title="Dissolved oxygen \n(mg/L)", style= "equal", 
            contrast = c(0.1, 0.5)) + 
  tm_shape(P) + tm_dots(size=0.02) +
  tm_shape(lagoon_geo) +  tm_borders() +
  tm_shape(islands_geo)  + tm_polygons() +
  tm_shape(shores_geo)  + tm_polygons() +
  tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
  tm_grid(ticks = TRUE, lines=FALSE, labels.size = 0.8) + 
  tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
  tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)

# Export to jpeg
plot_O2
tmap_save(plot_O2, "O2_interp_oct23.jpeg", width=1920, height=1080)













# 3.3. pH plot -----------------------------------------------------------

# Interpolate the grid cells using a power value (idp) of 3.5
names(P)
P.idw <- gstat::idw(pH ~ 1, P, newdata=grd, idp=3.5)















# Transform to raster object then clip to lagoon
r <- raster(P.idw)
r.m <- mask(r, lagoon)
plot(r.m)

plot_pH <- tm_shape(r.m, bbox = lagoon) + 
  tm_raster(n=6,palette = "PuRd", stretch.palette = TRUE,  
            title="pH", style= "equal", 
            contrast = c(0.1, 0.5)) + 
  tm_shape(P) + tm_dots(size=0.02) +
  tm_shape(lagoon_geo) +  tm_borders() +
  tm_shape(islands_geo)  + tm_polygons() +
  tm_shape(shores_geo)  + tm_polygons() +
  tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
  tm_grid(ticks = TRUE, lines=FALSE, labels.size = 0.8) + 
  tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
  tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)

# Export to jpeg
plot_pH
tmap_save(plot_pH, "pH_interp_oct23.jpeg", width=1920, height=1080)











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
r.m <- mask(r, lagoon)
plot(r.m)

plot_psu <- tm_shape(r.m, bbox = lagoon) + 
  tm_raster(n=6,palette = "YlGn", stretch.palette = TRUE,  
            title="PSU", style= "equal", 
            contrast = c(0.1, 0.5)) + 
  tm_shape(P) + tm_dots(size=0.02) +
  tm_shape(lagoon_geo) +  tm_borders() +
  tm_shape(islands_geo)  + tm_polygons() +
  tm_shape(shores_geo)  + tm_polygons() +
  tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
  tm_grid(ticks = TRUE, lines=FALSE, labels.size = 0.8) + 
  tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
  tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)

# Export to jpeg
plot_psu
tmap_save(plot_psu, "psu_interp_oct23.jpeg", width=1920, height=1080)










# 3.5. Only sampling points plot -----------------------------------------------------------

plot_points <- tm_shape(P, bbox = lagoon) + tm_dots(size=0.2) +
  tm_shape(lagoon) +  tm_borders(lty = "dashed") +
  tm_shape(islands)  + tm_polygons() +
 # tm_shape(shores)  + tm_polygons() +
  tm_legend(legend.outside=TRUE, legend.text.size = 1, legend.title.size=1.5) +
  tm_grid(ticks = TRUE, lines=FALSE, labels.size = 1) + 
  tm_xlab("Longitude", size = 1.5, rotation = 0, space = 0) +
  tm_ylab("Latitude", size = 1.5, rotation = 90, space = 0)

# Export to jpeg 
tmap_save(plot_points, "points_interp.jpeg", width=1920, height=1080)


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
