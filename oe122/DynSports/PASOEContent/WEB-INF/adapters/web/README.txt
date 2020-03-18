#########################################################

The "web" folder will have the WebHandler definition for each Service. For example, if we are going
to create a WebHandler for the service named "SportsSvc" then a folder named "SportsSvc" should
be created and inside that we should place the  webhandlers mapping file.


The handler configuration should be a JSON Object where each handler definition is a string
inside the JSON Object with the below format.

    "<handler URI>: handler class name"


For ROOT WebApp, ROOT.handlers should be placed inside the "ROOT" folder with no service name
in the handlers file.

Here is an example of a handlers file

{
  "version": "2.0",
  "serviceName": "PingService",
  "handlers": [
    {
      "\/_oeping: OpenEdge.Web.PingWebHandler",
      "\/pdo\/{service}: OpenEdge.Web.DataObject.DataObjectHandler"
    }
  ]
}

The URL to access the service should be in the format of /web/<ServiceName>/<ServiceURI>
So, for the above example it would be - /web/PingService/_oeping



