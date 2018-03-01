THIS IS NOT A PROJECT!

This is a project overlay, meant to get you up and running quickly with the Spark libraries as part of the
Progress Modernization Framework. To utilize this jump-start, start by creating an ABL Web App project via
PDSOE as you normally would: providing a suitable name, choosing your deployment option, and accepting the
default WebHandler service. Once you have completed the standard project wizard, copy the contents of this
directory on top of your new project, accepting any alerts to overwrite existing files. Once the files are
in place you may delete your default WebHandler class and service created as part of the wizard process.

The resulting project additions will set up a new Spark DataObjectService for you, pointing to the standard
WebHandler class Spark.Core.Handler.DataObjectHandler and using a Resource URI of /api for all requests.
You will also be given some modified implementations of oeablSecurity.* files which contain the necessary
options for for anonymous, form-local, and form-oerealm support. These will all use a default "spark" domain
(to be added to your target databases) along with a specific passphrase "spark01". Instructions for changes
to this domain, associated SparkReset.cp and any encoded passwords may be found in the various README files
under Deploy/Conf in your new project.

To immediately create a compatible PAS instance, start a command prompt as Administrator, change directory
to your project's AppServer directory, and run "ant" from the command line. This will give sample usage
instructions for using the script to generate a new PAS instance. If desired, adjust the parameters as
necessary, and it will create and tailor an instance for use with your new Spark-based project.