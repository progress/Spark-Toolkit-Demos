/*------------------------------------------------------------------------
    File        : preload.p
    Purpose     : Special application startup, run prior to service load.
    Description :
    Author(s)   : Dustin Grau (dugrau@progress.com)
    Created     : Mon Dec 22 08:25:45 EST 2014
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

&IF KEYWORD-ALL('block-level') EQ 'block-level' &THEN
block-level on error undo, throw.
&ELSEIF KEYWORD-ALL('routine-level') EQ 'routine-level' &THEN
routine-level on error undo, throw.
&ENDIF
&GLOBAL-DEFINE THROW ON ERROR UNDO, THROW

/* ***************************  Main Block  *************************** */
