# Makefile for White Sturgeon synthesis
# makes detections, deployments, and tagging tables for further analysis

DATA_DIR = $(shell Rscript -e 'cat(readRDS("data/data_dir_local.rds"))')

RSCRIPT = Rscript $<

BARD_RAW = $(addprefix $(DATA_DIR), 																	\
						/Davis/Deployments_UTC_091022.csv)

TAGS_RAW = $(addprefix $(DATA_DIR), 																	\
						/Lodi/LFWO_SJR_WST_Acoustic_Tags.xlsx 											\
						/Yolo/wst_all_metadata.xlsx 													\
						/Yolo/wst_tags.xlsx 																					\
						/Sacramento/Miller_USACE_white_sturgeon_tag_ids.csv)

DETS_RAW = $(addprefix $(DATA_DIR),																		\
						/Davis/allBARDdets_2022-06-03.rds												\
						/Yolo/yolo_detections.rds														\
						/Lodi/Lodi_DC/lodi_dc_2010/lodi_dc_2010.csv										\
						/Lodi/Lodi_DC/lodi_dc_2011/lodi_dc_2011.csv										\
						/Lodi/Lodi_DC/lodi_dc_2012/lodi_dc_2012.csv										\
						/Lodi/Lodi_DC/lodi_dc_2013/lodi_dc_2013.csv										\
						/Lodi/Lodi_DC/lodi_dc_2014/lodi_dc_2014.csv										\
						/Lodi/Lodi_DC/lodi_dc_2015/lodi_dc_2015.csv										\
						/Lodi/Lodi_DC/lodi_dc_2016/lodi_dc_2016.csv										\
						/Lodi/Lodi_DC/lodi_dc_2017/lodi_dc_2017.csv										\
						/Lodi/Lodi_DC/lodi_dc_2018/lodi_dc_2018.csv										\
						/Lodi/Lodi_DC/lodi_dc_2019/lodi_dc_2019.csv										\
						/Lodi/Lodi_DC/lodi_dc_2020/lodi_dc_2020.csv										\
						/Lodi/Lodi_DC/lodi_dc_2021/lodi_dc_2021.csv)	

DEPS_RAW = $(addprefix $(DATA_DIR), 																	\
						/Lodi/LFWO_SJR_WST_Receiver_Deployment_separatedByVRL.xlsx						\
						/Lodi/LFWO_SJR_WST_Receiver_Deployment.xlsx 									\
						/Yolo/ydep.rds /Yolo/YoloLatLongs.xlsx											\
						/spatial/Basins.kml																\
						/Davis/BARD_deployments_all_2022-06-24.rds)

YOLO_DB = $(addprefix $(DATA_DIR), /Yolo/ybt_database.sqlite)

TARGET = data_clean/alltags.rds data_clean/alldeps.rds data_clean/alldets.rds data_clean/all_rec_locs.csv data_clean/orphan_dets.csv

data/data_dir_local.rds : R/set_data_dir.R
	$(RSCRIPT)

data/bard_depsQ42022.rds : R/get_bard_deployments.R R/overlap_funs.R data/data_dir_local.rds $(BARD_RAW)
	$(RSCRIPT)

data_clean/alltags.rds : R/combine_tags.R data/data_dir_local.rds $(TAGS_RAW) | data_clean
	$(RSCRIPT)

data/WST_detections.rds : R/combine_detections.R data_clean/alltags.rds data/data_dir_local.rds $(DETS_RAW)
	$(RSCRIPT)

data_clean/alldeps.rds : R/clean_deployments.R															\
						 R/overlap_funs.R 																\
						 data/data_dir_local.rds														\
						 data/WST_detections.rds														\
						 data/bard_depsQ42022.rds 														\
						 $(DEPS_RAW) | data_clean
	$(RSCRIPT)

data_clean/alldets.rds : R/qaqc_detections.R data_clean/alldeps.rds data/WST_detections.rds data_clean/alltags.rds  | data_clean
	$(RSCRIPT)

data_clean/all_rec_locs.csv : R/receiver_map.R data_clean/alldeps.rds | data_clean
	$(RSCRIPT)

data_clean/orphan_dets.csv : R/qaqc_detections.R data_clean/alldeps.rds data/WST_detections.rds data_clean/alltags.rds | data_clean
	$(RSCRIPT)

$(DATA_DIR)/Yolo/yolo_detections.rds $(DATA_DIR)/Yolo/ydep.rds &: R/get_yolo_raw_data.R data/data_dir_local.rds $(YOLO_DB)
	$(RSCRIPT)

all: $(TARGET)

clean: 
	rm $(TARGET)

test: 
	echo $(DETS_RAW)

data_clean:
	mkdir -p $@
