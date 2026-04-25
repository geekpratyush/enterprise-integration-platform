-- setup-db.sql
CREATE DATABASE eip_db;
GO

-- Create Application User

USE master;
GO
CREATE LOGIN eip_user WITH PASSWORD = 'Password123!';
GO

USE eip_db;
GO
CREATE USER eip_user FOR LOGIN eip_user;
GO
ALTER ROLE db_owner ADD MEMBER eip_user;
GO
