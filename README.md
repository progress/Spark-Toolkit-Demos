# Spark Demo Projects

Release-based projects ready for import to illustrate usage of the Progress Modernization Framework for OpenEdge.


## Installation / Setup

Utilize the projects from the same folder as your major version of OpenEdge to maintain consistency with the project metadata as expected by **Progress Developer Studio**. Import the desired project via `File > Import > Existing Projects into Workspace`. Please note that use of the latest service pack is recommended for optimal compatibility.

Each demo is an "ABL Web App" project meant to work within a PAS instance. To make the setup process quick, there is an Ant build script in each project's "AppServer" directory. Simply running "`ant create`" will create a suitable PAS instance at a predetermined location (C:\PASOE) and automatically include the proper PROPATH entries and files to start the instance.
