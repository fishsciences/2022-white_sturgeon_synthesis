# Parse Lodi Detections
# M. Johnston
# Wed Jun 22 13:18:31 2022 ------------------------------

# Steps
# append BARD dets to Yolo dets
# append BARD deployments to Yolo deployments

# Query Yolo for detections and deployments tables
# Pare down dets columns to only DateTimeUTC, TagID, and Receiver

# Create new database with:
# - Yolo/BARD pared dets table
# - Yolo/BARD deployments table
# - New tagging table with all tags

# Append database with Lodi entries:
# - detections below
# - deployments (formatted)
# - New tagging table


data_dir = "~/DropboxCFS/NEW PROJECTS - EXTERNAL SHARE/WST_Synthesis/Data/Lodi/Lodi_DC/"

files = list.files(path = data_dir, pattern = ".csv", full.names = TRUE, recursive = TRUE)

dd = do.call(rbind, lapply(files, read.csv))
str(dd)
head(dd)

dd$DateTimeUTC = dd$Date.and.Time..UTC.
# Check
tz(dd$DateTimeUTC)


# Clean up column names
dd$TagID = dd$Transmitter


cols = c("DateTimeUTC", "TagID", "Receiver")

# Combine and find dups
tmp = as.data.table(dd[,cols])
# Need to exclude NA cols, because not marked as dups
i = duplicated(tmp[,c("DateTimeUTC", "Receiver", "TagID")]) #
sum(i)

