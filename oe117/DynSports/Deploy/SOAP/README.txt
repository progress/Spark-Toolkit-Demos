Use the following steps to generate the new WSM/WSDL files for SOAP deployment:

1. Open the Proxy Generator. 
2. Choose File -> New from the menu. 
3. On the AppObject tab enter a name (example: â€œWSTest"). 
4. Click on the "New" button next to the "Propath Components" section. 
5. Choose the directory where your AppServer application R-code is located. 
6. Choose Procedure -> Add -> Non-persistent from the menu. 
7. Add your procedural interfaces from the compiled R-code (*.r)
8. Choose File / Generate from the menu. 
9. In the General tab select "Web Servicesâ€� as the Client Type. 
10. Uncheck the "Use Default" option and enter the name of your AppServer in the "AppService" field. 
11. Look at the Client Details tab.
12. Enter a Namespace for your Web Service (eg. "urn:MyTest"). 
13. You may leave the default example as the "URL for the WSA". 
14. Choose "Free" for the Session Model (denotes Session-free). 
15. Choose "Document/Literalâ€� (aka. â€œDoc/Literalâ€�) in the WSDL Style box. 
16. Set the directory where you want the WSM to be output via the "Output Directory" selector.
17. Click on "OK" to generate the WSM and WSDL files.
18. Copy any previously-selected *.r files to a location in your PAS instance's PROPATH
19. Note the path and name of your generated .wsm file to be used in deployment.


Deploy to the "sports" WebApp by using the following command from within CATALINA_BASE/bin/
	deploySOAP.bat [path-to-file/]WSTest.wsm sports


Access the SOAP transport to view available URN's:
	http://${psc.as.host.name}:${psc.as.http.port}/soap


Testing the SOAP Endpoints

Accessing that URL should produce output as follows which should list your new service:
    {"AdapterType":"SOAP","Enabled":true,"Services":[{"Name":"<object_name>","Namespace":"<namespace>"}]}

The WSDL should be available at the following URL, should you wish to use SOAPUI for testing:
    http://<host_name>:<port>/soap/wsdl?targetURI=<namespace>

The utility DLC/bin/bprowsdldoc can be used to generate sample ABL code against your WSDL document to confirm availability of expected endpoints.
    bprowsdldoc http://<host_name>:<port>/soap/wsdl?targetURI=<namespace>
