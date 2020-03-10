# The Swift Package Index

A conversion of the [SwiftPM Library](https://swiftpm.co) to an open-source implementation in Swift and Vapor.

## Local Development Setup

To run the Swift Package Index server locally, you'll need two local Postgres databases. Install PostgreSQL, create a role, and two databases:

```sql
DROP DATABASE IF EXISTS swiftpackageindex_dev;
DROP DATABASE IF EXISTS swiftpackageindex_test;
DROP ROLE IF EXISTS swiftpackageindex;
CREATE ROLE swiftpackageindex WITH PASSWORD 'mysecretpassword' LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB;
CREATE DATABASE swiftpackageindex_dev WITH OWNER = swiftpackageindex;
CREATE DATABASE swiftpackageindex_test WITH OWNER = swiftpackageindex;
```
