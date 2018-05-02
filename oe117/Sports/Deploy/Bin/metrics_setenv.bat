@echo off

rem Set the name of the ABLApp which you want to monitor.
set ABLAPP_NAME=SportsDemo

rem Set the URL of the server where we can reach the OEManager webapp.
set INSTANCE_URI=http://localhost:8830

rem Set the name of the config file to use at runtime.
set METRICS_CONFIG=metrics.json

exit /b 0
