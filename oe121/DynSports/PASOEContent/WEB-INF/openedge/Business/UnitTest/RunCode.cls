/*------------------------------------------------------------------------
    File        : RunCode
    Purpose     : Test harness for runtime code examples
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Mon Aug 6 10:48:07 EDT 2019
    Notes       :
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class Business.UnitTest.RunCode inherits Spark.Core.Service.DynamicResource:

    define public override property serviceURI as character
        initial "/web/api/tests" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "runcode" no-undo get.
        protected set.

    method public override void initialize ( ):
        /* Describe any properties about invoke methods to be exposed. */
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "lookBusy", "busy", "put").
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "stopCode", "stop", "get").
    end method. /* initialize */

    method public void lookBusy ( input  busyTime as integer,
                                  output elapsed  as integer ):
        /* If no time specified then default to 1000 milliseconds. */
        if busyTime eq ? then assign busyTime = 1000.

        if busyTime lt 0 then /* Throw an error if the provided value is negative; SEE allows changing of the response code. */
            undo, throw new OpenEdge.Web.SendExceptionError(OpenEdge.Net.HTTP.StatusCodeEnum:BadRequest,
                                                            "Busy Time parameter cannot be less than zero.").

        /* Run a wait loop for some period to imitate long-running code. */
        define variable iStart as datetime no-undo.
        assign iStart = now.
        pause (busyTime / 1000) no-message.

        finally:
            /* Confirm that execution paused for the time stated. */
            assign elapsed = interval(now, iStart, "milliseconds").
        end finally.
    end method. /* lookBusy */

    method public void stopCode ( output completed as logical ):
        stop. /* Trigger a stop condition for this code. */

        finally:
            assign completed = true. /* This really should't return with a STOP. */
        end finally.
    end method. /* lookBusy */

end class.