# OpenEdge Overrides

This directory contains fixes and overrides for use with OpenEdge version 11.7.2 and later:

OpenEdge.Core.Util - Contains an override to the TokenResolver to allow use of the "request.agent" token to get the Agent PID.

OpenEdge.Logging - Contains a fix for picking up changes to the logging.config file; code is from official fix in OE 11.7.3.
