# Receiver map
# M. Johnston

library(dplyr)
library(leaflet)
library(ggplot2)

allgis = readRDS("data_clean/alldeps.rds") # made in R/clean_deployments.R
allgis$combo = paste0(allgis$Latitude, allgis$Longitude)

allgis %>% 
  group_by(Location_name) %>% 
  arrange(Start) %>% 
  filter(!duplicated(combo)) %>% 
  select(-StartUTC, -EndUTC) %>% 
  ungroup() %>% 
  arrange(Origin, Location_name, Start) -> cgis

cgis = as.data.frame(cgis)

v = table(cgis$Location_name)
v[v>1]

write.csv(cgis, "data_clean/all_rec_locs.csv") # for use in google earth; this is what we made Basins.shp from


leaflet(cgis) %>% 
  addTiles() %>% 
  addCircleMarkers(label = allgis$Location_name, 
                   color = case_when(cgis$Origin == "PATH" ~ "blue", 
                                    cgis$Origin == "YOLO 2020" ~ "orange",
                                    cgis$Origin == "SJR 2022" ~ "purple"),
                   radius = 0.8,
                   labelOptions = labelOptions(permanent = FALSE, noHide = FALSE)) 


# visualize gaps

y = allgis[allgis$Origin == "YOLO 2020", ]

y$Year = lubridate::year(y$Start)
y$jday_start = as.integer(format(y$Start, "%j"))
y$jday_end = as.integer(format(y$End, "%j"))

# 244 = Sept 1, 135 = May 15th


yt = y[y$Location_name == "YBGL", ]

ggplot(y, aes(x = Start, y = Location_name)) +
  geom_segment(aes(x = Start, xend = End,
                   y = Location_name, 
                   yend = Location_name)) +
  facet_wrap(~Year, scales = "free_x")

str(yt)

yt$rownum = seq(nrow(yt))

ggplot(yt, aes(x = Start, y = rownum)) +
  geom_segment(aes(x = Start, 
                   xend = End,
                   y = rownum, 
                   yend = rownum)) 


x = yt[1:4, 1:4]

gapcheck = difftime(x$Start[-1], x$End[-length(x$End)], units = "secs") > 48*60*60

# We want to insert a row into the right place - the 
gapstart = x$End[which(gapcheck)]
gapend = x$Start[which(gapcheck) + 1]
