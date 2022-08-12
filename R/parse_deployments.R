# Parse Deployments tables
# M. Johnston
# Wed Jun 22 13:43:07 2022 ------------------------------
library(RSQLite)
library(data.table)
library(telemetry)
library(lubridate)

## Receiver bounds: Longitude -120.0, Latitude 37.2
## Detection bounds: "2010-08-17" - "2022-01-01"

# 1. Subset detections to date range, and make list of receivers in the detections 
# 2. Check that those receivers are in the BARD deployments
      # - put any missing ones into their own file to track down
# 3. Subset BARD deployments to receivers our fish were detected on
# 4. Compare those deployment record to locs
# 5. Bring in lat/longs for matching recSN + startDep rows
# 6. Make .csv of BARD deployment rows that are not found in locs

# Detections
# Compare the receivers our fish were actually detected on to our deployments data
dd = readRDS("data/WST_detections.rds")
dd$DateTimeUTC = as.POSIXct(dd$DateTimeUTC)
d2 = as.data.table(dd)

d2 = d2[d2$DateTimeUTC > ymd_hms("2010-08-17 00:00:00"), ]



# BARD 2022 deployments
bd = readRDS("data/BARD_deployments_all_2022-06-24.rds")
bd$Origin = "BARD 2022"
bd = dplyr::rename(bd, 
                   Receiver = Receiver_ser_num,
                   Start = Start_date_time,
                   End = Stop_date_time,
                   Comments = Additional_notes)

bd$Receiver = as.numeric(bd$Receiver)

#k69 = bd$Receiver > 99999 & bd$Receiver < 200000 
#bd = bd[k69, ]

attr(bd$Start, which = "tz")

# bd$Start = lubridate::force_tz(bd$Start, tzone = "Etc/GMT+8")
# bd$End = lubridate::force_tz(bd$End, tzone = "Etc/GMT+8")
ii = grep("YB", bd$Location_name)
bd = bd[-ii, ]





# BARD
# locations table - has lat/lons
locs = readRDS("data/BARD_Receiver_locations_2022-06-24.rds")
locs$Latitude = as.numeric(locs$Latitude)
locs$Longitude = as.numeric(locs$Longitude)
locs$Receiver = as.numeric(locs$Receiver_ser_num)
#k69 = locs$Receiver > 99999 & locs$Receiver < 200000 
#locs = locs[k69, ] # keep only the 69khz
locs = locs[!is.na(locs$Receiver) & locs$Latitude != 0, ]

summary(as.numeric(locs$Receiver_ser_num))

locs$Origin = "BARD 2022"

# # Additional BARD (UCD 2016)
# gis2016 = read.csv("~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Davis/8_12_2016_UCDMaintained_RT_Core.csv")
# 
# colnames(gis2016) <- c("Longitude", "Latitude", "Location_name", "desc", "alt")
# gis2016$Origin = "UCD 2016"

# YOLO
ylocs = readxl::read_excel("data/YoloLatLongs.xlsx")
colnames(ylocs) = c("Location_name", "Location long", "Latitude", "Longitude")
ylocs$Origin = "YOLO 2020"


# LODI
lodi = readxl::read_excel("~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Lodi/LFWO_SJR_WST_Receiver_Deployment.xlsx")
lodi = dplyr::rename(lodi, Location_name = Location)
lodi$Origin = "SJR 2022"

allgis = rbind(locs[ , c("Location_name", "Longitude", "Latitude", "Origin")],
             #  gis2016[ , c("Location_name", "Longitude", "Latitude", "Origin")],
               ylocs[ , c("Location_name", "Longitude", "Latitude", "Origin")],
               lodi[ , c("Location_name", "Longitude", "Latitude", "Origin")])

# correct the positive longs
allgis$Longitude[allgis$Longitude > 0] <- allgis$Longitude[allgis$Longitude > 0]*(-1)

# bounds
allgis = subset(allgis, Longitude > -122.0 & Longitude < -120.0 & Latitude > 37.1 & Latitude < 44)

