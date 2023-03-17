CREATE TABLE merged_detections (
  Receiver INTEGER NOT NULL,
  LocationName TEXT NOT NULL,
  TagID TEXT NOT NULL,
  DateTimeUTC TEXT NOT NULL,
  DateTimePST TEXT NOT NULL,
  Latitude REAL,
  Longitude REAL,
  DetOrigin TEXT,
  StudyID TEXT,
PRIMARY KEY(TagID, DateTimeUTC, Receiver, LocationName)
)


