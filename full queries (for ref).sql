CREATE TABLE Ratings_Table (
    moviesID INT PRIMARY KEY,
    Title VARCHAR(255),
    IMDb_Score FLOAT,
    Rotten_Tomatoes_Score FLOAT,
    Metacritic_Score FLOAT
);

select * from Ratings_Table

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
    Title VARCHAR(255) ,
    Runtime VARCHAR(50),
    Director VARCHAR(255) ,
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

SELECT Genre, COUNT(Title) AS "Number of Movies"
FROM Movies_Table
GROUP BY Genre;

SELECT MIN(Boxoffice) AS "Minimum Box Office Collection"
FROM Movies_Table;

SELECT M.Title, R.Rotten_Tomatoes_Score
FROM Movies_Table M
JOIN Ratings_Table R ON M.moviesID = R.moviesID;

SELECT M.Title, R.Rotten_Tomatoes_Score
FROM Movies_Table M
JOIN Ratings_Table R ON M.moviesID = R.moviesID
WHERE R.Rotten_Tomatoes_Score > (
    SELECT AVG(Rotten_Tomatoes_Score) FROM Ratings_Table
);

SELECT Title, IMDb_Score
FROM Ratings_Table
ORDER BY IMDb_Score DESC;

ALTER TABLE Ratings_Table
  DROP COLUMN Title;

SELECT moviesid, boxoffice
  FROM movies_table
 WHERE boxoffice ~ '[^0-9\.\,]';

UPDATE Movies_Table
   SET Boxoffice = regexp_replace(Boxoffice, '[$,]', '', 'g')
 WHERE Boxoffice ~ '[$,]';

UPDATE Movies_Table
   SET Boxoffice = NULL
 WHERE trim(Boxoffice) = '';

  
-- 1. Enforcing box‑office, awards, and date logic in movies_table, dropping genre since we have separate table for it
ALTER TABLE movies_table
  DROP COLUMN IF EXISTS genre;

ALTER TABLE movies_table
  ALTER COLUMN boxoffice TYPE numeric(12,2)
    USING boxoffice::numeric,
  ALTER COLUMN awards_received TYPE integer
    USING awards_received::integer,
  ALTER COLUMN awards_nominated_for TYPE integer
    USING awards_nominated_for::integer;
	
ALTER TABLE Movies_Table
  ADD CONSTRAINT chk_movies_awards CHECK (Awards_Received>= 0),
  ADD CONSTRAINT chk_movies_nominations CHECK (Awards_Nominated_For >= 0),
  ADD CONSTRAINT chk_movies_boxoffice CHECK (Boxoffice >= 0),
  ADD CONSTRAINT chk_movies_dates  CHECK (Release_Date<= Netflix_Release_Date
                                             OR Netflix_Release_Date IS NULL);

-- ERROR:  check constraint "chk_movies_dates" of relation "movies_table" is violated by some row 
--Cleaning up bad rows

SELECT moviesID, release_date, netflix_release_date
FROM movies_table
WHERE netflix_release_date < release_date;

--Setting netflix and theatrical release date same as it makes more sense
UPDATE movies_table
SET netflix_release_date = release_date
WHERE netflix_release_date < release_date;


-- 2. Enforcing positive runtime in filmcredits_table

UPDATE FilmCredits_Table
SET Runtime = regexp_replace(Runtime, '\D', '', 'g')
WHERE Runtime ~ '\D';

UPDATE FilmCredits_Table
SET Runtime = NULL
WHERE trim(Runtime) = '';

ALTER TABLE FilmCredits_Table
  ALTER COLUMN Runtime TYPE INT
    USING Runtime::integer;

ALTER TABLE filmcredits_table
  ADD CONSTRAINT chk_filmcredits_runtime CHECK (runtime > 0);

-- 3. Enforcing valid score ranges in ratings_table
ALTER TABLE ratings_table
  ADD CONSTRAINT chk_ratings_imdb CHECK (imdb_score BETWEEN 0 AND 10);

ALTER TABLE ratings_table
  ADD CONSTRAINT chk_ratings_rt   CHECK (rotten_tomatoes_score BETWEEN 0 AND 100);

ALTER TABLE ratings_table
  ADD CONSTRAINT chk_ratings_meta CHECK (metacritic_score BETWEEN 0 AND 100);

