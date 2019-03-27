This directory is meant to retain options that are required for deployment of your project to
a PAS instance. Note that CATALINA_BASE is your PAS server instance's directory.

THESE SHOULD BE DEPLOYED BEFORE THE FIRST START OF YOUR PAS INSTANCE!

Conf/ - Primary configuration directory for Spark toolkit services.
        Files in this directory should be copied to CATALINA_BASE/conf/spark by default.
Conf/Realm - Specific configuration options for use with OERealm security.
             The SparkRealm.cp should be copied to CATALINA_BASE/common/lib (per Tomcat rules)
             The SparkRealm.json should be copied to CATALINA_BASE/conf or CATALINA_BASE/conf/spark

Within the "Conf" directory, be sure to read the accompanying README files for any customizations!

If you wish to provide a different configuration directory than /spark for your PAS instance, the
framework supports use of session startup procedure parameters in the form of a JSON object, with
a property of "ConfigDir" set to the name of your specific subdirectory under the /conf folder.
For example, this option will utilize /conf/DynSports instead:
    sessionStartupProcParam={"ConfigDir": "DynSports"}

Note: Build/ Contains management scripts for start/stop/restart actions. Used primarily by PDSOE.

/*********************************************************************************************/

To add the necessary components for the Progress Modernization Framework for OpenEdge (Spark),
copy the files in the project /AppServer directory to your CATALINA_BASE/openedge folder. This
is a default, shared location among all of your webapps that will be deployed to this instance.
Files that may be included with this folder include:
    startup.pf - A simple parameter file for database options and extra configuration options.
    Ccs.pl - A procedure library that contains the Common Component Specification interfaces.
    Spark.pl - A procedure library that contains all default Spark classes (default framework).


As an example for quick-merging properties within a PAS environment, you can use the file
"merge.openedge.properties" and the following command to merge into the PAS instance:

    CATALINA_BASE\bin\oeprop -f CATALINA_BASE\openedge\merge.openedge.properties


/*********************************************************************************************/

Additionally, the following values may be useful to modify within your PASOE instance:

bin/openedge_setenv.bat (add below other JAVA_OPTS options):

    rem set network to ipv4 only
    set _oeopts=%_oeopts% -Djava.net.preferIPv4Stack=true


conf/catalina.properties (adjust list of compressible file types):

    psc.as.compress.min=128
    psc.as.compress.types=text/html,text/xml,text/javascript,text/css,application/json,application/javascript


conf/logging-tomcat.properties (supports additional tokens):

    psc.as.logging.access.pattern=%h %reqAttribute{OEReq.userId} [%date{"yyyy-MM-dd'T'HH:mm:ss.SSSXXX"}] "%r" %s %b %D %I %S %reqAttribute{OEReq.requestId} %n
