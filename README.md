# Progress Spark Toolkit Demo Projects

### Welcome!

This repository contains sample projects ready for import into PDSOE, meant to illustrate usage of the **Progress Spark Toolkit**. Please note that all demos are for illustrating server-side micro-services only; there are no modifiable UI components bundled as of the October 2025 release (v7.0.0).

**Note:** This release utilizes toolkit release [v7.0.0](https://github.com/progress/Spark-Toolkit/releases/tag/v7.0.0).

## Requirements

**OpenEdge 12.2.19+** or **OpenEdge 12.8.10+** are preferred, with the **Spark.pl** library compiled on your appropriate version (12.2 or 12.8).

**IMPORTANT!** By default each project includes the 12.8 compiled version of the **Spark.pl** library; you MUST copy the appropriate version from the `support/spark/` folder into the project's `AppServer` location!

- Apache Ant 1.9.x+ (included at DLC/ant and run as DLC/bin/proant)
- Progress Compile Tools, or "PCT" (included at DLC/pct/PCT.jar)

## Installation / Setup

Within the `projects` folder are 2 projects which demonstrate a slightly different approach to building an application using the Spark Toolkit:

- **DynSports** - Uses a CatalogManager to dynamically read class and procedure signatures and an ABL-based annotation scheme to describe access to services via the WEB transport.
- **Sports** - Adheres to the standard DataObjectHandler approach which leverages annotated source files and .map files to expose available services via the WEB transport.

Using the **Progress Developer Studio for OpenEdge** simply import the desired project(s) via `File > Import > Existing Projects into Workspace`.

To provide sample data you may use the provided database structure, schema, and table data from `/support/schema/` to create the necessary **Sports2020** and **WebState** databases. To speed up this process on Windows, you can run `ant create` from within that directory to create and load the databases in a `C:\Databases` folder (use the `-Dpath` option to choose an alternate location).

**Note:** For compatibility with the security mechanisms in place within the application, each database must be pre-loaded with the necessary domain data. For each database, use the Data Administration tool to import Domain security via the supplied `_sec-authentication-domain.d` file in each database folder under `/support/schema/`.

**For OpenEdge 12.2 Users:** Please note that the `secprop` utility does not support the `-f` option to merge a properties file, which will result in an incomplete deployment for the OERealm security model. After using the built-in "create" command for creating the PASOE instance, merge the properties from the `AppServer/merge.oeablSecurity.properties` file to the `oeablSecurity.properties` file in the `CATALINA_BASE/webapps/sports/WEB-INF` directory.

## PAS Deployment

Look to the AppServer folder of the respective projects for more information on how to create the PASOE instance for each project. Once created, only source code need be updated within the instance's `ablapps` folder.

## Documentation

Please view the "docs" folder to view various forms of documentation for the available projects, as well as guides for assisting you in building applications with the **Progress Spark Toolkit**.
