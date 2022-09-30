# Combining tag tables to prep for UCD BARD query
# M. Johnston
# Fri Sep 30 10:27:40 2022 America/Los_Angeles ------------------------------

source('R/utils.R') # sources data-dir script to set dropbox path
# columns needed:
#Tag_ID, DateTagged, Codespace, Freq_kHz, Tagging/Release_location, StudyID, 
# FL_cm, TagLife_days, TagEnd, Sex

# ONly want V16 tags - no V13s or PIT tags
# All SJR and SAC fish are 10-year tags; YOLO you have to use the TAgLifeEnd column

library(lubridate)
keepcols = c("StudyID", 
             "DateTagged",
             "TagID",
             "CodeSpace",
             "TagCode",
             "Release_location",
             "FL_cm",
             "Sex",
             "TagEnd")
# ------------------------------------
# San Joaquin River Tags
#-------------------------------------
d = readxl::read_excel(file.path(data_dir, "Lodi/LFWO_SJR_WST_Acoustic_Tags.xlsx"))

d = d[ , c("TagCode", "DateTagged", "FL_cm", "Sex")]

d = tidyr::separate(d, TagCode, into = c("Freq_kHz", "CodeSpace", "TagID"), remove = FALSE, convert = TRUE)

# no data on time of tagging/release; default to 8am PST on the date tagged:
d$DateTagged = as.Date(d$DateTagged)
d$Release_location = "San Joaquin River"
d$StudyID = "SJR WST"
range(d$DateTagged)

d$TagEnd = as.POSIXct((d$DateTagged + 3650), format = "%Y-%m-%d")

stopifnot(all(keepcols %in% colnames(d)))

d = d[ , keepcols]

# ------------------------------------
# Yolo Tags
#-------------------------------------
y = readxl::read_excel(file.path(data_dir, "Yolo/wst_all_metadata.xlsx"))
y2 = readxl::read_excel(file.path(data_dir, "Yolo/wst_tags.xlsx"))

y2 = y2[ , c("DateTagged", "CodeSpace", "TagID", "Sex")]
y2$TagCode = paste("A69-", y2$CodeSpace, "-", y2$TagID, sep = "")
y2 = merge(y2, y[ , c( "Tag ID Number", "Fork Length (cm)", "Tag Life End")], by.x = "TagID", by.y = "Tag ID Number")

y2$DateTagged = as.Date(y2$DateTagged)

y2 = dplyr::rename(y2, FL_cm = `Fork Length (cm)`,
                     TagEnd = `Tag Life End`)

y2$Freq_kHz = "A69"
y2$Release_location = "Yolo Bypass"
y2$StudyID = "YOLO WST"
y2[ , c("TagID", "CodeSpace")] <- lapply(y2[ , c("TagID", "CodeSpace")], as.integer)

stopifnot(all(keepcols %in% colnames(y2)))

y2 = y2[ , keepcols]

# ------------------------------------
# Sacramento River Tags
#-------------------------------------
m = read.csv(file.path(data_dir, "Sacramento/Miller_USACE_white_sturgeon_tag_ids.csv"))

m = m[, c(
  "Date",
  "Location",
  "Fork.length.cm.",
  "Sex",
  "Tag.ID.",
  "Tag.Type"
)]
# get rid of v13s
m = m[m$Tag.Type != "v13" & !is.na(m$`Tag.ID.`), ]

m = dplyr::rename(m, 
                  FL_cm = Fork.length.cm., 
                  DateTagged = Date,
                  Release_location = Location,
                  TagID = Tag.ID.)

m$DateTagged = as.Date(m$Date, format = "%m/%d/%y")

m$Freq_kHz = "A69"
m$CodeSpace = 1303L
m$TagCode = paste(m$Freq_kHz, m$CodeSpace, m$TagID, sep = "-")
m$StudyID = "SAC WST"

m$TagEnd = as.POSIXct((m$DateTagged + 3650), format = "%Y-%m-%d")

m = dplyr::select(m, TagID, DateTagged, Release_location, FL_cm, Sex, StudyID, CodeSpace, TagCode, TagEnd)

stopifnot(all(keepcols %in% colnames(m)))

m = m[ , keepcols]

# all = merge x and San Joaquin River tags
all.tags = dplyr::bind_rows(d, y2, m)
csn(all.tags)
range(all.tags$DateTagged)

saveRDS(all.tags, "data_clean/alltags.rds")
