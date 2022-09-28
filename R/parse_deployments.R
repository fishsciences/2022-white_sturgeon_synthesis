# Parse Deployments tables
# M. Johnston
# Wed Sep 28 08:50:08 2022 America/Los_Angeles ------------------------------

library(RSQLite)
library(data.table)
library(telemetry)
library(lubridate)
source("R/overlap_funs.R")
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
path = readRDS("data/bard_depsQ42022.rds")
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
sql_loc = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/ac_telemetry_database.sqlite"
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
sjr = readxl::read_excel("~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Lodi/LFWO_SJR_WST_Receiver_Deployment_separatedByVRL.xlsx", sheet = "Lodi_deps_to_use")

sjr = dplyr::select(sjr, 
                    Location_name = Station,
                    Receiver,
                    Start = 'DeploymentStart',
                    End = 'DeploymentEnd_vrlDate',
                    Comments = Notes)

sjr$Start = paste(sjr$Start, "00:00:00")
sjr$End = paste(sjr$End, "00:00:00")

sjr$Start = as.POSIXct(sjr$Start, tz = "Etc/GMT+8")
sjr$End = as.POSIXct(sjr$End, tz = "Etc/GMT+8")
sjr$Origin = "SJR 2022"

yolo_sjr = c(unique(ydep$Receiver), unique(sjr$Receiver))

# Isolate receivers on which we have detections
rec_dets = unique(dd$Receiver)

# make list of all receivers for which we have any deployment metadata
rec_all = unique(c(unique(path$Receiver), yolo_sjr))

#stopifnot(all(rec_dets %in% rec_all))

rec_dets[!rec_dets %in% rec_all] # 546698

range(dd$DateTimeUTC[dd$Receiver == 546698])

agrep(546698, path$Receiver, value = TRUE)

path$Location_name[path$Receiver == 546699]
path$Receiver[grep("Chipps", path$Location_name)]


bd = readRDS("data/BARD_deployments_all_2022-06-24.rds")
bd[bd$Receiver_ser_num == 546698, ]

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

alldeps$Receiver = as.numeric(alldeps$Receiver)


summary(alldeps$Latitude)
summary(alldeps$Longitude)

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
