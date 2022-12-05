# This script adds the entire BARD detections table (queried May 2022) to the Yolo Detections from 2012-2018
# M. Johnston
# Fri Jul  1 09:38:24 2022 ------------------------------

library(ybt)
library(RSQLite)
library(data.table)

#sql_loc = "~/Downloads/ybt_database.sqlite"
sql_loc = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Yolo/ac_telemetry_database.sqlite"

#bard_loc = "~/Downloads/allBARDdets_2022-06-03.rds"
bard_loc = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Davis/allBARDdets_2022-06-03.rds"

bard = readRDS(bard_loc)

con = dbConnect(RSQLite::SQLite(), sql_loc)

# what does DB look like?
dbListTables(con)

lapply(dbListTables(con), function(tbl) dbListFields(con, tbl))

# Check
tz(bard$Detect_date_time)

# Format bard same as detection table in SQLite
bard$DateTimeUTC = bard$Detect_date_time

# this seems OK?
bard$Receiver = paste0("VR2W-", bard$Receiver_ser_num)
bard$TagID = paste(bard$Codespace, bard$Tag_ID, sep = "-")
bard[,c("TagName", "TagSN")] = NA
bard$SensorValue = bard$Data
bard$SensorUnit = bard$Units

dets = dbGetQuery(con, "SELECT * FROM detections;")
dets$DateTimeUTC = as.POSIXct(dets$DateTimeUTC, tz = "UTC")
cols = dbListFields(con, "detections")

# Combine and find dups
tmp = as.data.table(rbind(dets[,cols], bard[,cols]))
# Need to exclude NA cols, because not marked as dups
i = duplicated(tmp[,c("DateTimeUTC", "Receiver", "TagID")]) # data.table method much faster 
table(i)

# duplicated rows should only be in BARD, not Yolo dets
in_bard = i[(nrow(dets)+1):length(i)]
stopifnot(length(in_bard) == nrow(bard)) 

table(in_bard)
stopifnot(sum(in_bard) == sum(i)) # Sql should not have duplicates

## We should be able to insert these directly into the sqlite DB without issue
bard_tmp = bard[,cols]
bard_tmp$DateTimeUTC = as.character(bard_tmp$DateTimeUTC, tz = "UTC") # Needs to be character going into SQLite

dbDisconnect(con) # will reconnect below
# Should remove dups automatically
ybt_db_append(bard_tmp, "detections", sql_loc)
