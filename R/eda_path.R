# EDA on PATH deployments
# M. Johnston
# Tue Aug 23 13:10:28 2022 America/Los_Angeles ------------------------------


cols_keep = c("Location_name",
              "Receiver",
              "Latitude",
              "Longitude",
              "Start",
              "End",
              "Origin")

# PATH deployments
post12 = read.csv("~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Davis/deploys_post2012_final.csv")

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

pre12 = read.csv("~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Davis/deploys_pre2012_excluding2012_FINAL.csv")

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


chk_overlaps = function(df) {
  
  if(length(unique(df$Location_name)) == 1) return(FALSE) # if the receiver doesn't have more than 1 location, don't continue further in the function
  any(as.Date(df$Start[-1]) < as.Date(df$End[-nrow(df)])) # gets rid of first start value and last end value so that the rows line up, and then checks if any receiver has a start date that occurs before its previous end date
  
}

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


# Isolate just the receivers that seem to be deployed in more than one place at the same time:

# within a data frame: split by location_name, and check the overlaps across the intervals: do any of the intervals (start, end) from location A fall within location B...etc?

# return: a list with the overlapping rows, one list entry per overlap, two rows per entry

library(data.table)

z = split(bb, bb$Location_name) # two receiver dfs
z = lapply(z, setDT)

x = z[[1]]
y = z[[2]]

setkey(y, Start, End) # marks it as sorted with an attribute "sorted"; always sorted in ascending order. Reorders the DT by the columns provided and stores it that way

res = data.table::foverlaps(x,
                      y,
                      type = "within",
                      which = TRUE,
                      nomatch = NULL)


ans = list()
#ans[[1]] = as.data.frame(rbind(x[res$xid[1], ], y[res$yid[1], ]))

for(i in 1:nrow(res)) {
  
  ans[[i]] = as.data.frame(rbind(x[res$xid[i], ],
                                 y[res$yid[i], ]))
  
}


# Three locations:
z = aa$`102242`
z = split(z, z$Location_name)
z = lapply(z, setDT)

a = z[[1]]
b = z[[2]]
c = z[[3]]

setkey(a, Start, End)
setkey(b, Start, End)
setkey(c, Start, End)

# try with two locs:
data.table::foverlaps(a,
                      b,
                            type = "within",
                            which = TRUE,
                            nomatch = NULL)

res = mapply(
  foverlaps,
  x = list(b, b), # is it not working because foverlaps can't take lists as x&y? 
  y = list(a, c),
  MoreArgs = list(
                type = "within",
                which = TRUE,
                nomatch = NULL),
  SIMPLIFY = FALSE
)

res


## Functionalizing
table(sapply(aa, function(x) length(unique(x$Location_name)))) # some receivers have 4 or 5 locations that could potentially contain overlapping rows

return_overlaps = function(z) { # all the deployments for a single receiver
  
  
  if(length(z) != 2) stop("locations != 2")
    
    x = z[[1]]
    y = z[[2]]
    
    setkey(y, Start, End)
    
    res = data.table::foverlaps(x,
                                y,
                                type = "within",
                                which = TRUE,
                                nomatch = NULL)
    if(nrow(res)) {
    ans = list()
    for(i in seq(nrow(res))) {

      ans[[i]] = as.data.frame(rbind(x[res$xid[i], ],
                                     y[res$yid[i], ]))

    }
    
    } else {
      
    ans = NULL }
    
    return(ans)
    
  }
  
# Function that takes dfs with multiple receiver locations and makes them into pairs of locations to feed into return_overlaps:

feeder = function(rec_df, split_col = "Location_name") {

  z = lapply(split(rec_df, rec_df[[split_col]]), setDT)

  if(length(z) < 2 ) return(FALSE) # if there is only 1 location, can't run foverlaps

  if(length(z) == 2) ans = return_overlaps(z)

  if(length(z) > 2) {
 
  # create a matrix/array of pairwise indices
  idx = combn(length(z), 2, simplify = FALSE)
  ans = lapply(idx, function(i) return_overlaps(z[i]))
  ans = ans[!sapply(ans, is.null)] # only include the non-nulls
  }
  
  return(ans)
  
}

test = aa$`102242`

ans = feeder(test)
ans
