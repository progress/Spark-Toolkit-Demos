/***************************************************************************\
*****************************************************************************
**
**     Program: wrcust.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for write of Customer old buffer oldCustomer.

define variable i as integer initial 0.
define variable j as integer initial 0.
define variable k as integer initial 0.

/* Check to see if the user changed the Customer Number */

if Customer.CustNum ne oldCustomer.CustNum then 
do:
    /* If user changed the Customer Number, find related orders and change  */
    /* their customer numbers.                                              */
    for each Order where Order.CustNum eq oldCustomer.CustNum:
        Order.CustNum = Customer.CustNum.
        i = i + 1.
    end.
    if i > 0 then
        message i "orders changed to reflect the new customer number!"
            view-as alert-box information buttons ok.

    /* If user changed the Customer Number, find related invoices and change */
    /* their customer numbers.                                               */
    for each Invoice where Invoice.CustNum eq oldCustomer.CustNum:
        Invoice.CustNum = Customer.CustNum.
        j = j + 1.
    end.
    if j > 0 then
        message j "invoices changed to reflect the new customer number!"
            view-as alert-box information buttons ok.

    /* If user changed the Customer Number, find related ref-call and change */
    /* the customer numbers.                                               */
    for each RefCall where RefCall.CustNum eq oldCustomer.CustNum:
        RefCall.CustNum = Customer.CustNum.
        k = k + 1.
    end.
    if k > 0 then
        message k "reference calls changed to reflect the new customer number!"
            view-as alert-box information buttons ok.
end.
else
do:
    /* Ensure that the Credit Limit value is always Greater than the sum of the outstanding balance. */
    define variable Outstanding as integer initial 0.

    for each Order where Order.CustNum eq Customer.CustNum:
        for each OrderLine where OrderLine.OrderNum eq Order.OrderNum and Order.ShipDate eq ?:
            Outstanding = Outstanding + OrderLine.ExtendedPrice.
        end.
    end.
    for each Invoice where Invoice.CustNum eq oldCustomer.CustNum:
        Outstanding = Outstanding + ( Amount - ( TotalPaid + Adjustment )).
    end.

    if Customer.CreditLimit < Outstanding then 
    do:
        message "This Customer has an outstanding balance of: " Outstanding ". The Credit Limit MUST exceed this amount!"
            view-as alert-box information buttons ok.
        return error.
    end.
end.
