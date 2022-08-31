# EDA on PATH deployments
# M. Johnston
# Tue Aug 23 13:10:28 2022 America/Los_Angeles ------------------------------

source("R/overlap_funs.R")
base_dir = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/"
base_dir = "."
cols_keep = c("Location_name",
              "Receiver",
              "Latitude",
              "Longitude",
              "Start",
              "End",
              "Origin")

# PATH deployments
post12 = read.csv(file.path(base_dir, "Data/Davis/deploys_post2012_final.csv"))

post12$Origin = "PATH_post12"

new = c(
  "Location_name" = "location_name",
  "Receiver" = "receiver_serial_num",
  "Latitude" = "latitude",
  "Longitude" = "longitude",
  "Start" = "deploy_date_time",
  "End" = "recover_date_time"
)

i = match(new, colnames(post12))
colnames(post12)[i] <- names(new)

pre12 = read.csv(file.path(base_dir, "Data/Davis/deploys_pre2012_excluding2012_FINAL.csv"))
pre12$Origin = "PATH_pre12"

new2 = c(
  "Start" = "deploy_date_time",
  "End" = "recover_date_time",
  "Latitude" = "deploy_lat",
  "Longitude" = "deploy_long",
  "Receiver" = "Receiver_ser_num"
)

i2 = match(new2, colnames(pre12))
colnames(pre12)[i2] <- names(new2)

# bind together
path = dplyr::bind_rows(pre12[ , cols_keep], post12[ , cols_keep])

# subset down to only records with Location Names and Receiver SNs
path = path[path$Location_name != "" & !is.na(path$Receiver), ]

# assume times are in PST for now:
path$Start = as.POSIXct(path$Start, tz = "etc/GMT+8", format = "%m/%d/%Y %H:%M")
path$End = as.POSIXct(path$End, tz = "etc/GMT+8", format = "%m/%d/%Y %H:%M")

path = path[!is.na(path$End), ] # remove the 24 End nas for now - they're all Golden Gate & Pt Reyes

# split by receiver SN - want to find the receivers that are associated with more than one location and check deployment continuity:
ps = split(path, path$Receiver)
ps = lapply(ps, function(x) x[order(x$Start), ]) # order each data frame by its start column



ps_chk = sapply(ps, chk_overlaps)

table(ps_chk) # 53 receivers that have >1 locaiton and have at least one start date that occurs before the previous row's end date.  This doesn't necessarily mean the mismatch is across locations, just that it meets the criteria I set above.

aa = ps[ps_chk] # get the 53 receivers from the original

# spot-check one of these:
bb = aa[[2]]
bb = bb[order(bb$Start), ] 
bb[bb$Start[-1] < bb$End[-nrow(bb)], ] # ordered by Start, we see that this receiver's deployment at Pt Reyes occurs before the end of its deployment at GG2.5

bb = bb[order(bb$Location_name, bb$Start), ]
bb # the deployments make more sense within location, but across locations they overlap.

# here's a post_2012 one; it doesn't have any overlapping deployments across locations, only within one location:
cc = aa[[52]]
cc[order(cc$Start), ] # the deployment at Georg_SloughN3 on 2015-10-16 06:59:00 begins before the previous row ended.
cc[cc$Start[-1] < cc$End[-nrow(cc)], ] 



## Functionalizing

# Isolate just the receivers that seem to be deployed in more than one place at the same time:

# within a data frame: split by location_name, and check the overlaps across the intervals: do any of the intervals (start, end) from location A fall within location B...etc?

# return: a list with the overlapping rows, one list entry per overlap, two rows per entry

library(data.table)

table(sapply(aa, function(x) length(unique(x$Location_name)))) # some receivers have 4 or 5 locations that could potentially contain overlapping rows


test = aa$`102242`
ans = feeder(test)
ans

test2 = aa$`106086`
ans = feeder(test2)

test2 = aa$`102242`
ans = feeder(test2)

ans = feeder(test2)

ans2 = lapply(aa, feeder)
two_places = rbindlist(ans2, fill = TRUE)

two_places$conflict = rep(seq(nrow(two_places)/2), each = 2)

test3 = two_places[[1]]

lapply(two_places, function(y)
  lapply(seq_along(y), function(x) {
    write.csv(y[[x]],
              file = paste0("output/test/",
                            unique(y[[x]]$Receiver), 
                            "_conflict",
                            x,
                            ".csv"))
  }))

ll = aa$`121339`
ll = ll[order(ll$Start), ]
ll[ll$Start[-1] < ll$End[-nrow(ll)], ] # ordered by Start, we see that this receiver's deployment at Pt Reyes occurs before the end of its deployment at GG2.5


#----------------------------------------#
test = aa$`102242`
test = aa$`128`


t1 = get_overlaps(test)
feeder(test) # no hits

t1

ans = lapply(aa, get_overlaps)


ww = unlist(ans, recursive = FALSE)

plot_overlaps(ww[[3]])

out_dir = "output/overlapping_path_deployments"

if(!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

sapply(names(ww), function(nm) write.csv(ww[[nm]], file = file.path(out_dir,
                                                                    sprintf("overlap_%s.csv", nm)),
                                         row.names = FALSE))

sapply(names(ww), function(nm) {
  plot_overlaps(ww[[nm]])
  ggsave(filename = file.path(out_dir,
                              sprintf("overlap_%s.png", nm)),
         bg = "white")
  })