-- Eliminate overlapping attributes (attributes repeated in both Movies_Table and FilmCredits_Table)
ALTER TABLE FilmCredits_Table
  DROP COLUMN IF EXISTS Title,
  DROP COLUMN IF EXISTS Release_Date,
  DROP COLUMN IF EXISTS Netflix_Release_Date,
  DROP COLUMN IF EXISTS Production_House,
  DROP COLUMN IF EXISTS Director;

--Enforce 1NF on multi‑valued “Actors” & “Writer”. Storing comma‑separated lists in 
--a single column violates 1NF (you can’t query or index individual actors or writers).
--Putting actors and writers into their own tables

-- a) master list of people (actors & writers)
CREATE TABLE Person (
  personID   SERIAL PRIMARY KEY,
  name       VARCHAR(255) NOT NULL UNIQUE
);

-- b) a Movie–Actor join table
CREATE TABLE MovieActor (
  moviesID    INT NOT NULL REFERENCES Movies_Table(moviesID) ON DELETE CASCADE,
  personID   INT NOT NULL REFERENCES Person(personID)   ON DELETE CASCADE,
  PRIMARY KEY (moviesID, personID));

-- c) a Movie–Writer join table
CREATE TABLE MovieWriter (
  moviesID    INT NOT NULL REFERENCES Movies_Table(moviesID) ON DELETE CASCADE,
  personID   INT NOT NULL REFERENCES Person(personID)   ON DELETE CASCADE,
  PRIMARY KEY (moviesID, personID));

ALTER TABLE FilmCredits_Table
  DROP COLUMN IF EXISTS Actors,
  DROP COLUMN IF EXISTS Writer;

CREATE TABLE staging_filmcredits (
  movieid               INT,
  title                 VARCHAR(255),
  runtime               VARCHAR(50),
  director              VARCHAR(255),
  writer                TEXT,
  actors                TEXT,
  release_date          DATE,
  netflix_release_date  DATE,
  production_house      VARCHAR(1000)
);

ALTER TABLE staging_filmcredits
  RENAME COLUMN movieid TO "moviesID";

SELECT * FROM STAGING_FILMCREDITS

-- Populate Person
INSERT INTO Person(name)
SELECT DISTINCT trim(nm) AS name
FROM (
  SELECT unnest(string_to_array(actors, ','))        AS nm
  FROM staging_filmcredits
  WHERE actors IS NOT NULL

  UNION

  SELECT unnest(string_to_array(writer, ','))        AS nm
  FROM staging_filmcredits
  WHERE writer IS NOT NULL
) sub
ON CONFLICT (name) DO NOTHING;

SELECT * FROM PERSON

-- Populate MovieActor
INSERT INTO MovieActor(moviesID, personID)
SELECT
  s."moviesID",
  p.personID
FROM staging_filmcredits s
  JOIN LATERAL unnest(string_to_array(s.actors, ',')) AS a(raw_name) ON true
  JOIN Person p
    ON p.name = trim(both ' ' FROM a.raw_name)
WHERE s.actors IS NOT NULL
ON CONFLICT DO NOTHING;

-- Populate MovieWriter
INSERT INTO MovieWriter(moviesID, personID)
SELECT
  s."moviesID",
  p.personID
FROM staging_filmcredits s
  JOIN LATERAL unnest(string_to_array(s.writer, ',')) AS w(raw_name) ON true
  JOIN Person p
    ON p.name = trim(both ' ' FROM w.raw_name)
WHERE s.writer IS NOT NULL
ON CONFLICT DO NOTHING;

DROP TABLE IF EXISTS staging_filmcredits;

EXPLAIN ANALYZE
SELECT m.Title, r.IMDb_Score
FROM Movies_Table m
JOIN Ratings_Table r USING (moviesID)
ORDER BY r.IMDb_Score DESC
LIMIT 5;

CREATE INDEX idx_rating_score_desc ON Ratings_Table(imdb_score DESC, moviesID);

EXPLAIN ANALYZE
SELECT m.Title, g.Genre
FROM Movies_Table m
LEFT JOIN Genre_Table g USING (moviesID);

CREATE INDEX idx_genre_moviesid ON Genre_Table(moviesID);

EXPLAIN ANALYZE
SELECT p.name
FROM MovieActor ma
JOIN Person p USING (personID)
WHERE ma.moviesID = 102;

CREATE INDEX idx_movieactor_movies ON MovieActor(moviesID);

