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

dd = subset(dets, TagID %in% tags$TagCode)
saveRDS(dd, "data/WST_detections.rds")
}

d = readRDS("data/WST_detections.rds") # has already been subset down to only our tags
tags = readRDS("data_clean/alltags.rds")

tags$TagID = paste("A", tags$Frequency_kHz, "-", tags$CodeSpace, "-", tags$TagID, sep = "")

d$DateTimeUTC = ymd_hms(d$DateTimeUTC)
d = dplyr::left_join(d, tags[ , c("TagID", "Study_ID")])
d = subset(d, year(DateTimeUTC) > 2009) # gets rid of weird 1970 & 2007 years

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

deps = readRDS("data_clean/alldeps.rds")

d2 = tidyr::separate(d, col = Receiver, into = c("RecFreq", "ReceiverSN"), remove = FALSE, sep = "-")
d2$ReceiverSN = as.numeric(d2$ReceiverSN)

mrecs = setdiff(d2$ReceiverSN, deps$Receiver) # these recs are not in the deployments

chk = subset(d2, Receiver %in% mrecs) # 52K detections
range(chk$DateTimeUTC)
table(chk$Study_ID)
len(chk$TagID) # 117 fish though - that's a lot of Emily's fish on these 27 receivers
table(chk$Receiver)

# for Em
print(unique(d2$Receiver[d2$ReceiverSN %in% mrecs]))

yolo = d[d$Study_ID == "UCD Yolo Bypass WST/Johnston" , ]

yolo = yolo[order(yolo$DateTimeUTC), ]
head(yolo)
tags[tags$TagID == "A69-1303-34027", ]
