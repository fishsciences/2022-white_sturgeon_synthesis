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

deps = readRDS("data_clean/alldeps.rds")
d = readRDS("data/WST_detections.rds") # has already been subset down to only our tags and date range
tags = readRDS("data_clean/alltags.rds")
all(d$Receiver %in% deps$Receiver)

## Subset out the detections that already match a single deployment window:
single = find_orphans(d, deps, fuzzy_match = 0L)
orph_single = single[is.na(single$DeploymentStart), ] # true orphans

idx = find_orphans(d, deps, which = TRUE, fuzzy_match = 0L)
orphan_idx = is.na(single$DeploymentStart) # logical index of orphans
y = table(idx$xid)
b = y[y>1]
idx_rows = as.numeric(names(b)) # numeric index of multiples
mults = idx$xid %in% names(b) # logical index of multiples

good = single[!mults & ! orphan_idx, ]

write.csv(good[ , c("DateTimePST", "TagID", "Receiver", "Location_name", "Latitude", "Longitude", "Origin")], "data_clean/detections_clean2022-12-08.csv")

table(orphan_idx, mults) # good that there's no overlaps

# create a dataset of mults and a dataset of orphans; tackle the mults first
# subset unique TagID, DateTimePST, Receiver combos first to get a detections df back.
multdf = single[mults, ]
table(multdf$Receiver)

View(multdf[multdf$Receiver == 113014, ])

# create df of orphans:
orphdf = single[orphan_idx, ]


# plot A69-9001-19540
tf = rbind(good[good$TagID == "A69-9001-19543", ], orphdf[orphdf$TagID == "A69-9001-19543", ])
tf = tf[order(tf$DateTimePST), ]
tf = tf[tf$DateTimePST > "2018-06-06 00:00:00" & tf$DateTimePST <"2019-01-01 00:00:00", ]

tf %>% 
  group_by(Receiver) %>% 
  filter(DateTimeUTC == min(DateTimeUTC)) %>% 
  ungroup() %>% 
  arrange(DateTimeUTC) %>% 
  pull(Receiver) -> or


ggplot(tf, aes(x = DateTimePST, y = factor(Receiver, levels = or))) +
  geom_point(alpha = 0.5)

tf$Location_name[tf$Receiver == 106775]
deps$Location_name[deps$Receiver == 106675]


## checking recs one by one
chk = orph[orph$Receiver == 112537, ]
table(chk$TagID)
range(chk$DateTimePST) # single deployment
deps[deps$Receiver == 112537, ]  


c2 = orph[orph$Receiver == 101256, ]
table(c2$TagID)
range(c2$DateTimePST)
range(deps$DeploymentStart[deps$Receiver == 101256])


pag = read.csv("~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Davis/archive/Deployments_from_Klimley_Server_20220830.csv")

pag[pag$VR2SN == 104310, c("Location", "VR2SN", "Start", "Stop")]
View(pag[pag$VR2SN == 101256, c("Location", "VR2SN", "Start", "Stop", "Additional_Notes")])


chk = orph[orph$Receiver == 104318, ]
table(chk$TagID, chk$StudyID)
range(chk$DateTimePST) # single deployment
range(deps$DeploymentStart[deps$Receiver == 104318])
deps[deps$Receiver == 104318, ] 
yy = deps[deps$Location_name == "GG7.5", ]
yy = yy[order(yy$DeploymentStart), ]


# sorting out unrecorded deployments for 125874:
unique(d$TagID[d$Receiver == 125874 & d$DateTimePST > as.POSIXct("2018-09-13") & d$DateTimePST < as.POSIXct("2018-12-20")])
x = d[d$TagID == "A69-9001-19543" & d$DateTimePST > as.POSIXct("2018-09-13") & d$DateTimePST < as.POSIXct("2018-12-20"), ]
x = x[order(x$DateTimePST), ]

x %>% 
  group_by(Receiver) %>% 
  filter(DateTimeUTC == min(DateTimeUTC)) %>% 
  ungroup() %>% 
  arrange(DateTimeUTC) %>% 
  pull(Receiver) -> or

ggplot(x, aes(x = DateTimePST, y = factor(Receiver, levels = or))) +
  geom_point(alpha = 0.5)

unique(deps$Location_name[deps$Receiver == 132451])


# process for a case like this: isolate the detections for +/-1 week around the detection period, and check spatiotemporal history of the fish - this would tell us if the gap represents detections from a place that the receiver was moved to

chk2 = ans[ans$TagID %in% c("A69-1303-56461", "A69-1303-56483", "A69-1303-56490", "A69-1303-63051", 
                             "A69-1303-63053") & ans$DateTimePST >= range(chk$DateTimePST)[1] -7 & ans$DateTimePST <= range(chk$DateTimePST)[2] + 7, ]



if(FALSE){ # make test detections and deployments set for telemetry::find_orphans()
  x = orph[orph$Receiver == 6279, ]
  test_dets = dd[dd$Receiver == 6279, c("TagID", "DateTimePST", "Receiver", "StudyID")]
  test_dets = test_dets[test_dets$DateTimePST > min(x$DateTimePST) & test_dets$DateTimePST < max(x$DateTimePST) + 60*60*24*20, ] # orphans + 20days
  # make smaller
  test_dets = subset(test_dets, TagID %in% c(unique(x$TagID), "A69-1303-62777", "A69-1303-56410"))
  
  test_deps = deps[deps$Receiver == 6279, c("Receiver", "Location_name", "DeploymentStart", "DeploymentEnd")] # fairly confident that this receiver was Chipp17 for all the detections listed
  
  save(test_dets, test_deps, file = "~/NonDropboxRepos/telemetry/inst/test_find_orphans.rda") 
}
