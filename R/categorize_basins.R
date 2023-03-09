# add basins to receiver locations
# M. Johnston

library(sf)
library(dplyr)

map = read_sf("data/spatial/Basins.kml")
gis = readRDS("data_clean/allgis.rds")
deps = readRDS("data_clean/alldeps.rds")
d = readRDS("data_clean/alldets.rds")


pnts_sf <- st_as_sf(gis, coords = c('Longitude', 'Latitude'), crs = st_crs(map))

pnts <- pnts_sf %>% mutate(
  intersection = as.integer(st_intersects(geometry, map)), 
  Basin = if_else(is.na(intersection), 'Bay', map$Name[intersection])
) 

table(pnts$Basin)

pnts = as.data.frame(pnts)
sort(unique(pnts$Location_name[pnts$Basin == "Bay"]))
sort(unique(pnts$Location_name[pnts$Basin == "Sacramento River"]))
sort(unique(pnts$Location_name[pnts$Basin == "SJR Basin"]))

v = table(pnts$Location_name)
v[v>1]

gis[gis$Location_name == "SJR LR", ]
gis[gis$Location_name == "SJR UR", ]

# add basin to deployments
deps$combo = paste0(deps$Latitude, deps$Longitude)

ans = merge(deps, pnts[ , c("Location_name", "combo", "Basin")],
            all.x = TRUE, by = c("Location_name", "combo"))

write.csv(ans, "data_clean/alldeps_with_basin.csv", row.names = FALSE)

# add basin to detections
d = d[ , c("Receiver", "Location_name", "TagID", "DateTimePST", "Origin")]

ans2 = merge(d, ans[ , c("Location_name", "Receiver", "Basin")],
             all.x = TRUE)
