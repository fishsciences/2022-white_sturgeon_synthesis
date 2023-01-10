# Parse Deployments tables
# M. Johnston
# Wed Sep 28 08:50:08 2022 America/Los_Angeles ------------------------------

library(RSQLite)
library(data.table)
library(telemetry)
library(lubridate)
source("R/overlap_funs.R")
data.dir = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/"
if(FALSE){
  # YOLO deployments original
  sql_loc = file.path(data.dir, "ac_telemetry_database.sqlite") # yolo + BARD
  con = dbConnect(RSQLite::SQLite(), sql_loc)
  ydep = dbGetQuery(con, "SELECT * FROM deployments;")
  dbDisconnect(con)
  saveRDS(ydep, "data/ydep.rds")
}

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
              "Origin",
              "Notes")

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
  "End" = "Stop",
  "Notes" = "Additional_Notes"
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

# only have deployments that end >= June 2010:
outside = path$End < as.POSIXct("2010-05-30 23:23:23", tz = "Etc/GMT+8")
chk = path[outside, ]
path = path[!outside, ]

# load Yolo and Lodi
ydep = readRDS("data/ydep.rds")
ydep$Location_name = ydep$Station
ydep$Notes = paste(ydep$VRLNotes, ydep$DeploymentNotes)

ydep = dplyr::rename(ydep, 
                     Start = DeploymentStart,
                     End = DeploymentEnd)

ydep$Origin = "YOLO 2020"
ydep = ydep[ydep$End != "", ]

ydep$Start = as.POSIXct(ydep$Start, tz = "Etc/GMT+8", format = "%Y-%m-%d %H:%M:%S")
ydep$End = as.POSIXct(ydep$End, tz = "Etc/GMT+8", format = "%Y-%m-%d %H:%M:%S")

# SJR 2022
sjr = readxl::read_excel(file.path(data.dir, 
                                   "Lodi/LFWO_SJR_WST_Receiver_Deployment_separatedByVRL.xlsx"), 
                         sheet = "Deployment")

sjr = dplyr::select(sjr, 
                    Location_name = Station,
                    Receiver,
                    Start = 'DeploymentStart',
                    End = 'DeploymentEnd',
                    Notes = Comment)

sjr$Origin = "SJR 2022"

# duplicate deployments in sjr & PATH: need to remove from PATH
comp = path[path$Receiver %in% unique(sjr$Receiver), ] # checked these w/ Laura on 12/22; can discard PATH dups
range(comp$End)
path = dplyr::anti_join(path, comp)

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

# Extend final window of rec deployment per notes column and detections of A69-9001-27460:
i = path$Receiver == 112537 & path$End == as.POSIXct("2015-06-17 12:00:00", tz = "Etc/GMT+8")
i_corr = as.POSIXct("2015-06-23 01:00:00", tz = "Etc/GMT+8")
path$End[i] <- i_corr
path[path$Receiver == 112537, ]  # fixed

# test merge results:
rec_all = unique(c(unique(path$Receiver), yolo_sjr))
stopifnot(all(rec_dets %in% rec_all)) # should pass now

# YOLO
ylocs = readxl::read_excel("data/YoloLatLongs.xlsx")
colnames(ylocs) = c("Location_name", "Location long", "Latitude", "Longitude")
ylocs$Origin = "YOLO 2020"

sum(duplicated(ydep[ , c("Location_name", "Receiver", "Start")]))
ydep = merge(ydep,  ylocs[ , c("Location_name", "Longitude", "Latitude")], all.x = TRUE)

ydep$End[is.na(ydep$End)] <- as.POSIXct("2019-08-21 11:05:00", tz = "Etc/GMT+8")

# LODI
lodi = readxl::read_excel("~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Lodi/LFWO_SJR_WST_Receiver_Deployment.xlsx")

# need to take it down to 4 decimals; verify that there's only 1 lat/long per location_name

lodi = dplyr::rename(lodi, Location_name = Station)
lodi = as.data.frame(lodi[ , c("Location_name", "Longitude", "Latitude")])
stopifnot(all(sjr$Location_name %in% lodi$Location_name))
lodi[ , c("Longitude", "Latitude")] <- round(lodi[ , c("Longitude", "Latitude")], 3)

j = duplicated(lodi$Location_name)
lodi = lodi[!j, ]

sjr = merge(sjr, lodi, all.x = TRUE)
sjr$Receiver = as.integer(sjr$Receiver)

# represents all the deployment data we have that includes start and end dates
alldeps = rbind(ydep[ , cols_keep],
                path[ , cols_keep],
                sjr[ , cols_keep])

# insert missing deployment for Santa Clara Shoals 1N rec, per Matt Pagel email circa 2013:
scs = alldeps[alldeps$Receiver == 101256, ][2:3, ]
stopifnot(scs$Start[2] == structure(1361529669, class = c("POSIXct", "POSIXt"), tzone = "Etc/GMT+8"))
stopifnot(scs$End[1] == structure(1353348906, class = c("POSIXct", "POSIXt"), tzone = "Etc/GMT+8"))
scs_ins = scs[1, ]
scs_ins$Start <- scs$End[1] + 1 # add 1 second
scs_ins$End <- scs$Start[2] - 1 # subtract 1 from the next start
scs_ins$Origin = "BARD 2020"
scs_ins$Notes = "this row added in parse_deployments.R, Dec 2022"

alldeps = rbind(alldeps, scs_ins)

alldeps = alldeps[order(alldeps$Receiver, alldeps$Start), ]

# check
summary(unique(alldeps$Receiver))
summary(alldeps$Latitude)
summary(alldeps$Longitude)
colSums(is.na(alldeps))
alldeps[alldeps$End < alldeps$Start, ]
range(alldeps$Start)

# correct the positive longs
alldeps$Longitude[alldeps$Longitude > 0] <- alldeps$Longitude[alldeps$Longitude > 0]*(-1)
stopifnot(alldeps$Longitude < 0)

# add column of PST
alldeps$StartUTC = with_tz(alldeps$Start, tzone = "UTC")
alldeps$EndUTC = with_tz(alldeps$End, tzone = "UTC")

# only have deployments that end >= June 2010:
outside = alldeps$End < as.POSIXct("2010-05-30 23:23:23", tz = "Etc/GMT+8")
chk = alldeps[outside, ]
alldeps = alldeps[!outside, ]
saveRDS(alldeps, "data_clean/alldeps.rds")



if(FALSE){
  deps = readRDS("data_clean/alldeps.rds")
  # bounds
  # allgis = subset(deps, Longitude > -122.65 & Longitude < -120.0 & Latitude > 37.1 & Latitude < 44) # cuts out the Pt_Reyes receivers, but we don't need to
  write.csv(deps, "data_clean/alldeps.csv")
  
}
