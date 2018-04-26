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

class Spark.Core.Util.Logger abstract: 

    define protected property oLogger as ILogWriter
        get():
            if not valid-object(this-object:oLogger) then
                assign this-object:oLogger = LoggerBuilder:GetLogger(this-object:getClass()).
            return this-object:oLogger.
        end get.
        private set.

end class.