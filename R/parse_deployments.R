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
# 2. Check that those receivers are in the BARD + YOLO + SJR deployments # they are
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

d2 = tidyr::separate(d2, col = Receiver, sep = "-", into = c("Freq", "Receiver"))
d2$Receiver = as.integer(d2$Receiver)

# BARD 2022 deployments
bd = readRDS("data/BARD_deployments_all_2022-06-24.rds")
bd$Origin = "BARD 2022"
bd = dplyr::rename(bd, 
                   Receiver = Receiver_ser_num,
                   Start = Start_date_time,
                   End = Stop_date_time,
                   Comments = Additional_notes)

bd$Receiver = as.integer(bd$Receiver)
# remove overlapping Yolo deployments, source from ybt data later
ii = grep("YB", bd$Location_name)
bd = bd[-ii, ]

rec_dets = unique(d2$Receiver)
rec_bd = unique(bd$Receiver)
rec_all = c(rec_bd, yolo_sjr)

all(rec_dets %in% rec_all)
x = setdiff(rec_dets, rec_bd)


# Subset BARD deployments to just those receivers our fish were detected on
cols_keep = c("Location_name",
              "Receiver",
              "Start",
              "End",
              "Origin")

bd2 = bd[bd$Receiver %in% rec_dets, cols_keep]

# BARD
# locations table - has lat/lons
locs = readRDS("data/BARD_Receiver_locations_2022-06-24.rds")
locs$Latitude = as.numeric(locs$Latitude)
locs$Longitude = as.numeric(locs$Longitude)
locs$Receiver = as.integer(locs$Receiver_ser_num)
#k69 = locs$Receiver > 99999 & locs$Receiver < 200000 
#locs = locs[k69, ] # keep only the 69khz
locs = locs[!is.na(locs$Receiver) & locs$Latitude != 0, ]
locs$Start = as.POSIXct(locs$Start_date_time, format = "%F %T")
locs$End = as.POSIXct(locs$Stop_date_time, format = "%F %T")

summary(locs$Receiver)
locs$Origin = "BARD 2022"
locs2 = locs[ , cols_keep]

## fuzzy search - do the receiver SNs + start times match within a day or so?
bd2$fuzzy = NA
bd2$nomatch = NA
bd2$shift = NA

for(i in 1:nrow(bd2)) {
 # i = 3538
  x = locs2$Receiver == bd2$Receiver[i] # tells which rows in locs correspond to i in bd2
  s = locs2$Start[x] # vector of starts for corresponding receivers in both tables
  bd2$nomatch[i] = !any(x)
  bd2$fuzzy[i] = any(abs(difftime(s, bd2$Start[i], units = "hours")) < 48) 
  bd2$shift[i] = min(abs(difftime(s, bd2$Start[i], units = "hours")))
  
}

table(bd2$fuzzy, bd2$nomatch) # 2053 rows in bd2 where there's not a receiver in locs, 2798 where there is a receiver in locs2 but no matching timestamp

# how many unique receivers in bd2 are represented by the matches?
length(unique(bd2$Receiver[!bd2$nomatch]))

# find the missing rows
# nomatch = true & fuzzy = false

missing_locs = bd2[bd2$nomatch & !bd2$fuzzy, ]

# locs must be a subset of deps, where they didn't want to repeat location_name or lat/lon info
# this means that we would not expect every receiver number to have a match in locs
# and so we also wouldn't expect every receiver number + start to have a match in locs.


# in bd2 there are 209 rows where the receiver matches one in locs2 and the corresponding start time is within 24hrs, so we're assuming the same


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

#ydep$Start = lubridate::force_tz(ymd_hms(ydep$Start), tzone = "Etc/GMT+8")
#ydep$End = lubridate::force_tz(ymd_hms(ydep$End), tzone = "Etc/GMT+8")


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

yolo_sjr = c(unique(ydep$Receiver), unique(sjr$Receiver))


#sjr$Start = lubridate::force_tz(ymd_hms(sjr$Start), "Etc/GMT+8")
#sjr$End = lubridate::force_tz(ymd_hms(sjr$End), "Etc/GMT+8")

comp_tags(sjr$Location_name, lodi$Station) # sweet



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