saveRDS(allgis, "data_clean/allgis.rds")

## 
# Deployments tables from databases
## 
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
ydep = ydep[ydep$End != "", ]

ydep$Start = lubridate::force_tz(ymd_hms(ydep$Start), tzone = "Etc/GMT+8")
ydep$End = lubridate::force_tz(ymd_hms(ydep$End), tzone = "Etc/GMT+8")


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
sjr$Origin = "SJR 2022"

sjr$Start = lubridate::force_tz(ymd_hms(sjr$Start), "Etc/GMT+8")
sjr$End = lubridate::force_tz(ymd_hms(sjr$End), "Etc/GMT+8")

comp_tags(sjr$Location_name, lodi$Station) # sweet

cols_keep = c("Location_name",
              "Receiver",
              "Start",
              "End",
              "Comments",
              "Origin")

# ------------------------------
# Compare pag and bd, because all pag should be in bd
# ------------------------------

dplyr::all_equal(pag, bd)
janitor::compare_df_cols(pag[ , cols_keep], 
                         bd[ , cols_keep])

comp_tags(pag$Receiver, bd$Receiver)
all(pag$Receiver %in% bd$Receiver)

# For each receiver, are the Start, End, Location_names the same within rows?
# make a unique id/primary key of the Receiver and Start, and then compare between the two

i = pag[ , c("Receiver", "Start")]

x = paste(i$Receiver, as.integer(i$Start))
y = paste(bd$Receiver, as.integer(bd$Start))

all(x %in% y)
any(x %in% y) 

z = setdiff(x, y)

x = paste(i$Receiver, format(i$Start, "%Y-%m-%d"))
y = paste(bd$Receiver, format(bd$Start, "%Y-%m-%d"))

all(x %in% y)
any(x %in% y) 

z = setdiff(x, y)

subset(pag[ , cols_keep], Receiver == 3480)
subset(bd[ , cols_keep], Receiver == 3480)



# represents all the deployment data we have that includes start and end dates
alldeps = dplyr::bind_rows(ydep[ , cols_keep],
                pag[ , cols_keep],
                bd[ , cols_keep],
                sjr[ , cols_keep]
                )

alldeps$Receiver = as.numeric(alldeps$Receiver)

saveRDS(alldeps, "data_clean/alldeps.rds")


# See how many of our deployments have location data
comp_tags(allgis$Location_name, alldeps$Location_name)

x = setdiff(alldeps$Location_name, allgis$Location_name)



ylocs2 = merge(ylocs, ydep[ , c("Location_name", "Receiver")]) # bring in rec ser_num
i = duplicated(ylocs2[ , c("Location_name", "Receiver", "Latitude", "Longitude")])
ylocs2 = ylocs2[!i, ]
locs$Receiver = as.integer(locs$Receiver_ser_num)

with_coords = rbind(locs[ , c("Receiver", "Location_name", "Longitude", "Latitude", "Origin")],
               ylocs2[ , c("Receiver", "Location_name", "Longitude", "Latitude", "Origin")],
               lodi[ , c("Receiver", "Location_name", "Longitude", "Latitude", "Origin")])

comp_tags(d2$Receiver, alldeps$Receiver)
comp_tags(d2$Receiver, with_coords$Receiver)
x = setdiff(d2$Receiver, with_coords$Receiver)
y = dd[d2$Receiver == 373, ]

# try to get coord info from the location names
missing_coords = alldeps[alldeps$Receiver %in% x, ] # where x is all the receivers that fish are detected on but that aren't found in with_coords, and with_coords is all the receivers we have coordinate info for

salvaged = missing_coords[(unique(missing_coords$Location_name) %in% unique(with_coords$Location_name)), ]

s2 = merge(salvaged, allgis[ , c("Location_name", "Latitude", "Longitude", "Origin")], by = "Location_name")

# BARD 2022 and UCD 2016 do not agree
