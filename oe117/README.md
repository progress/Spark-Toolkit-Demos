# Framework Demo Projects


## PASOE Projects (Type: ABL Web App)

**DynSports** - Utilizes the new WebHandlers in PASOE-WebSpeed to dynamically route Web transport requests to static Business Entity classes on disk. This project can execute code in 2 ways: either directly (using BE classes in the same project) or remotely (using an APSV connection to a remote server). When using the direct mode, code is dynamically located, reflected, and registered in the MSAgent's session memory, and can then be invoked automatically when requested. When using the remote mode, the ConnectionManager will establish a connection to a remote APSV server, and pass through all requests to that server, executing the necessary code there and returning the appropriate data for the web response.

**Sports** - Demonstrates use of the built-in DataObjectHandler with 11.6.3 and later, combined with available DOH class events to allow for fine-tuning operation. This allows integration of the Spark Toolkit into the application without having to implement the dynamic class reflection and catalog manager. Essentially, all business entities and catalog generation can be done from within PDSOE as available from the product. This project is functionally equivalent to the DynSports project and contains 99% identical code for the front-end application.


## Other Projects

**QuickStart** - Not a project, per-se, but more like an overlay of project properties and extra files to get you started quickly with a new PAS-compatible ABL Web App project. This will provide the necessary PL files for use with Spark, set the PROPATH accordingly, and add the metadata for a defined service called DataObjectService that utilizes a specific WebHandler class for generic class/procedure endpoints.
