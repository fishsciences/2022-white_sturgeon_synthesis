CREATE TABLE tags (
  DateTagged TEXT,
  TagID INTEGER NOT NULL,
  TagSN INTEGER,
  CodeSpace INTEGER,
  EstTagLife_days REAL,
  Species TEXT,
  TL REAL,
  FL REAL,
  Sex TEXT,
  TagLoc TEXT,
  StudyID TEXT,
  Comments TEXT,
  FishID REAL,
  PRIMARY KEY(TagID, TagSN, DateTagged, FishID)
);

CREATE TABLE detections (
  TagID TEXT NOT NULL,
  DateTimeUTC TEXT NOT NULL,
  DateTimePT TEXT NOT NULL,
  Receiver TEXT NOT NULL,
  SensorValue TEXT,
  SensorUnit TEXT,
  PRIMARY KEY(TagID, DateTimeUTC, Receiver)
);

CREATE TABLE deployments (
  Station TEXT NOT NULL,
  Receiver INTEGER,
  DeploymentStartPT TEXT,
  DeploymentEndPT TEXT,
  Latitude REAL,
  Longitude REAL,
  Basin TEXT,
  Origin TEXT,
  Notes TEXT,
  PRIMARY KEY(Station, Receiver, DeploymentStartPT)
);
