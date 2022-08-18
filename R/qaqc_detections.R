# QAQC Detections
# M. Johnston
# Fri Jul  1 10:28:13 2022 ------------------------------

library(ybt)
library(RSQLite)
library(data.table)
library(lubridate)
library(ggplot2)

if(FALSE){
source("R/collate_tags.R")

alltags = readRDS("data_clean/alltags.rds")

#sql_loc = "~/Downloads/ybt_database.sqlite"
sql_loc = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/ac_telemetry_database.sqlite"

con = dbConnect(RSQLite::SQLite(), sql_loc)

dets = dbGetQuery(con, "SELECT * FROM detections")

dd = subset(dets, TagID %in% alltags$TagCode)

dd$DateTimeUTC = as.POSIXct(dd$DateTimeUTC)

d2 = dd[dd$DateTimeUTC > ymd_hms("2010-08-17 00:00:00"), ] # study start
d2 = tidyr::separate(d2, col = Receiver, sep = "-", into = c("Freq", "Receiver"))

d2$Receiver = as.integer(d2$Receiver)

saveRDS(d2, "data/WST_detections.rds")

}

d = readRDS("data/WST_detections.rds") # has already been subset down to only our tags and date range
tags = readRDS("data_clean/alltags.rds")


d = dplyr::left_join(d, tags[ , c("TagID", "Study_ID")])

# bring in study id
tapply(d$Receiver, d$Study_ID, function(x) length(unique(x)))
len(d$Receiver)
d$Year = year(d$DateTimeUTC)
tapply(d$Receiver, d$Year, function(x) length(unique(x)))

#d2 = subset(d, Year > 2011 & Year < 2019)

x = aggregate(Receiver ~ Study_ID + Year, data = d, FUN = len)

ggplot(x, aes(x = Study_ID, y = Receiver)) +
  geom_bar(stat = "identity", aes(fill = factor(Year)),
           position = "dodge",
           width = 0.4) +
  scale_fill_viridis_d()

y = aggregate(TagID ~ Study_ID + Year, data = d, FUN = len)

tapply(d$TagID, d$Study_ID, len)

ggplot(y, aes(x = Study_ID, y = TagID)) +
  geom_bar(stat = "identity", aes(fill = factor(Year)),
           position = "dodge",
           width = 0.4) +
  scale_fill_viridis_d(option = "A")
