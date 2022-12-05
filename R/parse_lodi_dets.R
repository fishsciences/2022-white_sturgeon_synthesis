# Parse Lodi Detections
# M. Johnston
# Wed Jun 22 13:18:31 2022 ------------------------------

library(ybt)

# Steps

## Detections  
# append BARD dets to Yolo dets - COMPLETE: ac_telemetry, detections table
# append SJR detections to ac_telemetry database below

sql_loc = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Yolo/ac_telemetry_database.sqlite"

con = dbConnect(RSQLite::SQLite(), sql_loc)
fields = dput(dbListFields(con, "detections"))
dbGetQuery(con, 'SELECT * FROM "detections" LIMIT 10') # see what fields look like

# SJR Detections
data_dir = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Lodi/Lodi_DC/"

files = list.files(path = data_dir, pattern = ".csv", full.names = TRUE, recursive = TRUE)

dd = do.call(rbind, lapply(files, read.csv))
str(dd)
head(dd)

# Clean up column names
dd = dplyr::select(dd, 
                   DateTimeUTC = Date.and.Time..UTC.,
                   Receiver,
                   TagID = Transmitter,
                   TagName = Transmitter.Name,
                   TagSN = Transmitter.Serial,
                   SensorValue = Sensor.Value,
                   SensorUnit = Sensor.Unit
                   )
# Check
tz(dd$DateTimeUTC)
# Combine and find dups
tmp = as.data.table(dd[ , fields])
# Need to exclude NA cols, because not marked as dups
i = duplicated(tmp[ , c("DateTimeUTC", "Receiver", "TagID")]) #
j = duplicated(tmp)
sum(i) # db_append should reject 6132 rows

sjr = data.frame(tmp)

dbDisconnect(con) # will reconnect below

# Should remove dups automatically
ybt_db_append(sjr, "detections", sql_loc)

nrow(sjr) - 1435838 == sum(i)
sum(i)
