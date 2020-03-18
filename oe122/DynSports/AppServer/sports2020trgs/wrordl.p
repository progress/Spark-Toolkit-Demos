/***************************************************************************\
*****************************************************************************
**
**     Program: wrordl.p
**    Descript: OrderLine write trigger.
**
*****************************************************************************
\***************************************************************************/

trigger procedure for write of OrderLine.

/* Automatically calculate the Extended Price based on Price, Qty, Discount */

assign OrderLine.ExtendedPrice = Price * Qty * (1 - (Discount / 100)).


/* In some applications you may want to prohibit the change of a record
 * based on the value of some field(s) in that record.  This is an example
 * of what you might do if you want to prevent the change of an order-line
 * record if a ship-date has already been entered for that record.
 */
/*
find first order of orderline no-error.
if available order then do:
   if order.shipdate ne ? then do:
      message "Cannot change an order's detail information when a ship"
              "date has been entered for that order."
              view-as alert-box information buttons ok.
      return error.
   end.
end.
*/
