# QAQC Detections - checks that each detection has a "home" in a valid deployment window, and removes any that don't ("orphan" detections)
# M. Johnston
library(data.table)
library(lubridate)
library(telemetry)

deps = readRDS("data_clean/alldeps.rds") # made in R/clean_deployments.R
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

orphan_idx = is.na(single$Start) # logical index of orphans; 3594 orphan dets
y = table(idx$xid)
b = y[y>1]
idx_rows = as.numeric(names(b)) # numeric index of multiples
mults = idx$xid %in% names(b) # logical index of multiples; sum should now be zero
stopifnot(sum(mults) == 0)

good = single[!mults & !orphan_idx, ]

cols_keep = c("Receiver", "Location_name", "Latitude", "Longitude", "Basin", "TagID", "DateTimePST",
              "DetOrigin", "StudyID")

good = good[ , cols_keep]

# Removing the Feather River RT receivers as their locations are ambiguous:
#---------------------------------------------------------#
fr = good[good$Location_name %in% c("SR_AbvFeather1_RT", "SR_AbvFeather2_RT"), ]
good = dplyr::anti_join(good, fr)

# these are all the detections that fall within a legit receiver window with known locations, no fuzzy match necessary
saveRDS(good, "data_clean/alldets.rds")

# create df of orphans:
orphdf = single[orphan_idx, ]

# write .csvs of remaining orphan detections - will reference if we need to complete a fish's history
write.csv(orphdf, "data_clean/orphan_dets.csv", row.names = FALSE)

if(FALSE){ # make test detections and deployments set for telemetry::find_orphans()
  x = orph[orph$Receiver == 6279, ]
  test_dets = dd[dd$Receiver == 6279, c("TagID", "DateTimePST", "Receiver", "StudyID")]
  test_dets = test_dets[test_dets$DateTimePST > min(x$DateTimePST) & test_dets$DateTimePST < max(x$DateTimePST) + 60*60*24*20, ] # orphans + 20days
  # make smaller
  test_dets = subset(test_dets, TagID %in% c(unique(x$TagID), "A69-1303-62777", "A69-1303-56410"))
  
  test_deps = deps[deps$Receiver == 6279, c("Receiver", "Location_name", "DeploymentStart", "DeploymentEnd")] # fairly confident that this receiver was Chipp17 for all the detections listed
  
  save(test_dets, test_deps, file = "~/NonDropboxRepos/telemetry/inst/test_find_orphans.rda") 
}
