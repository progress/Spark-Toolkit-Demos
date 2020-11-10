/*------------------------------------------------------------------------
    File        : TableTest
    Purpose     : Test harness for database table examples
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Mon Nov 9 10:48:07 EDT 2020
    Notes       :
  ----------------------------------------------------------------------*/

using Progress.Lang.* from propath.
using Progress.Json.ObjectModel.* from propath.

block-level on error undo, throw.

class Business.UnitTest.TableTest inherits Spark.Core.Service.DynamicResource:

    define public override property serviceURI as character
        initial "/web/api/tests" no-undo get.
        protected set.

    define public override property resourceName as character
        initial "table" no-undo get.
        protected set.

    method public override void initialize ( ):
        /* Describe any properties about invoke methods to be exposed. */
        Spark.Core.Util.Annotate:describeInvoke(serviceURI, getClassName(), "lockTable", "lock", "put").
    end method. /* initialize */

    method public void lockTable ( input  busyTime as integer,
                                   output elapsed  as integer ):
        /* If no time specified then default to 1000 milliseconds. */
        if busyTime eq ? then assign busyTime = 1000.

        if busyTime lt 0 then /* Throw an error if the provided value is negative; SEE allows changing of the response code. */
            undo, throw new OpenEdge.Web.SendExceptionError(OpenEdge.Net.HTTP.StatusCodeEnum:BadRequest,
                                                            "Busy Time parameter cannot be less than zero.").

        /* Execute a pause for some period to imitate long-running code. */
        define variable dStart as datetime no-undo.

        assign dStart = now.
        for first Customer exclusive-lock:
            pause (busyTime / 1000) no-message.
        end.

        finally:
            /* Confirm that execution paused for the time stated. */
            assign elapsed = interval(now, dStart, "milliseconds").
        end finally.
    end method. /* lockTable */

end class.