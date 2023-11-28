# Group detections and consolidate lat/lons by GenLoc
# This script adds GenLoc to the detections so that shared receiver locations can be consolidated into a single representative lat/lon.  It also removes simultaneous detections.
# this is the last step before analysis
# M. Johnston
# Wed Jul 19 09:16:02 2023 America/Los_Angeles ------------------------------

# end product: Want a key of Location_name + GenLoc + Lat + Lon + Basin for all Location_names found in detections.  The lat/lons have to come from either alldeps (from the shared Location_name/GenLoc) or from GenLocs.csv, which has the generalized lat/longs for Bay Bridge, etc.

# key: df with nrow = len(Location_name[detections]) + len(GenLoc !%in% alldeps)

source("R/utils.R")
data_dir = readRDS("data/data_dir_local.rds")
# bring in raw detections & deployments
dets = readRDS("data_clean/alldets.rds")
deps = readRDS("data_clean/alldeps.rds")
deps = deps[ , c("Location_name", "Latitude", "Longitude", "Basin")]

# this is only the receivers that contain detections; it was made by writing unique(alldets$location_name) to a csv, and then manually adding grouped locations as GenLoc:
stns = read.csv(file.path(data_dir, "spatial/alldets_location_names.csv"))
stns = subset(stns, Location_name != "SR_AbvFeather1_RT") # this location removed from dets
# fix some typos
stns$GenLoc[stns$GenLoc == "GeorgSloughN2"] <- "Georg_SloughN2"
stns$GenLoc[stns$GenLoc == "MidR_N_of_OR3"] <- "MidR_N_of_OR2"
stns$GenLoc[stns$GenLoc == "OR_SWoMidR_E2"] <- "OR_SWoMidR_E1"
stns$GenLoc[stns$GenLoc == "Pt_Reyes"] <- "Pt_Reyes_05"
stns$GenLoc[stns$GenLoc == "SF_Larkspur_Ferry_16"] <- "SF_Larkspur_Ferry_15"
stns$GenLoc[stns$GenLoc == "SJ_CurtisLanding_StateReleaseSite"] <- "SJ_CurtisLanding_StateReleaseSite1"
stns$GenLoc[stns$GenLoc == "SP_Array1E"] <- "SP_Array_1E"
stns$GenLoc[stns$GenLoc == "SP_Array2E"] <- "SP_Array_2E"

sum(stns$Location_name == stns$GenLoc) # 151 have the same name & genloc.
sum(stns$GenLoc %in% unique(deps$Location_name)) #231 GenLoc lat/lons can be pulled from deps
pull_from_deps = stns[stns$GenLoc %in% unique(deps$Location_name), ] # isolate these

i = unique(deps)

# pull the lat/lon for GenLoc from the matching Location_name in deps
pfd = merge(pull_from_deps, i, 
            all.x = TRUE,
            all.y = FALSE,
            by.x = "GenLoc",
            by.y = "Location_name") # specifying by.y makes it pull the correct lat/lon

# spot-check
unique(deps[deps$Location_name == "PotatoSlough" | deps$Location_name == "PotatoSlough2", ])
pfd[pfd$GenLoc == "PotatoSlough" | pfd$Location_name == "PotatoSlough2", ] # both should have PotatoSlough lat/lon, not PotatoSlough2's

# need to get lat/lons for the general locations that do not have a match in deps:
genLL = read.csv(file.path(data_dir, "/GIS/GenLocs.csv"))
genLL = genLL[ , c("Name", "X", "Y")]
colnames(genLL) <- c("GenLoc", "Longitude", "Latitude")
stopifnot(!all(genLL$GenLoc %in% deps$Location_name)) # none of these should exist in deps or pfd
stopifnot(!all(genLL$GenLoc %in% pfd$GenLoc))

# add basin to genLocs
library(sf)
library(dplyr)
map = read_sf(file.path(data_dir, "spatial/Basins.kml"))

genLL$combo = paste0(genLL$Latitude, genLL$Longitude)
stopifnot(!any(duplicated(genLL)))
stopifnot(!any(table(genLL$GenLoc)>1)) # make sure each location is associated with a single lat/lon combo
cgis <- genLL
pnts_sf <- st_as_sf(cgis, coords = c('Longitude', 'Latitude'), crs = st_crs(map))

pnts <- pnts_sf %>% mutate(
  intersection = as.integer(st_intersects(geometry, map)), 
  Basin = if_else(is.na(intersection), 'Bay', map$Name[intersection])
) 

pnts = as.data.frame(pnts)
v = table(pnts$GenLoc)
stopifnot(!any(v>1)) # still only one locaiton name per combo

# add basin to deployments
genLL = merge(genLL, pnts[ , c("GenLoc", "Basin")],
                all.x = TRUE, by = c("GenLoc"))
genLL$combo = NULL # remove merging column; don't need in the final table

# merge back with stns to get the matching Location_names for a general loc, but with the right lat/lons:
genkey = merge(stns[stns$GenLoc %in% genLL$GenLoc, ], genLL, by = "GenLoc")

# rbind genkey and pfd
allkey = rbind(genkey, pfd)
stopifnot(nrow(allkey) == nrow(stns))

str(dets)
dets = dets[ , c("TagID", "Location_name", "Receiver", "DateTimePST", "DetOrigin", "StudyID")]

# bring in genLoc
dets2 = merge(dets, allkey, all.x = TRUE, by = "Location_name")
str(dets2)

# Remove simultaneous detections
#-------------------------------------------------------#
i = duplicated(dets2[, c("TagID", "GenLoc", "DateTimePST")])
d = dets2[!i, ]
print(paste("Removing", sum(i), "duplicate detections", sep = " ")) # 2.26 million duplicate detections
stopifnot(sum(as.vector(csn(d))) == 0)
saveRDS(d, "data_clean/alldets_grouped.rds")
