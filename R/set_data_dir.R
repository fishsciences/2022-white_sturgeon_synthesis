# Set the data directory for your computer
# currently configured for M.Johnston/M.Espe

data_dir =
  switch(Sys.info()["user"],
         myfanwyjohnston = "~/DropboxCFS/npes/WST_Synthesis/Data",
         matt = "/home/matt/consulting/cfs/Projects/2022-white_sturgeon_synthesis/Data",
         stop("User not known")
  )

# Make sure the directory is actually there
if(!dir.exists(data_dir))
  stop("data directory does not exist on this system. Please check and/or source R/set_data_dir.R")

saveRDS(data_dir, "data/data_dir_local.rds")
