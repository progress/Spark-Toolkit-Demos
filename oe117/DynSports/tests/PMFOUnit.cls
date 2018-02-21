/*------------------------------------------------------------------------
    File        : PMFOUnit
    Purpose     : Provide basic methods to run ABLUnit against PMFO.
    Syntax      : 
    Description : 
    Author(s)   : dugrau@progress.com
    Created     : Tue May 30 11:47:54 EDT 2017
    Notes       : 
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class tests.PMFOUnit abstract: 

    define protected variable NumDatabases as integer no-undo.

    define protected variable UseProfiler as logical no-undo initial true.

    method protected void StartPMFO ( input pcTestSuiteName as character ):
        define variable oParser    as ObjectModelParser no-undo.
        define variable oConfig    as JsonObject        no-undo.
        define variable oDatabases as JsonObject        no-undo.
        define variable cPath      as character         no-undo.
        define variable cDB        as character extent  no-undo.
        define variable ix         as integer           no-undo.

        this-object:NumDatabases = 0.
        if search("tests/config.json") ne ? then do:
            /* Parse config file when found. */
            assign oParser = new Progress.Json.ObjectModel.ObjectModelParser().
            assign oConfig = cast(oParser:ParseFile(search("tests/config.json")), JsonObject) no-error.
            delete object oParser no-error.

            /* Isolate current working directory. */
            assign cPath = replace(search("tests/config.json"), "~\", "~/").
            assign cPath = substring(cPath, 1, length(cPath) - 11).
        end. /* config.json */
        else
            assign cPath = replace(session:temp-directory, "~\", "~/").

        if valid-object(oConfig) and oConfig:Has("Databases") and
           oConfig:GetType("Databases") eq JsonDataType:object then do:
            /* Assign databases to be used via the config object. */
            assign oDatabases = oConfig:GetJsonObject("Databases") no-error.
        end.

        if valid-object(oDatabases) then do:
            /* Connect to standard databases, similar to -pf option in agentStartupParam. */
            assign cDB = oDatabases:GetNames().
            this-object:NumDatabases = extent(cDB).
            do ix = 1 to NumDatabases:
                if not connected(cDB[ix]) then
                    connect value(cDB[ix]) value(oDatabases:GetCharacter(cDB[ix])) no-error.
            end. /* do ix */
        end. /* valid-object(oDatabases) */

        if this-object:NumDatabases eq 0 then
            OpenEdge.Core.Assert:RaiseError("No databases configured for testing.").

        /* Run standard "sessionStartupProc". */
        define variable cStartup as character no-undo. /* sessionStartupProcParam */
        run Spark/startup.p (input cStartup).

        if UseProfiler then do:
            define variable cListDir as character no-undo.
            assign cListDir = substitute("&1/listing/", right-trim(cPath, "~/")).
            os-create-dir value(cListDir).

            assign /* Note: Order matters here, do not rearrange! */
                profiler:enabled      = true
                profiler:profiling    = true
                profiler:file-name    = substitute("&1/output_&2.prof", right-trim(cPath, "~/"), pcTestSuiteName)
                profiler:description  = "PMFO ABLUnit Output"
                profiler:listings     = true /* Note: Requires source code. */
                profiler:directory    = cListDir
                profiler:trace-filter = "*":u
                profiler:tracing      = "":u
                profiler:coverage     = true
                profiler:statistics   = true
                .
        end. /* UseProfiler */

        catch err as Progress.Lang.Error:
    		OpenEdge.Core.Assert:RaiseError(err:GetMessage(1)).
        end catch.
        finally:
            delete object oConfig no-error.
            delete object oDatabases no-error.
        end finally.
    end method. /* StartPMFO */

    method protected void StopPMFO ( ):
        /* Run standard "sessionShutdownProc". */
        run Spark/shutdown.p.

        if profiler:enabled then do:
            /* Turn off the profiler, if enabled. */
            assign
                profiler:profiling = false
                profiler:enabled   = false
                .

            /* Make sure you actually WRITE the data out. */
            profiler:write-data().
        end. /* profiler:enabled */

        catch err as Progress.Lang.Error:
            OpenEdge.Core.Assert:RaiseError(err:GetMessage(1)).
        end catch.
    end method. /* StopPMFO */

    method protected logical HasManagerInterface ( ):
        define variable oManager as Progress.Lang.Class no-undo.

        assign oManager = Progress.Lang.Class:GetClass("Ccs.Common.IManager") no-error.

        return valid-object(oManager).
    end method. /* HasManagerInterface */

    method protected Progress.Lang.Object GetManager ( input pcClassInterface as character ):
        define variable oInterface as Progress.Lang.Class  no-undo.
        define variable oManager   as Progress.Lang.Object no-undo.

        assign oInterface = Progress.Lang.Class:GetClass(pcClassInterface) no-error.
        if valid-object(oInterface) then do:
            assign oManager = Ccs.Common.Application:StartupManager:getManager(oInterface) no-error.
        end.
        else
            OpenEdge.Core.Assert:RaiseError(substitute("Class interface unavailable: &1", pcClassInterface)).

        return oManager.
    end method. /* GetManager */

end class.