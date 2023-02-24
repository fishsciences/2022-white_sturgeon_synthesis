# Get Yolo wst tag IDs and detection table from Yolo Bypass Project .sqlite database
# data is read-only and gets cleaned/formatted in subsequent scripts
# This script is just to document where the data came from

library(RSQLite)
data.dir = readRDS("data/data_dir_local.rds")

# filepath to copy of the database from Yolo Bypass Project
db_path = file.path(data.dir, "Yolo/ybt_database.sqlite")

# open a connection
con = RSQLite::dbConnect(drv = RSQLite::SQLite(), db_path)

# Get and save full tags data from database
wst = dbGetQuery(con, "select * from wst") # wst yolo tags only
dets = dbGetQuery(con,"select * from detections") # detections
ydep = dbGetQuery(con, "SELECT * FROM deployments;") # deployments

saveRDS(wst, "data/wst_yolo.rds")
saveRDS(dets, "data/yolo_detections.rds")
saveRDS(ydep, "data/ydep.rds")

# close connection
dbDisconnect(con)
