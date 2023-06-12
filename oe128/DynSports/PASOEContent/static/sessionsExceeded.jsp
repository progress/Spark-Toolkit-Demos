<%@ page language="java" 
         contentType="text/html;charset=UTF-8" 
         pageEncoding="UTF-8" 
         session="false"
         isErrorPage="true" 
         trimDirectiveWhitespaces="true"
%>
<%@ taglib prefix="sec" uri="/WEB-INF/security.tld" %>
<html>
<head>
<title>Progress Application Server Error</title>
<link rel="stylesheet" type="text/css" href="<%= request.getContextPath()%>/static/commonStyle.css" media="screen" />
<meta http-equiv="Cache-Control" content="no-store" />
</head>
<body>

<%@  include file="../WEB-INF/jsp/errorPageHeader.jsp" %>
This session has been expired (possibly due to multiple concurrent logins being attempted as the same user).
<% response.setStatus(401); %>
<%@  include file="../WEB-INF/jsp/errorPageFooter.jsp" %>
</body>
</html>
