/***************************************************************************\
*****************************************************************************
**
**     Program: crord.p
**    Descript:
**
*****************************************************************************
\***************************************************************************/

trigger procedure for create of Order.

/* Automatically Increment Order-Number using Next-Ord-Num Sequence */

assign  
    Order.OrderNum    = next-value(NextOrdNum)
    /* Set Order Date to TODAY, Promise Date to 2 weeks from TODAY */
    Order.OrderDate   = today
    Order.PromiseDate = today + 14
    .
