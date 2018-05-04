/*------------------------------------------------------------------------
    File        : Logger
    Purpose     : 
    Description : 
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Thu Apr 26 13:30:07 EDT 2018
    Notes       : 
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using OpenEdge.Logging.* from propath.

block-level on error undo, throw.

class Spark.Diagnostic.Util.Logger abstract: 

    define protected property oLogger as ILogWriter no-undo
        get():
            /* Create single logger instance for this class. */
            if not valid-object(oLogger) then do:
                message substitute("Creating Logger for &1", this-object:getClass():TypeName).
                assign oLogger = LoggerBuilder:GetLogger(this-object:getClass()).
            end.
            return oLogger.
        end get.
        private set.

end class.