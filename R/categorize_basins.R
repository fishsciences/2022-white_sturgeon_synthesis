# add basins to receiver locations
# M. Johnston
# Tue Jan 10 09:11:02 2023 America/Los_Angeles ------------------------------


library(sf)
library(dplyr)

map = read_sf("data/spatial/Basins.kml")
gis = readRDS("data_clean/allgis.rds")

pnts_sf <- st_as_sf(gis, coords = c('Longitude', 'Latitude'), crs = st_crs(map))

pnts <- pnts_sf %>% mutate(
  intersection = as.integer(st_intersects(geometry, map)), 
  Basin = if_else(is.na(intersection), 'Bay', map$Name[intersection])
) 

table(pnts$Basin)

pnts = as.data.frame(pnts)
sort(unique(pnts$Location_name[pnts$Basin == "Bay"]))

unique(dets$Longitude[dets$Location_name == "SR_BlwDeerCk"])
sort(unique(pnts$Location_name[pnts$Basin == "Sacramento River"]))

v = table(pnts$Location_name)
v[v>1]
