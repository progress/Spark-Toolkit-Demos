<%@ page language="java" 
         contentType="text/html;charset=UTF-8" 
         pageEncoding="UTF-8" 
         session="false"
         isErrorPage="true" 
         trimDirectiveWhitespaces="true"
         errorPage="/WEB-INF/jsp/exceptionPage.jsp"
         import="java.io.*"
         import="java.util.*"
         import="java.system.*" %>

<%-- Java scriptlet to cleanup raw input properties and attributes used as 
      psc.as.attr.xxxxx tokens by the HTML template found in this file. --%>
      
<%-- Import OWASP --%>
<%@ page import="org.owasp.encoder.Encode" %>

<%-- Begin editable JSON response template: --%>

<%@  include file="loadErrorData.jsp" %>{ 
"error_code": <%=request.getAttribute("psc.as.attr.errorCode")%>
, "status_txt": "<%=Encode.forHtml((String)request.getAttribute("psc.as.attr.errorMessage"))%>"

<% if ( (Integer)request.getAttribute("psc.as.attr.detailLevel") > 1) { %> <%-- Add verbose information here --%>
, "error_details": {
  "remote_user": "<%=request.getRemoteUser()%>"
, "user_principal": "<%=request.getUserPrincipal()%>"
, "url_scheme": "<%=request.getScheme()%>"
, "remote_addr": "<%=request.getRemoteAddr()%>"
, "server_name": "<%=request.getServerName()%>"
, "product_type": "<%=request.getAttribute("psc.as.attr.product")%>"
, "http_status": <%=(Integer)request.getAttribute("javax.servlet.error.status_code")%> 
, "error_detail": "<%=request.getAttribute("psc.as.attr.errorDetail")%>"
}
<% }; %> <%-- End of Error Details --%>

<% if ( (Integer)request.getAttribute("psc.as.attr.detailLevel") > 2) { %> <%-- Add more debug information here --%>
, "debug_details": {
  "http_method": "<%=request.getMethod()%>"
, "web_application": "<%=request.getAttribute("psc.as.attr.webApp")%>"
, "transport": "<%=request.getAttribute("psc.as.attr.transport")%>"
, "request_url": "<%=request.getAttribute("psc.as.attr.requrl")%>"
, "path_info": "<%= Encode.forHtml((String)request.getPathInfo())%>"
, "servlet": "<%=(String)request.getAttribute("javax.servlet.error.servlet_name")%>"
, "uri": "<%=(String)request.getAttribute("javax.servlet.error.request_uri")%>"
, "exception_class": "<%=request.getAttribute("psc.as.attr.exceptionName")%>"
, "exception_message": "<%=request.getAttribute("psc.as.attr.exceptionMessage")%>"
, "exception_stack_trace": "<%=request.getAttribute("psc.as.attr.exceptionStack")%>"
}
<% }; %>

}
<%-- End editable JSON response template: --%>

