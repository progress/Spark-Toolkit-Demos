<%@ page language="java"
         contentType="text/html;charset=UTF-8"
         pageEncoding="UTF-8"
         session="false"
         errorPage="/WEB-INF/jsp/errorPage.jsp"%>
<% // Just redirect to the application login.
    response.sendRedirect(request.getScheme() + "://" +
                          request.getServerName() + ":" +
                          request.getServerPort() +
                          "/ui/static/login.html");
%>
