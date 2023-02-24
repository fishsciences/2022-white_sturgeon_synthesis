# QA/QC deployments from Klimley server
# M. Espe
# 2022 Aug
library(ggplot2)
library(lubridate)
source("R/overlap_funs.R")
data.dir = readRDS("data/data_dir_local.rds")

# newest version, sent by UC Davis on 9/10/22
g = read.csv(file.path(data.dir, "Davis/Deployments_UTC_091022.csv"))

g$Start = gsub("T", " ", g$Start)
g$Start = as.POSIXct(g$Start, tz = "UTC")
g$Stop = gsub("T", " ", g$Stop)
g$Stop = as.POSIXct(g$Stop, tz = "UTC")
colSums(is.na(g)) # 29 NA value for dep ends, 2 lat long NAs


if(FALSE){ # this finds the recs deployed in >1 place at the same time and plots them; only one receiver applies, does not affect our fish
g2 = g[!is.na(g$Stop) & !is.na(g$Lat), ]

g2 = split(g2, g2$VR2SN)
g2 = g2[sapply(g2, nrow) > 1] # subset down to recs w/ more than one row
gg = lapply(g2, get_overlaps, "Start", "Stop")
gg = gg[sapply(gg, length) > 0]
gg[[1]]
gg = unlist(gg, recursive = FALSE)

gg = gg[sapply(gg, function(x) length(unique(x$Location)) > 1)] # recs with more than 1 location
length(gg)

out_dir = "output/overlapping_klimley_deps"

if(!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

sapply(names(gg), function(nm) {
  plot_overlaps(gg[[nm]], group_col = "Location", receiver_col = "VR2SN")
  ggsave(filename = file.path(out_dir,
                              sprintf("overlap_%s.png", nm)),
         bg = "white")
})
}

#---------------------
# Other checks: # start with g2
# Date / Time checks
g2 = g[!is.na(g$Stop) & !is.na(g$Lat), ]
range(g2$Start)
range(g2$Stop)

# check receiver deployment hour ranges - are there receivers that are deployed or pulled at unusual times?  >11pm PT, <5am PT?
ss = c(with_tz(g2$Stop, "Etc/GMT+8"), with_tz(g2$Start, "Etc/GMT+8"))
summary(hour(ss))
after_hours = ss[hour(ss) >= 22 | hour(ss) <= 5]
length(after_hours) # ~260 start/stop times fall within these ranges
range(after_hours) # possible that some times were actually in PT already but were "converted" to UTC

# do any deployments end before they begin?
stopifnot(sum(g2$Stop < g2$Start) == 0)

# Check format of lat/lons
summary(g2$Lat)
summary(g2$Lon)

# Check that lat/longs are consistent within locations
test = g2[g2$Location == "SR_Freeport", ]
stopifnot(min(test$Lat) == max(test$Lat))

chk_coords = function(df) {
  
  # within a data frame of deployments for a single receiver, compare lats with lats, lons with lons
  diff_lat = diff(range(df$Lat))
  diff_lon = diff(range(df$Lat))
  
  if(abs(diff_lat) >= 0.001 | abs(diff_lon) >= 0.001) 
    {return(unique(df$Location))} else {return(invisible())}
  
}

chk_coords(test)

test$Lat[1] <- 40

chk_coords(test)

# check that all longs are negative:
stopifnot(g2$Lon < 0)

g_split = split(g2, g2$Location)

ans = sapply(g_split, FUN = chk_coords)
ans[!sapply(ans, is.null)] # all null

saveRDS(g2, "data/bard_depsQ42022.rds")
