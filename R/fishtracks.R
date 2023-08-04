# Q2: What is the scope and variability of inter-basin movements exhibited by tagged adult White Sturgeon across years?
	# - Summarize movements of tagged White Sturgeon detected in multiple river basins or migratory corridors (Sacramento or San Joaquin, Yolo Bypass)

library(dplyr)
library(ggplot2)

dets = readRDS("data_clean/alldets_grouped.rds")

dets %>% 
  filter(StudyID == "YOLO WST") -> y

unique(y$Basin)
y$Year = lubridate::year(y$DateTimePST)

tapply(y$Basin, y$TagID, n_distinct)
tapply(y$Year, y$TagID, n_distinct)

y %>% 
  group_by(TagID, Year) %>% 
  summarize(nbasins = n_distinct(Basin)) %>% 
  group_by(Year) %>% 
  summarise(med = median(nbasins))

dets %>% 
  filter(Basin %in% c("Sacramento River", "SJR Basin")) %>% 
  group_by(TagID) %>% 
  summarize(nbasins = n_distinct(Basin)) %>% 
  filter(nbasins > 1) -> bb

bb2 = subset(dets, TagID %in% unique(bb$TagID))
bb2$Year = lubridate::year(bb2$DateTimePST)

bb2 = subset(bb2, Year > 2011)

ds = telemetry::tag_tales(bb2, "TagID", "Location_name", Datetime_col = "DateTimePST")

dss = split(ds, ds$TagID)

sapply(dss, function(df) {
  ggplot(df, aes(x = arrival, y = reorder(GenLoc, Longitude))) +
    geom_point(alpha = 0.6, size = 1,
               aes(color = Basin)) +
    facet_wrap(~Year, scales = "free", ncol = 2) +
    labs(y = NULL, 
         x = NULL, 
         title = sprintf("TagID: %s", unique(df$TagID))) +
    theme_bw() +
    scale_color_viridis_d() +
      theme(axis.text = element_text(size = 7))
  ggsave(sprintf("output/fishtracks2/%s.png", unique(df$TagID)), height = 8.5, width = 11)
})


length(unique(ds$TagID))
length(unique(dets$TagID))

## examples: "A69-1303-63038", 2016, 2019
##            A69-1303-63044, 2016
