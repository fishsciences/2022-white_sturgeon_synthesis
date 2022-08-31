# QA/QC deployments from Kimbly server
# M. Espe
# 2022 Aug

source("R/overlap_funs.R")

d = read.csv("Data/Davis/Deployments_from_Klimley_Server_20220830.csv")

d$Start = as.POSIXct(d$Start, tz = "Etc/GMT+8")
d$Stop[d$Stop == "NULL"] = NA
d$Stop = as.POSIXct(d$Stop, tz = "Etc/GMT+8")

d2 = split(d, d$VR2SN)

d2 = d2[sapply(d2, nrow) > 1]
ff = lapply(d2, get_overlaps, "Start", "Stop")
ff = ff[sapply(ff, length) > 0]

ff[[1]]

