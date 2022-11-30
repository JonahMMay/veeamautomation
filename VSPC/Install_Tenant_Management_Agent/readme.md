# Install_Management_Agent

Installs the VSPC Management Agent on a tenant's VBR server.

# Description

By running this on a VBR server, the VSPC Management Agent can be installed and connected to a VSPC server silently. The script will automatically connect to the VSPC linked to the Cloud Connect server with the most jobs pointed to it. Recommended distribution method is to package the script as an executable using something like PS2EXE.

# Usage

Replace the host name on line 11 with part of the intended url (i.e. *offsitedatasync.com) then run the script on the tenant's VBR server, either as a PS1 file or an executable.


# Related Links

* https://helpcenter.veeam.com/docs/backup/powershell/set-vbrcloudprovider.html
* https://github.com/MScholtes/PS2EXE
