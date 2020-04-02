# Hotfixes #

**OCTA-20120 - QueryBuilder Does Not Properly Handle Serialize-Name Fields**

Inclusion of the BusinessLogic.Query.QueryBuilder class corrects an issue discovered in 11.7.5/12.1 which prevents the dynamic query builder from properly identifying fields which use a serialize-name, and causes the field name to be used as-is within the resulting query.