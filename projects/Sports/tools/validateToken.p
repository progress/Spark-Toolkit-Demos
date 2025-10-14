/*------------------------------------------------------------------------
    File        : validateToken.p
    Purpose     : 
    Description : 
    Author(s)   : Dustin Grau
    Created     : Tue Oct 14 17:10:43 EDT 2025
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

block-level on error undo, throw.

&global-define BaseName SparkRealm
&global-define PassCodeValue sp4rkR3alm

/* ***************************  Main Block  *************************** */

var character cFilename = "Deploy/Conf/Realm/{&BaseName}.cp".
var handle oPrincipal.
var memptr mCP.
var raw rCP.

create client-principal oPrincipal.

assign cFilename = search(cFilename).
file-info:file-name = cFileName.
if file-info:full-pathname ne ? then do:
    copy-lob from file file-info:full-pathname to mCP.

    if get-size(mCP) gt 0 then do:
        put-bytes(rCP, 1) = mCP.
        oPrincipal:import-principal(rCP).
    end.
    else
        message "CP Token file is empty.".

    if valid-object(oPrincipal) then do:
        message "Token Seal Valid:" oPrincipal:validate-seal("{&PassCodeValue}").
    end.
end.
else
    message "Cannot find CP Token file.".
