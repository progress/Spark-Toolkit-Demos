/***************************************************************************\
*****************************************************************************
**
**     Program: delcust.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for delete of Customer.

/* Variable Definitions */

define variable answer as logical.

/* Customer record cannot be deleted if outstanding invoices are found */

find first invoice of customer no-error.
if available invoice then
do:
    if invoice.amount <= invoice.totalpaid + invoice.adjustment then
    do:
        message "Invoice OK, looking for Orders..."
            view-as alert-box information buttons ok.
        find first order of customer no-error.
        if not available order then
        do:
            return.
        end.
        else
        do:
            message "Open orders exist for Customer " customer.custnum ". Cannot delete."
                view-as alert-box information buttons ok.
            return error.
        end.
    end.
    else
    do:
        message "Outstanding unpaid Invoice exists. Cannot Delete"
            view-as alert-box information buttons ok.
        return error.
    end.
end.
else
do:
    find first order of customer no-error.
    if not available order then
    do:
        return.
    end.
    else
    do:
        message "Open orders exist for Customer " customer.custnum ". Cannot delete."
            view-as alert-box information buttons ok.
        return error.
    end.
end.
