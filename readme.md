# Database Schema Change Management With liquibase using buildkite pipeline

## Pipeline steps
1. Chekout the source code repository.
2. Prompt:For Datasource to interact.
3. Take Database backup.
4. Dry run to check the database schema changes using liquibase.
5. Prompt:For user confirmation to run schema changes to database.
6. Run Schema Changes to selected database.

## liquibase Changelogfile and changeset
1. Liquibase supports changelogfile formats in SQL,XML,JSON,YAML
2. Our case will be using SQL formats
3. All changes to database schema will be recorded in the changelogfile.
4. Each realease will be considered as a single changeset, consisting of author_name and a unique id.

## Changeset Observation
Liquibase
VALIDATION OF ENTIRE CHANGELOG WILL BE DONE FIRST  
--lock Database  
**Case 1:** what will happen if Change the Id 
	a. Swap ChangeSet ID: 
		Will result in Check sum validation error because the generated checksum during validation is compared with swaped id from the databasechangelog table
	b. Assigin a new ID to ChangeSet :
		Will result in Add new enrty to databasechangelog table in updatesql , During actual Update to schema will result in duplicate entry or error depending on SQL statement will it contains primary key.
		
**Case 2:** How can we retain the last 10 id
	We can remove the changeset from changelog , but persistent entry will be there in databasechangelog table , As per observation updatesql and update action did not throw any error

**Case 3:** If I have removed the entry for particular changeset in databasechangelog table and in changelog file
	New entry wrt the details for  databasechangelog table will be made and There Will Be Change in ORDER OF EXECUTION  
--Release Lock Database

## liquibase commands used
1. Updatesql
    
2. Update