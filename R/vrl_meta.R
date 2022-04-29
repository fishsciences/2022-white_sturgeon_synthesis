# Lodi vrl data EDA
# M. Johnston
# Tue Mar 15 13:31:37 2022 ------------------------------

data_dir = readRDS("data/data_dir_local.rds")
files = list.files(file.path(data_dir, "Lodi/LFWO_SJR_WST_ALL_VR2W.VRL"), full.names = TRUE)
files2 = grep(pattern = "VR2W180_|-RLD_", files, invert = TRUE, value = TRUE) # invert gives us all the things that don't match, and value = TRUE says return the actual string, not the index of the location of the string

# extract rec SN
# extract date of VRL

vrl_meta = function(full_filepath) {
  
  # ( ) creates a capture group
  # pattern: has the prefix, and the first capture group (alphanumeric, 6 characters), and .* = any character
  # replacement: replaces the pattern with the first capture group, which will be the serial number
  data.frame(Receiver = as.integer(gsub("VR2W_([0-9]{6})_.*", replacement = "\\1", x = basename(full_filepath))),
  Date = as.Date(gsub("VR2W_[0-9]{6}_([0-9]{8})_.*", replacement = "\\1", x = basename(full_filepath)),
                 format = "%Y%m%d")
  )
  # could also have split on the underscore
}

# x = strsplit(basename(files), split = "_") # how could I put this into a data.frame?
# ans = as.integer(sapply(x, "[[", 2)) # rec SNs
# date = as.Date(sapply(x, "[[", 3), format = "%Y%m%d")

ans = do.call(rbind, lapply(files2, vrl_meta))


# Goal: match receiver SNs with deployments SN, and make sure all dates fall within the window of deployments mentioned.

dep = as.data.frame(readxl::read_excel(file.path(data_dir, "Lodi/LFWO_SJR_WST_Receiver_Deployment.xlsx")))


dim(dep)
length(unique(dep$Receiver))
dep$combo = paste(dep$Station, dep$Receiver, sep = "-")
length(unique(dep$combo))

ans$chk = NA

for(i in 1:nrow(ans)) {
  x = ans$Receiver[i]
  matching_in_dep = dep[dep$Receiver == x, ]
  
  d = ans$Date[i] 
  
  ans$chk[i] = sum(d >= matching_in_dep$DeploymentStart & d <= matching_in_dep$DeploymentEnd)
  
}

ans$chk = factor(ans$chk, levels = 0:2, labels = c("No match within deployments",
                                                   "Date falls within a deployment",
                                                   "Multiple matches within a deployment"))

ans[ans$chk == "Multiple matches within a deployment", ]

dep[dep$Receiver == 113007, ]

# Check Start is before end deployment
stopifnot(all(dep$DeploymentStart < dep$DeploymentEnd))

# Receivers at multiple locations
tt = table(dep$Receiver)
tt[ tt > 1 ]

# "combo" might already resolve these
stopifnot(all(sort(table(dep$combo)) == 1))

# deployment gaps and coverage
tmp = split(dep, dep$Station)

sapply(tmp, nrow)

dep_range = lapply(tmp, function(df){
    c(min(df$DeploymentStart), max(df$DeploymentEnd))
})

dep_gaps = lapply(tmp, function(df) {
    if(nrow(df) > 1) {
        df = df[order(df$DeploymentStart),]
        difftime(df$DeploymentStart[-1], df$DeploymentEnd[-nrow(df)], units = "days")
    } else
        0
})
