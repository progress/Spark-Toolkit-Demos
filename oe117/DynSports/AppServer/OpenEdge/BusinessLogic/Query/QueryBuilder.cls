/* *************************************************************************************************************************
Copyright (c) 2019 by Progress Software Corporation and/or one of its subsidiaries or affiliates. All rights reserved.
************************************************************************************************************************** */
/*------------------------------------------------------------------------
    File        : QueryBuilder
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : pjudge
    Created     : Thu May 10 12:38:00 EDT 2018
    Notes       : ADAS-101
  ----------------------------------------------------------------------*/
block-level on error undo, throw.

using Ccs.BusinessLogic.IGetDataRequest.

class OpenEdge.BusinessLogic.Query.QueryBuilder: 
    
    /* Builds a query handle (object) from a IGetDataRequest object. This method maps
       the input names to the input handle's SERIALIZE-NAMEs and uses the 'real'
       names to build the where clause
       
       @param IGetDataRequest A valid queryn definition
       @param handle a Dataset or buffer (TT or DB) handle 
       @return handle A valid QUERY handle */
    method public handle BuildQuery(input pFilter as IGetDataRequest,
                                    input pSchema as handle):
    end method.
    
    /* Builds a query string from a IGetDataRequest object. This method does
       no name conversions - just takes the names from the input object.
       
       @param IGetDataRequest A valid queryn definition
       @return character A complete WHERE clause , with no name conversions */
    method public character BuildQueryString(input pFilter as IGetDataRequest):
        return BuildQueryString(pFilter, ?).
    end method.
    
    /* Builds a query string from a IGetDataRequest object. This method maps
       the input names to the input handle's SERIALIZE-NAMEs and uses the 'real'
       names to build the where clause
       
       @param IGetDataRequest A valid queryn definition
       @param handle a Dataset or buffer (TT or DB) handle 
       @return character A complete WHERE clause */
    method public character BuildQueryString(input pFilter as IGetDataRequest,
                                             input pSchema as handle):
        define variable queryString as character no-undo.
        
        queryString = "WHERE TRUE".
        
        /**
        pSchema:get-buffer-handle(1).
        
        do i - 1 to num-fields:
              //SERIALIZE-NAME= pFilter:TableRequests[1]:QueryDefinition:QuerySelection:FieldName
              //pFilter:TableRequests[1]:QueryDefinition:QuerySelection
              find query-entry where
                query-entry:name eq buffer-field:serialize-name.
              
              //pFilter:TableRequests[1]:QueryDefinition:QuerySort
              find query-sort where      
                query-entry:name eq buffer-field:serialize-name.
               :buffer-field(
                ).
        **/
        
        return queryString.
    end method.
    
end class.