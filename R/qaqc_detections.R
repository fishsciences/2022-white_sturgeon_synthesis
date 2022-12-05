# QAQC Detections
# M. Johnston
# Fri Sep 30 10:33:48 2022 America/Los_Angeles ------------------------------
library(RSQLite)
library(data.table)
library(lubridate)
library(ggplot2)
library(telemetry)
source("R/utils.R")

# tidies the detections - only run again if data has changed
if(FALSE){
source("R/collate_tags.R")

alltags = readRDS("data_clean/alltags.rds")

#sql_loc = "~/Downloads/ybt_database.sqlite"
sql_loc = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/ac_telemetry_database.sqlite"

con = dbConnect(RSQLite::SQLite(), sql_loc)

dets = dbGetQuery(con, "SELECT * FROM detections") # contains YOLO + SJR + BARD detections

dd = subset(dets, TagID %in% alltags$TagCode)

dd$DateTimeUTC = as.POSIXct(dd$DateTimeUTC, tz = "UTC")

d2 = dd[dd$DateTimeUTC > ymd_hms("2010-08-17 00:00:00"), ] # study start
d2 = tidyr::separate(d2, col = Receiver, sep = "-", into = c("Freq", "Receiver"))
d2$Receiver = as.integer(d2$Receiver)

saveRDS(d2, "data/WST_detections.rds")

}

deps = readRDS("data_clean/alldeps.rds")
tags = readRDS("data_clean/alltags.rds")

d = readRDS("data/WST_detections.rds") # has already been subset down to only our tags and date range
table(tags$StudyID)
tags[tags$StudyID == "SAC WST", ]

all(deps$Receiver %in% d$Receiver)
all(d$Receiver %in% deps$Receiver)

x = unique(d$Receiver)
y = setdiff(x, unique(deps$Receiver)) # 546698

nrow(d[d$Receiver == y, ])

dd = merge(d, tags[ , c("TagCode", "StudyID")], by.x = "TagID", by.y = "TagCode") # slow; better to summarise/table by TagCode first, and then join that smaller table
table(dd$StudyID)
table(dd$StudyID[dd$Receiver == y])

tapply(dd$Receiver, dd$StudyID, function(x) length(unique(x)))
tapply(d$Receiver, year(dd$DateTimeUTC), function(x) length(unique(x)))

# prep for get_stations
dd$DateTimePST = with_tz(dd$DateTimeUTC, tz = "Etc/GMT+8")
deps = dplyr::rename(deps, DeploymentStart = Start, DeploymentEnd = End)

ans = find_orphans(dd, deps)
chk = deps[deps$DeploymentEnd <= deps$DeploymentStart, ]

deps = dplyr::anti_join(deps, chk)

ans = find_orphans(dd, deps)
ans2 = find_orphans(dd, deps, fuzzy_match = 60*60*8.1)

ans3 = find_orphans(dd, deps, fuzzy_match = 60*60*24.1)
orph3 = ans3[is.na(ans3$ExpandedStart), ]
sort(table(orph3$Receiver))
setdiff(unique(orph$Receiver), unique(orph3$Receiver)) # the receivers whose orphans go away with an 24hr shift in window
range(orph3$DateTimePST)

# orphans
orph = ans[is.na(ans$ExpandedStart), ]
sort(table(orph$Receiver))
range(orph$DateTimePST)

orph2 = ans2[is.na(ans2$ExpandedStart), ]
sort(table(orph2$Receiver))

setdiff(unique(orph$Receiver), unique(orph2$Receiver)) # the receivers whose orphans go away with an 8hr shift in window

if(FALSE){ # make test detections and deployments set for telemetry::find_orphans()
x = orph[orph$Receiver == 6279, ]
test_dets = dd[dd$Receiver == 6279, c("TagID", "DateTimePST", "Receiver", "StudyID")]
test_dets = test_dets[test_dets$DateTimePST > min(x$DateTimePST) & test_dets$DateTimePST < max(x$DateTimePST) + 60*60*24*20, ] # orphans + 20days
# make smaller
test_dets = subset(test_dets, TagID %in% c(unique(x$TagID), "A69-1303-62777", "A69-1303-56410"))

test_deps = deps[deps$Receiver == 6279, c("Receiver", "Location_name", "DeploymentStart", "DeploymentEnd")] # fairly confident that this receiver was Chipp17 for all the detections listed

save(test_dets, test_deps, file = "~/NonDropboxRepos/telemetry/inst/test_find_orphans.rda") }


## checking recs one by one
chk = orph[orph$Receiver == 112537, ]
table(chk$TagID)
range(chk$DateTimePST) # single deployment
range(deps$DeploymentStart[deps$Receiver == 112537])
deps[deps$Receiver == 112537, ] 
yy = deps[deps$Location_name == "GG7.5", ]
yy = yy[order(yy$DeploymentStart), ]

pag = read.csv("~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Davis/archive/Deployments_from_Klimley_Server_20220830.csv")

p = pag[pag$VR2SN == 112537, c("Location", "VR2SN", "Start", "Stop")]

chk = orph[orph$Receiver == 104318, ]
table(chk$TagID, chk$StudyID)
range(chk$DateTimePST) # single deployment
range(deps$DeploymentStart[deps$Receiver == 104318])
deps[deps$Receiver == 104318, ] 
yy = deps[deps$Location_name == "GG7.5", ]
yy = yy[order(yy$DeploymentStart), ]


# process for a case like this: isolate the detections for +/-1 week around the detection period, and check spatiotemporal history of the fish - this would tell us if the gap represents detections from a place that the receiver was moved to

chk2 = ans[ans$TagID %in% c("A69-1303-56461", "A69-1303-56483", "A69-1303-56490", "A69-1303-63051", 
                             "A69-1303-63053") & ans$DateTimePST >= range(chk$DateTimePST)[1] -7 & ans$DateTimePST <= range(chk$DateTimePST)[2] + 7, ]
