# Parse Deployments tables
# M. Johnston
# Wed Sep 28 08:50:08 2022 America/Los_Angeles ------------------------------

library(RSQLite)
library(data.table)
library(telemetry)
library(lubridate)
source("R/overlap_funs.R")
data.dir = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/"

## Receiver bounds: Longitude -120.0, Latitude 37.2
## Detection bounds: "2010-08-17" - "2022-01-01"

# 1. Subset detections to date range, and make list of receivers in the detections 
# 2. Check that those receivers are in the PATH + YOLO + SJR deployments 
# 3. Merge PATH + YOLO + SJR with columns: Location_name, Receiver, Start, End, Lat, Lon
# 4. Check for orphaned detections - see if each detection falls within a deployment

cols_keep = c("Location_name",
              "Receiver",
              "Start",
              "End",
              "Latitude", 
              "Longitude",
              "Origin")

# Detections
# Compare the receivers our fish were actually detected on to our deployments data
dd = readRDS("data/WST_detections.rds")


# PATH deployments
path = readRDS("data/bard_depsQ42022.rds") # made in qaqc_klimbley.R
path$Origin = "PATH"

new = c(
  "Location_name" = "Location",
  "Receiver" = "VR2SN",
  "Latitude" = "Lat",
  "Longitude" = "Lon",
  "End" = "Stop"
)

i = match(new, colnames(path))
colnames(path)[i] <- names(new)
attr(path$Start, "tz")

# convert to PT because that's what the others are in:
path$Start = with_tz(path$Start, tzone = "Etc/GMT+8")
path$End = with_tz(path$End, tzone = "Etc/GMT+8")

# remove overlapping Yolo deployments, source from ybt data later
ii = grep("YB", path$Location_name)
path = path[-ii, ]

# load Yolo and Lodi
# YOLO
sql_loc = file.path(data.dir, "ac_telemetry_database.sqlite")
con = dbConnect(RSQLite::SQLite(), sql_loc)
ydep = dbGetQuery(con, "SELECT * FROM deployments;")
dbDisconnect(con)

ydep$Location_name = ydep$Station
ydep$Comments = paste(ydep$VRLNotes, ydep$DeploymentNotes)

ydep = dplyr::rename(ydep, Start = DeploymentStart,
                     End = DeploymentEnd)

ydep$Origin = "YOLO 2020"

ydep = ydep[!is.na(ydep$End), ]
ydep = ydep[ydep$End != "", ] # be aware that this cuts the deployments back to Dec 2019

ydep$Start = as.POSIXct(ydep$Start, tz = "Etc/GMT+8")
ydep$End = as.POSIXct(ydep$End, tz = "Etc/GMT+8")

# SJR 2022
sjr = readxl::read_excel(file.path(data.dir, "Lodi/LFWO_SJR_WST_Receiver_Deployment_separatedByVRL.xlsx"), 
                         sheet = "Lodi_deps_to_use")

sjr = dplyr::select(sjr, 
                    Location_name = Station,
                    Receiver,
                    Start = 'DeploymentStart',
                    End = 'DeploymentEnd_vrlDate',
                    Comments = Notes)

sjr$Start = paste(sjr$Start, "00:00:00")
sjr$End = paste(sjr$End, "23:59:59") # rounding up deployment end to include the full day that it ends on

sjr$Start = as.POSIXct(sjr$Start, tz = "Etc/GMT+8")
sjr$End = as.POSIXct(sjr$End, tz = "Etc/GMT+8")
sjr$Origin = "SJR 2022"

