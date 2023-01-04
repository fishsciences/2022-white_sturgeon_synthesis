# QAQC Detections
# M. Johnston
# Tue Dec  6 13:26:47 2022 America/Los_Angeles ------------------------------
library(data.table)
library(lubridate)
library(ggplot2)
library(telemetry)
source("R/utils.R")

# tidies the detections - only run again if data has changed
if(FALSE){
  library(RSQLite)
source("R/collate_tags.R")

tags = readRDS("data_clean/alltags.rds")

#sql_loc = "~/Downloads/ybt_database.sqlite"
sql_loc = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/ac_telemetry_database.sqlite"

con = dbConnect(RSQLite::SQLite(), sql_loc)

dets = dbGetQuery(con, "SELECT * FROM detections") # contains YOLO + SJR + BARD detections

dd = subset(dets, TagID %in% tags$TagCode)

dd$DateTimeUTC = as.POSIXct(dd$DateTimeUTC, tz = "UTC")

d2 = dd[dd$DateTimeUTC > ymd_hms("2010-08-17 00:00:00"), ] # study start
d2 = tidyr::separate(d2, col = Receiver, sep = "-", into = c("Freq", "Receiver"))
d2$Receiver = as.integer(d2$Receiver)
dd = d2[ , c("TagID", "DateTimeUTC", "Receiver", "StudyID")]

dd = merge(d, tags[ , c("TagCode", "StudyID")], by.x = "TagID", by.y = "TagCode") # slow; better to summarise/table by TagCode first, and then join that smaller table

dd$DateTimePST = with_tz(dd$DateTimeUTC, tz = "Etc/GMT+8")

saveRDS(dd, "data/WST_detections.rds")

}

deps = readRDS("data_clean/alldeps.rds") # made in R/parse_deployments.R
d = readRDS("data/WST_detections.rds") # has already been subset down to only our tags and date range
tags = readRDS("data_clean/alltags.rds")
stopifnot(all(d$Receiver %in% deps$Receiver))

## Subset out the detections that already match a single deployment window:
single = find_orphans(d, 
                      deps, 
                      deployment_start_col = "Start",
                      deployment_end_col = "End",
                      fuzzy_match = 0L)

orph_single = single[is.na(single$Start), ] # true orphans

idx = find_orphans(d, 
                   deps, 
                   deployment_start_col = "Start",
                   deployment_end_col = "End",
                   which = TRUE, 
                   fuzzy_match = 0L)

orphan_idx = is.na(single$Start) # logical index of orphans
y = table(idx$xid)
b = y[y>1]
idx_rows = as.numeric(names(b)) # numeric index of multiples
mults = idx$xid %in% names(b) # logical index of multiples; sum should now be zero

good = single[!mults & ! orphan_idx, ]

# these are all the detections that fall within a legit receiver window, no fuzzy match necessary
write.csv(good[ , c("DateTimePST", "TagID", "Receiver", "Location_name", "Latitude", "Longitude", "Origin")], "data_clean/detections_clean2023-01-04.csv")

# create df of orphans:
orphdf = single[orphan_idx, ]

# write .csvs of remaining orphan detections - will reference if we need to complete a fish's history
write.csv(orphdf, "data_clean/orphan_dets.csv")


if(FALSE){ # make test detections and deployments set for telemetry::find_orphans()
  x = orph[orph$Receiver == 6279, ]
  test_dets = dd[dd$Receiver == 6279, c("TagID", "DateTimePST", "Receiver", "StudyID")]
  test_dets = test_dets[test_dets$DateTimePST > min(x$DateTimePST) & test_dets$DateTimePST < max(x$DateTimePST) + 60*60*24*20, ] # orphans + 20days
  # make smaller
  test_dets = subset(test_dets, TagID %in% c(unique(x$TagID), "A69-1303-62777", "A69-1303-56410"))
  
  test_deps = deps[deps$Receiver == 6279, c("Receiver", "Location_name", "DeploymentStart", "DeploymentEnd")] # fairly confident that this receiver was Chipp17 for all the detections listed
  
  save(test_dets, test_deps, file = "~/NonDropboxRepos/telemetry/inst/test_find_orphans.rda") 
}
