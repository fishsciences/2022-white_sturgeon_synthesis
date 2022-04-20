# Get Yolo wst tag IDs from latest database
# Mon Apr  4 14:42:18 2022 ------------------------------

library(RSQLite)
library(lubridate)
library(data.table)

# change this filepath to point to your local copy of the database
db_path = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/ARCHIVE/2018-AECOMM-Yolo-Telemetry-External/Deliverables/data/ybt_database.sqlite"

# open a connection
con = RSQLite::dbConnect(drv = RSQLite::SQLite(), db_path)

# Get full data from database
wst = dbGetQuery(con, "select * from wst") # wst tags only

# close connection
dbDisconnect(con)

saveRDS(wst, "data/wst_yolo.rds")

