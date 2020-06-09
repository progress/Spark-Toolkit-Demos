/***************************************************************************\
*****************************************************************************
**
**     Program: delsuppl.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for delete of Supplier.

find first purchaseorder of supplier where postatus ne "Received" no-lock no-error.

if avail purchaseorder then 
do:
    message "Supplier can not be deleted." "There is at least one PO that has not been received."
        view-as alert-box error buttons ok.
    return error.
end.

else 
do:
    /* delete received po */

    for each purchaseorder of Supplier:
        for each poline of purchaseorder:
            delete poline.
        end. /*for each poline*/

        delete purchaseorder.
    end. /*for each purchaseorder of supplier*/

end. /*else do*/
