# Lodi data EDA
# M. Johnston
# Tue Mar 15 13:31:37 2022 ------------------------------

library(ybt)
check_vrls

files = list.files("~/DropboxCFS/NewPROJECTS/DSCSAC-2021-YR1-White_Sturgeon_Telemetry_Synthesis/WORKING/Data/Lodi/LFWO_SJR_WST_ALL_VR2W.VRL/", full.names = TRUE)

# extract rec SN
# extract date of VRL

vrl_meta = function(full_filepath) {
  
  # ( ) creates a capture group
  # pattern: has the prefix, and the first capture group (alphanumeric, 6 characters), and .* = any character
  # replacement: replaces the pattern with the first capture group, which will be the serial number
  RecSN = gsub("VR2W_([0-9]{6})_.*", replacement = "\\1", x = basename(full_filepath))
  Date = gsub("VR2W_[0-9]{6}_([0-9]{8})_.*", replacement = "\\1", x = basename(full_filepath))
  
  # could also have split on the underscore and 
  
  
}

str = "VR2W_113011_20120517_1_edited.vrl"
x = strsplit(basename(files), split = "_")
ans = as.integer(sapply(x, "[[", 2))
date = as.Date(sapply(x, "[[", 3), format = "%Y%m%d")
