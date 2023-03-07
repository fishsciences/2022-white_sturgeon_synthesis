
# White Sturgeon Telemetry Synthesis

<!-- badges: start -->
<!-- badges: end -->

Data sources and recipes:

    The raw data (detections, deployments, and tags) is stored on the CFS Dropbox (New Projects External Share/WST_synthesis). Access gets configured for individual users in R/set_data_dir.R, which saves an RDS file of the character string for the filepath; this RDS is read in to set the data.dir at the top of most of the qaqc scripts.

# Raw Detections

### Yolo
  Source: ybt .sqlite database
  Script: R/get_yolo_raw_data.R. Connects to the db and queries full detection table
  Output: data.dir/Yolo/yolo_detections.rds
  
### bard/path
  Source: R/SJ_Sturgeon_Detection_Query_20220523.r is the read-only, original query used for the old BARD database. UCD gave M. Johnston access to the old Klimley Biotelemetry lab server in May 2022.
  Script: R/SJ_Sturgeon_Detection_Query_20220523.r
  Output: data/allBARDdets_2022-06-03.rds. After query, this file got copied to the dropbox data directory so that external researchers could access it; the dropbox file is the one that gets used in the analysis.

### sjr/lodi
  Source: data.dir/Lodi/Lodi_DC/*.csv. All the original vrls from CDFW were collated by the Lodi office and sent to CFS, where we added them to a .vdb and drift-corrected them before exporting as .csvs. These drift-corrected .csvs get read into the qaqc_detections script.

## Combined detections:
  Source(s): data.dir/Yolo/yolo_detections.rds, data.dir/Lodi/Lodi_DC/*.csvs, data.dir/Davis/allBARDdets_2022-06-03.rds
  Script: R/combine_detections.R
  Output: data/WST_detections.rds

## QAQC'd, cleaned detections:

* Source(s): data_clean/alldeps.rds, data/WST_detections.rds, data_clean/alltags.rds
* Script: R/qaqc_detections.R
* Output: data_clean/alldets.rds

  
# Raw Deployments

### yolo
* Source: data.dir/Yolo/ybt .sqlite database
* Script: R/get_yolo_raw_data.R. Connects to db & queries full deployments table.
* Output: data.dir/Yolo/ydep.rds
  
### bard/path
  Source: PATH deployments .csv, sent by UC Davis on 9/10/22: data.dir/Davis/Deployments_UTC_091022.csv. We also use data/BARD_deployments_all_2022-06-24.rds, which was queried in the same script as the BARD detections.
  Script: R/get_bard_deployments.R. Does some formatting and checking to prep for combining.
  Output: data/bard_depsQ42022.rds

### sjr/lodi
  Source: data.dir/Lodi/LFWO_SJR_WST_Receiver_Deployment_separatedByVRL.xlsx. This file was processed at CFS by manually collating and cross-checking the Lodi deployment records with Lauren Heironimus' backup records, which went through 2016. File gets pulled directly into the deployments qaqc script.
  
## Cleaned deployments:
  Sources: data.dir/Yolo/ydep.rds, data/bard_depsQ42022.rds, data.dir/BARD_deployments_all_2022-06-24.rds,  data.dir/Lodi/LFWO_SJR_WST_Receiver_Deployment_separatedByVRL.xlsx, data.dir/Yolo/YoloLatLongs.xlsx (compiled by MEJ, 2022)
  Script: R/clean_deployments.R
  Output: data_clean/alldeps.rds

# Raw Tags

### yolo

* Sources:  data.dir/Yolo/wst_all_metadata.xlsx, data.dir/Yolo/wst_tags.xlsx
* Script: R/combine_tags.R
* Output: data_clean/alltags.rds, data_clean/alltags.csv (for collaborators)

### davis (Miller)

* Source: data.dir/Sacramento/Miller_USACE_white_sturgeon_tag_ids.csv
* Script: R/combine_tags.R
* Output: data_clean/alltags.rds, data_clean/alltags.csv (for collaborators)

### sjr/lodi

* Source: data.dir/Lodi/LFWO_SJR_WST_Acoustic_Tags.xlsx
* Script: R/combine_tags.R
* Output: data_clean/alltags.rds, data_clean/alltags.csv (for collaborators)
