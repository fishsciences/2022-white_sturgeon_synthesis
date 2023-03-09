CREATE TABLE tags (
  StudyID TEXT,
  DateTagged TEXT NOT NULL,
  TagID INTEGER NOT NULL,
  CodeSpace INTEGER,
  TagCode TEXT,
  Release_location TEXT,
  FL_cm REAL,
  Sex TEXT,
  TagEnd TEXT,
  PRIMARY KEY(TagID, DateTagged, StudyID)
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