EXPLAIN ANALYZE
SELECT p.name
FROM MovieWriter mw
JOIN Person p USING (personID)
WHERE mw.moviesID = 105;

CREATE INDEX idx_moviewriter_movies ON MovieWriter(moviesID);

-- Task 9
-- INSERT QUERIES

INSERT INTO Movies_Table (moviesID, Title, Languages, Series_or_Movie, Release_Date, Netflix_Release_Date, Production_House, Summary, Awards_Received, Awards_Nominated_For, BoxOffice)
VALUES (9999, 'Test Movie', 'English', 'Movie', '2023-11-01', '2023-12-01', 'Test Productions', 'This is a test movie.', 2, 5, 1000000);

SELECT * FROM MOVIES_TABLE WHERE MOVIESID = 9999

INSERT INTO Ratings_Table (moviesID, IMDb_Score, Rotten_Tomatoes_Score, Metacritic_Score)
VALUES (9999, 8.2, 85, 75);

SELECT * FROM RATINGS_TABLE WHERE MOVIESID = 9999

-- DELETE QUERIES
--Deleting the test movie
DELETE FROM Ratings_Table
WHERE moviesID = 9999;

DELETE FROM Movies_Table
WHERE moviesID = 9999;

-- Delete ratings first (because of foreign key constraint)
DELETE FROM Ratings_Table
WHERE moviesID IN (
  SELECT m.moviesID
  FROM Movies_Table m
  JOIN Ratings_Table r USING (moviesID)
  WHERE r.IMDb_Score < 4
    AND EXTRACT(YEAR FROM m.Release_Date) < 2010
);

-- Then delete movies
DELETE FROM Movies_Table
WHERE moviesID IN (
  SELECT m.moviesID
  FROM Movies_Table m
  LEFT JOIN Ratings_Table r USING (moviesID)
  WHERE r.moviesID IS NULL  -- No rating anymore (clean after step 1)
    AND EXTRACT(YEAR FROM m.Release_Date) < 2010
);

SELECT m.moviesID, m.Title, r.IMDb_Score, m.Release_Date
FROM Movies_Table m
JOIN Ratings_Table r USING (moviesID)
WHERE r.IMDb_Score < 4
  AND EXTRACT(YEAR FROM m.Release_Date) < 2010;

SELECT COUNT(*) FROM Movies_Table;

-- Update Query
--If Netflix_Release_Date is NULL, setting it to one month after Release_Date
UPDATE Movies_Table
SET Netflix_Release_Date = Release_Date + INTERVAL '1 month'
WHERE Netflix_Release_Date IS NULL;

SELECT moviesID, Title, Release_Date, Netflix_Release_Date
FROM Movies_Table
WHERE Netflix_Release_Date IS NOT NULL
  AND Netflix_Release_Date = Release_Date + INTERVAL '1 month';

--Trimming extra spaces in Production House names
UPDATE Movies_Table
SET Production_House = trim(Production_House)
WHERE Production_House IS NOT NULL;

SELECT moviesID, Title, Production_House
FROM Movies_Table
WHERE Production_House ~ '^\s+|\s+$';

-- Select Query 
-- Finding top 5 rated IMDb movies
SELECT m.Title, r.IMDb_Score
FROM Movies_Table m
INNER JOIN Ratings_Table r USING (moviesID)
WHERE r.IMDb_Score IS NOT NULL
ORDER BY r.IMDb_Score DESC
LIMIT 5;

-- Average IMDb score by each production house
SELECT m.Production_House, AVG(r.IMDb_Score) AS avg_imdb
FROM Movies_Table m
INNER JOIN Ratings_Table r USING (moviesID)  
WHERE r.IMDb_Score IS NOT NULL
GROUP BY m.Production_House
ORDER BY avg_imdb DESC
LIMIT 10;

-- Task 10 (Explain Tool)
--Query 1
SELECT m.Title, r.IMDb_Score
FROM Movies_Table m
JOIN Ratings_Table r USING (moviesID)
ORDER BY r.IMDb_Score DESC
LIMIT 5;

--Query 2
SELECT m.Production_House, AVG(r.IMDb_Score)
FROM Movies_Table m
JOIN Ratings_Table r USING (moviesID)
GROUP BY m.Production_House
ORDER BY AVG(r.IMDb_Score) DESC;

--Query 3
Explain analyze
SELECT m.Title, g.Genre
FROM Movies_Table m
LEFT JOIN Genre_Table g USING (moviesID);

