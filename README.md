# Progress Spark Toolkit Demo Projects

### Welcome!

This repository contains sample projects ready for import into PDSOE and PASOE, meant to illustrate usage of the **Progress Spark Toolkit**. Please note that all demos are for illustrating server-side micro-services only; there are no UI components bundled as of the June 2020 release (v6.0.0).

**Note:** This release utilizes toolkit release [v6.0.0](https://github.com/progress/Spark-Toolkit/releases/tag/v6.0.0).

## Requirements

**OpenEdge 11.7.5** or **OpenEdge 12.1.** at minimum, **OpenEdge 11.7.6** or **OpenEdge 12.2.** preferred, with the **Spark.pl** library compiled on your appropriate version (11 or 12).

- Apache Ant 1.9.x+ (included as of OE 11.7+ at DLC/ant and run as DLC/bin/proant)
- Progress Compile Tools, or "PCT" (included as of OE 11.7.3 at DLC/pct/PCT.jar)

## Installation / Setup

Utilize the projects from the same folder as your major version of OpenEdge to maintain consistency with the project metadata as expected by **Progress Developer Studio for OpenEdge**. Import the desired project via `File > Import > Existing Projects into Workspace`.

To provide sample data you may use the provided database structure, schema, and table data from `/support/schema/` to create the necessary **Sports2020** and **WebState** databases. To speed up this process on Windows, you can run `ant create` to create and load the databases in a `C:\Databases` folder (use the `-Dpath` option to choose an alternate location).

**Note:** For compatibility with the security mechanisms in place within the application, each database must be pre-loaded with the necessary domain data. For each database, use the Data Administration tool to import Domain security via the supplied `_sec-authentication-domain.d` file in each database folder under `/support/schema/`. Note that the correct authentication domain file must agree with the version of OpenEdge as security passcode hashes changed between versions 11 and 12.

## PAS Deployment

Each demo is an "ABL Web App" project meant to work within a PAS instance. To make the setup process quick, there is an Ant build script in each project's "AppServer" directory. Simply running `ant create` will create a suitable PAS instance at a predetermined location (C:\PASOE) and automatically include the proper PROPATH entries and files to start the instance.


## Documentation

Please view the "docs" folder to view various forms of documentation for the available projects, as well as guides for assisting you in building applications with the Progress Spark Toolkit.
