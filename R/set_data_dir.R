# Sets the data directory once and then looks up
# M. Espe, M. Johnston

data_dir =
  switch(Sys.info()["user"],
         myfanwyjohnston = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data",
         matt = "/home/matt/consulting/cfs/Projects/WST_Synthesis/Data/",
         mattespe = "/home/mattespe/consulting/cfs/Projects/2022-white_sturgeon_synthesis/data",
         stop("User not known")
  )

# Make sure the directory is actually there
if(!dir.exists(data_dir))
  stop("data directory does not exist on this system. Please check R/set_data_dir.R")

saveRDS(data_dir, "data/data_dir_local.rds")