# end_times = readxl::read_excel(file.path(data.dir, "Lodi/OneDrive_1_6-13-2022/Full Receiver History_Updated Jun2017.xlsx"), sheet = 1)
# 
# end_times$`Receiver Time @ Log Start (PST)` = force_tz(end_times$`Receiver Time @ Log Start (PST)`, tz = "Etc/GMT+8")
# 
# end_times$StartDate = as.Date(end_times$`Receiver Time @ Log Start (PST)`)
# sjr$StartDate = as.Date(sjr$Start)
# 
# # make a column to math on
# end_times$Rec_StartDate = paste(end_times$Serial_Number, end_times$StartDate)
# sjr$Rec_StartDate = paste(sjr$Receiver, sjr$StartDate)
# 
# # for each index in x, find the first match in y
# ii =  match(end_times$Rec_StartDate, sjr$Rec_StartDate) # has NAs, but need to keep it in the same order
# sjr$StartDate[na.omit(ii)] = end_times$StartDate[!is.na(ii)] # pattern for using match
# 
# sjr$End[na.omit(ii)] = end_times$`Receiver Time @ Log Upload (PST)`[!is.na(ii)] # pattern for using match


yolo_sjr = c(unique(ydep$Receiver), unique(sjr$Receiver))

# Isolate receivers on which we have detections
rec_dets = unique(dd$Receiver)

# make list of all receivers for which we have any deployment metadata
rec_all = unique(c(unique(path$Receiver), yolo_sjr))
all(rec_dets %in% rec_all)

rec_dets[!rec_dets %in% rec_all] # 546698 has detections but no deployment info

range(dd$DateTimeUTC[dd$Receiver == 546698])
nrow(dd[dd$Receiver == 546698, ]) # 20k detections between Jan 2018 & July 2018
length(unique(dd$TagID[dd$Receiver == 546698])) # 55 of our fish; not insignificant

# is it in the old records?
bd = readRDS("data/BARD_deployments_all_2022-06-24.rds")
ans = bd[bd$Receiver_ser_num == 546698, ] # decker island from Jan 17-July 23; exact missing period

# add this deployment info in:
ins = path[path$Location_name == "Decker_IsCL3", ][6:7, ] # last two rows of this receiver's record
ins[1:2, c(2:4, 7:29)] <- ans[1:2, c(2:4, 5:26)] # ans has everything except lat/lon
ins$Origin <- "BARD 2020" # to mark the rows that came from BARD
str(ins[ , cols_keep])
ins$Receiver = as.integer(ins$Receiver)
str(path[, cols_keep])
path <- rbind(path, ins)

# test merge results:
rec_all = unique(c(unique(path$Receiver), yolo_sjr))
stopifnot(all(rec_dets %in% rec_all)) # should pass now


# YOLO
ylocs = readxl::read_excel("data/YoloLatLongs.xlsx")
colnames(ylocs) = c("Location_name", "Location long", "Latitude", "Longitude")
ylocs$Origin = "YOLO 2020"

ydep = merge(ydep,  ylocs[ , c("Location_name", "Longitude", "Latitude")], all.x = TRUE)


# LODI
lodi = readxl::read_excel("~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Lodi/LFWO_SJR_WST_Receiver_Deployment.xlsx")

lodi = dplyr::rename(lodi, Location_name = Station)
sjr = merge(sjr, lodi[ , c("Location_name", "Longitude", "Latitude")], all.x = TRUE)

# represents all the deployment data we have that includes start and end dates
alldeps = dplyr::bind_rows(ydep[ , cols_keep],
                           path[ , cols_keep],
                           sjr[ , cols_keep])

# check
summary(unique(alldeps$Receiver))
summary(alldeps$Latitude)
summary(alldeps$Longitude)
chk = alldeps[alldeps$End <= alldeps$Start, ]


# correct the positive longs
alldeps$Longitude[alldeps$Longitude > 0] <- alldeps$Longitude[alldeps$Longitude > 0]*(-1)
stopifnot(alldeps$Longitude < 0)

# add column of PST
alldeps$StartUTC = with_tz(alldeps$Start, tzone = "UTC")
alldeps$EndUTC = with_tz(alldeps$End, tzone = "UTC")



saveRDS(alldeps, "data_clean/alldeps.rds")

# bounds
allgis = subset(alldeps, Longitude > -122.0 & Longitude < -120.0 & Latitude > 37.1 & Latitude < 44)

saveRDS(allgis, "data_clean/allgis.rds")
