# This is the original query used to get the full detections, deployments, and receiver lat/long data from the old Klimley server (Biotelemetry Lab, UC Davis).  This query was run on 2022-06-03 and the data was saved locally, then added to the data.dir for use in this analysis.
# Data and script are now READ ONLY.
# This script is just to document where the data came from.
# M. Johnston
#-----------------------------------
library(DBI)
library(RPostgres)


# Load .Renviron file.
readRenviron("~/Desktop/.Renviron")

# Connect to database "pathnode".
con <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("DBHOST"),
  user = Sys.getenv("DBUSER"),
  password = Sys.getenv("DBPASSWORD"),
  dbname = "69kHz_Acoustic_Biotelemetry_Database"
)

RPostgres::dbListTables(con)

#x = dbGetQuery(con, "SELECT * FROM information_schema.tables;")

dbGetQuery(con, "SELECT schema_name
FROM information_schema.schemata;")

dbGetQuery(con, 'SELECT * FROM "UCD_69kHz_telemetry_data"."Detections_all" 
                 WHERE "Tag_ID" = 245 AND "Codespace" = \'A69-1206\' 
           LIMIT 20')

if(FALSE){
dets = dbGetQuery(con, 'SELECT * FROM "UCD_69kHz_telemetry_data"."Detections_all" 
                  WHERE "Tag_ID" IN (2841, 2842, 2843, 2844, 2845, 2846, 2847, 2848, 2849, 2850, 
2851, 2852, 2853, 2854, 2855, 2856, 2857, 2858, 2859, 2860, 2861, 
2862, 2863, 2864, 2865, 2866, 2867, 2868, 2869, 2870, 2871, 2872, 
2873, 2875, 2876, 2877, 2878, 2879, 2880, 2881, 2882, 2883, 2884, 
2885, 2886, 19525, 19526, 19538, 19540, 19541, 19542, 19543, 
19544, 19545, 19546, 19547, 19548, 19549, 19550, 19551, 19552, 
19553, 19554, 19555, 19556, 19557, 19558, 19559, 19560, 19561, 
19562, 19563, 19564, 23886, 23887, 23888, 23889, 23890, 23891, 
23892, 23893, 23894, 23895, 23896, 23897, 23898, 23899, 25618, 
25619, 25620, 25621, 25622, 25623, 25624, 25625, 25626, 25627, 
25628, 25629, 25630, 25631, 25632, 25839, 25840, 25841, 25842, 
25843, 25844, 25845, 25846, 25847, 25848, 27450, 27451, 27452, 
27453, 27454, 27455, 27456, 27457, 27458, 27459, 27460, 27461, 
27462, 27463, 27464, 27465, 27466, 27467, 27468, 27469, 34027, 
46640, 46641, 46642, 46643, 46644, 46688, 47821, 47822, 47823, 
47824, 47825, 47826, 47827, 47828, 47829, 47830, 47831, 47832, 
47833, 47834, 47835, 47836, 47837, 47838, 47839, 47840, 47842, 
47843, 47844, 47845, 47846, 47847, 47848, 47849, 47850, 47851, 
47852, 47853, 47854, 47855, 47856, 47857, 47858, 47859, 47860, 
47861, 47862, 47863, 47864, 47865, 47866, 47867, 47868, 47869, 
47871, 47872, 47873, 47874, 47875, 47876, 47877, 47878, 47879, 
47881, 47882, 47883, 47884, 56401, 56403, 56404, 56405, 56406, 
56408, 56409, 56410, 56411, 56412, 56413, 56414, 56415, 56416, 
56417, 56418, 56419, 56420, 56421, 56422, 56423, 56424, 56425, 
56426, 56427, 56428, 56429, 56430, 56431, 56432, 56434, 56435, 
56436, 56437, 56438, 56439, 56440, 56441, 56442, 56443, 56444, 
56445, 56446, 56447, 56448, 56449, 56450, 56451, 56452, 56453, 
56454, 56455, 56456, 56458, 56460, 56461, 56462, 56463, 56464, 
56465, 56466, 56467, 56468, 56469, 56471, 56473, 56474, 56475, 
56476, 56477, 56478, 56479, 56480, 56481, 56482, 56483, 56484, 
56485, 56486, 56487, 56488, 56489, 56490, 56491, 56492, 56493, 
56494, 62769, 62770, 62771, 62772, 62773, 62774, 62775, 62776, 
62777, 62779, 62780, 62781, 62782, 62783, 62784, 62785, 62786, 
62787, 62788, 62789, 62790, 62791, 62792, 62793, 62794, 62795, 
62796, 62797, 62798, 62799, 62800, 62801, 63038, 63039, 63040, 
63041, 63042, 63043, 63044, 63045, 63046, 63047, 63048, 63050, 
63051, 63052, 63053, 63054, 63055, 63056, 63057)')


saveRDS(dets, "data/allBARDdets_2022-06-03.rds")

deps = dbGetQuery(con, 'SELECT * FROM "UCD_69kHz_telemetry_data"."Receiver_deployments"')
str(deps)
saveRDS(deps, "data/BARD_deployments_all_2022-06-24.rds")

locs = dbGetQuery(con, 'SELECT * FROM "UCD_69kHz_telemetry_data"."Receiver_locations"')
str(locs)
saveRDS(locs, "data/BARD_Receiver_locations_2022-06-24.rds")
}

unique(dbGetQuery(con, "SELECT * FROM information_schema.tables;"))$table_name

DBI::dbDisconnect(con)
