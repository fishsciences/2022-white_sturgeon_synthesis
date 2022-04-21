# Combining tag tables to prep for UCD BARD query
# M. Johnston
# Wed Apr 20 13:48:56 2022 ------------------------------

# columns needed:
#Tag_ID, Tag_ser_num, Codespace, Tag_type, Frequency_kHz, Release_date_time, Release_location, Study_ID

d = readxl::read_excel("data/Lodi/LFWO_SJR_WST_Acoustic_Tags.xlsx")

d = d[ , c("TagCode", "SN", "DateTagged", "FL_cm", "PIT")]

d = ybt::parse_tagid_col(df = d, tagcol = "TagCode", sepchar = "-")
str(d)

d$Frequency_kHz = 69
d$Release_date_time = lubridate::ymd_hms(paste(d$DateTagged, "08:00:00", sep = " "), tz = "Etc/GMT+8")
d$Release_location = "San Joaquin River"
d$Study_ID = "SJR WST/Jackson/Heironimus"
d = dplyr::rename(d, Tag_ser_num = SN)

range(d$DateTagged)

write.csv(d, "data_clean/JacksonHeironimusSJRWST_NEWTAGS.csv", row.names = FALSE)

y = readxl::read_excel("data/Yolo/wst_tags.xlsx")
y = y[ , c("DateTagged", "FL", "CodeSpace", "TagID", "TagSN")]
y = dplyr::rename(y, FL_cm = FL,
                     Tag_ser_num = TagSN)

y$Frequency_kHz = 69
y$Release_location = "Yolo Bypass"
y$Study_ID = "UCD Yolo Bypass WST/Johnston"
y$DateTagged = as.Date(y$DateTagged)
range(y$DateTagged)

m = read.csv("data/Sacramento/Miller_USACE_white_sturgeon_tag_ids.csv")
str(m)
m = m[, c(
  "Date",
  "Location",
  "Fork.length.cm.",
  "Tag.ID.",
  "Tag.Sn.",
  "Pit.Tag.ID",
  "Tag.Type",
  "Time.of.Capture"
)]

m = dplyr::rename(m, 
                  FL_cm = Fork.length.cm., 
                  DateTagged = Date,
                  Release_location = Location,
                  TagID = Tag.ID.,
                  Tag_ser_num = Tag.Sn.,
                  PIT = Pit.Tag.ID)

m$DateTagged = as.Date(m$Date, format = "%m/%d/%y")

m = m[m$Tag.Type != "v13" & !is.na(m$TagID), ]

m$Time.of.Capture[is.na(m$Time.of.Capture)] <- "08:00" # assign NAs to 8am on DateTagged
m$Time.of.Capture[m$Time.of.Capture == ""] <- "08:00" # assign NAs to 8am on DateTagged

m$Release_date_time = lubridate::ymd_hm(paste(as.character(m$DateTagged), 
                                             m$Time.of.Capture, sep = " "), tz = "Etc/GMT+8")

m$Study_ID = "UCD Sacramento WST/Miller"
m$CodeSpace = 1303
m = dplyr::select(m, TagID, Tag_ser_num, PIT, DateTagged, Release_location, FL_cm, Study_ID, CodeSpace)
m$Frequency_kHz = 69

x = merge(m, y, all = TRUE)
colSums(is.na(x))

write.csv(x, "data_clean/MillerJohnston_WSTUCD_OLDTAGS.csv", row.names = FALSE)
