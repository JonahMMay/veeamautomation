# SSL_Replace

Replaces the SSL certificate used by the cloud gateways with another one located in the certificate store.

# Description

Replaces the SSL certificate used by the Cloud Connect server with the latest issued certificate matching a specified subject name.

# Usage

Replace the CN in line 3 with the CN name of the server. The newest issued certificate will automatically be used.


# Related Links
* https://helpcenter.veeam.com/docs/backup/powershell/add-vbrcloudgatewaycertificate.html?ver=110
* https://learn.microsoft.com/en-us/powershell/module/pki/import-pfxcertificate?view=windowsserver2022-ps
