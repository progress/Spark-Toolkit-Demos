/* *************************************************************************************************************************
Copyright (c) 2017 by Progress Software Corporation and/or one of its subsidiaries or affiliates. All rights reserved.
************************************************************************************************************************** */
 /*------------------------------------------------------------------------
    File        : ServiceOptions
    Purpose     : A set of service-level options
    Syntax      : 
    Description : 
    Author(s)   : dgrau
    Created     : 2019-12-09
    Notes       : 
  ----------------------------------------------------------------------*/
block-level on error undo, throw.

class Spark.Core.Handler.ServiceOptions inherits OpenEdge.Web.DataObject.ServiceOptions:

    /* Prefix for service URI, if applicable [Transport + / + Prefix] */
    define public property PrefixURI as character no-undo get. set.

    /* Default constructor */
    constructor public ServiceOptions():
        super().
    end constructor. 
    
end class.