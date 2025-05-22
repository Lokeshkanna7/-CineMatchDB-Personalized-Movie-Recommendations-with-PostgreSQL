# 🎬 CineMatchDB: Personalized Movie Recommendations with PostgreSQL

CineMatchDB is a dynamic, database-driven recommendation system built using PostgreSQL and Netflix's 2021 dataset. The project demonstrates the design of a fully normalized schema, optimized queries, and indexing strategies for real-time content-based recommendations.

## 🚀 Project Overview

In this project, we:
- Designed a relational schema from scratch using BCNF principles
- Built optimized queries for top-rated, genre-specific, and actor-based recommendations
- Improved query execution using indexing strategies
- Developed a prototype Streamlit app for movie suggestion demos

## 🧱 Schema Highlights

- Fully normalized to BCNF
- Key tables: `Movies`, `Ratings`, `Genre`, `Person`, `MovieActor`, `MovieWriter`
- Composite & foreign key usage ensures data integrity

## 🛠️ Key Features

- **Advanced Querying:** JOINs, aggregation, filtering
- **Index Optimization:** Improved execution using B-tree and composite indexes
- **Streamlit Demo:** Locally hosted movie recommendation interface
- **Data Cleaning:** Type safety, range checks, and runtime normalization

## 📂 Dataset

- [Netflix Dataset (2021) on Kaggle](https://www.kaggle.com/datasets/syedmubarak/netflix-dataset-latest-2021)

