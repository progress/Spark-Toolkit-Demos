# Progress Spark Toolkit Demo Projects

Sample projects ready for import to PDSOE and PASOE, to illustrate usage of the **Progress Spark Toolkit**.

Utilizes toolkit release v4.3.0. 


## Requirements

**OpenEdge 11.7.3** or later, as the Spark.pl library is compiled on 11.7.3 and thus highly recommended as the installed version.

- Apache Ant 1.9.x+ (now included with OE 11.7.0 at DLC/ant)
- Progress Compile Tools, or "PCT" (now included with OE 11.7.3 at DLC/pct/PCT.jar)

## Installation / Setup

Utilize the projects from the same folder as your major version of OpenEdge to maintain consistency with the project metadata as expected by **Progress Developer Studio for OpenEdge**. Import the desired project via `File > Import > Existing Projects into Workspace`. Please note that use of the latest service pack for each OpenEdge release is recommended for optimal compatibility.

To provide sample data you may use the provided database structure, schema, and table data from `/support/schema/` to create the necessary Sports2000 and WebState databases. To speed up this process on Windows, you can run `ant create` to create and load the databases in a `C:\Databases` folder (use the `-Dpath` option to choose an alternate location).

**Note:** For compatibility with the security mechanisms in place within the application, each database must be pre-loaded with the necessary domain data. For each database, use the Data Administration tool to import Domain security via the supplied `_sec-authentication-domain.d` file in each database folder under `/support/schema/`.

## PAS Deployment

Each demo is an "ABL Web App" project meant to work within a PAS instance. To make the setup process quick, there is an Ant build script in each project's "AppServer" directory. Simply running `ant create` will create a suitable PAS instance at a predetermined location (C:\PASOE) and automatically include the proper PROPATH entries and files to start the instance.

## Internal Libraries

The demo applications are meant to utilize [JSDO version 5.0.0](https://github.com/progress/JSDO) for managing data against Progress Data Objects. NOTE: This JSDO release changed the promise object to ES6 Promises, which alters the returned parameters. This affects data requests but not callback methods, and may affect any existing projects which utilize the JSDO.
