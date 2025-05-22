
CREATE TABLE Ratings_Table (
    moviesID INT PRIMARY KEY,
    Title VARCHAR(255),
    IMDb_Score FLOAT,
    Rotten_Tomatoes_Score FLOAT,
    Metacritic_Score FLOAT
);

CREATE TABLE Movies_Table (
    moviesID INT PRIMARY KEY,
    Title VARCHAR(255),
    Genre VARCHAR(255),
    Languages VARCHAR(255),
    Series_or_Movie VARCHAR(50),
    Director VARCHAR(255),
    Release_Date DATE,
    Netflix_Release_Date DATE,
    Production_House VARCHAR(1000),
    Summary TEXT,
    Awards_Received FLOAT,
    Awards_Nominated_For FLOAT,
    Boxoffice VARCHAR(50)
);

CREATE TABLE FilmCredits_Table (
    moviesID INT PRIMARY KEY,
    Title VARCHAR(255),
    Runtime VARCHAR(50),
    Director VARCHAR(255),
    Writer TEXT,
    Actors TEXT,
    Release_Date DATE,
    Netflix_Release_Date DATE,
    Production_House VARCHAR(1000)
);

CREATE TABLE Genre_Table (
    moviesID INT PRIMARY KEY,
    Genre VARCHAR(255)
);

CREATE TABLE Person (
  personID   SERIAL PRIMARY KEY,
  name       VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE MovieActor (
  moviesID    INT NOT NULL REFERENCES Movies_Table(moviesID) ON DELETE CASCADE,
  personID   INT NOT NULL REFERENCES Person(personID) ON DELETE CASCADE,
  PRIMARY KEY (moviesID, personID)
);

CREATE TABLE MovieWriter (
  moviesID    INT NOT NULL REFERENCES Movies_Table(moviesID) ON DELETE CASCADE,
  personID   INT NOT NULL REFERENCES Person(personID) ON DELETE CASCADE,
  PRIMARY KEY (moviesID, personID)
);