# VSPC_Inactive_Resources

Queries VSPC for all tenants with a state other than "Active" and returns related backup and replica resources usage information.

# Description

This script queries the VSPC REST APIs to collect information on backup and replica resources connected to inactive tenants. Useful for finding orphaned resources that can be deleted.

# Usage

Replace the token on line 27 with a valid API key and the base URL on line 33 with the VSPC server name.


# Related Links

* https://helpcenter.veeam.com/docs/vac/rest/reference/vspc-rest.html?ver=60
