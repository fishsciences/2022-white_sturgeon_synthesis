# This script preps each raw detection table (BARD queried June 2022, LODI transferred May 2022, Yolo queried June 2022) to match the format of the Yolo Detections from 2012-2018 (https://github.com/fishsciences/ybt), and then joins them for QA/QCing.
# M. Johnston
library(lubridate)
library(data.table)

data.dir = readRDS("data/data_dir_local.rds")
bard_loc = file.path(data.dir, "/Davis/allBARDdets_2022-06-03.rds") # full BARD detections table
bard = readRDS(bard_loc)
ydets = readRDS("data/yolo_detections.rds")
names(bard); names(ydets)

# Check tz; Format bard same as detection table in Yolo detections
tz(bard$Detect_date_time)  
bard$DateTimeUTC = as.character(bard$Detect_date_time)
bard$Receiver = bard$Receiver_ser_num
bard$TagID = paste(bard$Codespace, bard$Tag_ID, sep = "-")
bard[,c("TagName", "TagSN")] = NA
bard$SensorValue = bard$Data
bard$SensorUnit = bard$Units
bard$DetOrigin = "BARD"

ydets$DetOrigin = "YOLO"
tz(ydets$DateTimeUTC)
cols = colnames(ydets)
stopifnot(all(cols %in% colnames(bard)))

# Combine and find dups
tmp = as.data.table(rbind(ydets[,cols], bard[,cols]))
# Need to exclude NA cols, because not marked as dups
i = duplicated(tmp[,c("DateTimeUTC", "Receiver", "TagID")]) # data.table method much faster 
table(i)

# duplicated rows should only be in BARD, not Yolo dets
in_bard = i[(nrow(ydets)+1):length(i)]
stopifnot(length(in_bard) == nrow(bard)) 
stopifnot(sum(in_bard) == sum(i)) # yolo dets should not have duplicates, as they were already removed in the ybt project

tmp = as.data.frame(tmp)
bard_tmp = tmp[ !i, cols]
stopifnot(nrow(tmp) - nrow(bard_tmp) == sum(i)) # should have only removed the dups

# SJR Detections
data_dir = file.path(data.dir, "Lodi/Lodi_DC/")
files = list.files(path = data_dir, pattern = ".csv", full.names = TRUE, recursive = TRUE)
dd = do.call(rbind, lapply(files, read.csv))

# Clean up column names
dd$DetOrigin = "SJR"
dd = dplyr::select(dd, 
                   DateTimeUTC = Date.and.Time..UTC.,
                   Receiver,
                   TagID = Transmitter,
                   TagName = Transmitter.Name,
                   TagSN = Transmitter.Serial,
                   SensorValue = Sensor.Value,
                   SensorUnit = Sensor.Unit,
                   DetOrigin
)
# Check
tz(dd$DateTimeUTC)
range(dd$DateTimeUTC)
dd$DateTimeUTC = as.character(dd$DateTimeUTC)
# Combine and find dups
ltmp = as.data.table(dd[ , cols])
# Need to exclude NA cols, because not marked as dups
i = duplicated(ltmp[ , c("DateTimeUTC", "Receiver", "TagID")]) #
sum(i) # 6132 rows

sjr = as.data.frame(ltmp)
sjr = sjr[!i, ]
stopifnot(nrow(ltmp) - nrow(sjr) == sum(i))

all_dets = rbind(bard_tmp, sjr)
all_dets$DateTimeUTC = as.POSIXct(all_dets$DateTimeUTC, tz = "UTC")
all_dets = all_dets[all_dets$DateTimeUTC > ymd_hms("2010-08-17 00:00:00", tz = "UTC"), ] # study start
range(all_dets$DateTimeUTC)
saveRDS(all_dets, "data/combined_detections.rds")
