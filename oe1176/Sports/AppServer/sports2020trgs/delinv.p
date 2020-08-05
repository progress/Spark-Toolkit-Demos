/***************************************************************************\
*****************************************************************************
**
**     Program: delinv.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for delete of Invoice.

/* Invoices cannot be deleted if the Invoice amount exceeds Total-Paid + Adjustment */

if Invoice.Amount > (Invoice.TotalPaid + Invoice.Adjustment) then
do:
    message "The Invoice Amount cannot be greater than Total Paid + Adjustment"
        view-as alert-box information buttons ok.
    return error.
end.
