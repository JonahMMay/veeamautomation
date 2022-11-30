# CreateResources
 
 Creates a Cloud Director Organization, Virtual Data Center, Edge Gateway, and Networks.

## Description

This script takes a combination of user input and preset variables to generate VMware Cloud Director resources.

The script was created as a stopgap while this functionality was added to a web portal for scripted and automated DR as a VCSP. Certain functionality, such as using non-default storage policies, may not be needed. 

## Usage

All preset modifications take place below line 249. Use Write-Host to give multiple VCD server instances if there are multiple you need to access. Underneath, add as many switch cases with the following variables initialized:

* $VCDServer - the URL of the VCD server
* $pVDCName - the name of the Provider VDC
* $netPoolName - the name of the network pool that will be used for the new resources
* $sPolicyName - the storage policy to override the default with
* $IRPolicyName - the storage policy containing the VeeamBackup NFS datastore (for Veeam Instant VM Recovery)
* $defSPolicyName - the default storage policy (to remove from VDC after creation)
* $EGNetwork - the external network to use for the Edge Gateway
* $EGgateway - the gateway of the network being used for Edge Gateway's external network
* $EGSubnet - the subnet mask of the Edge Gateway's external network
* $EGIP - the first three octets of the Edge Gateway's external IP
* $octetMin - the min value of the Edge Gateway external IP's final octet (inclusive)
* $octetMax - the max value of the Edge Gateway external IP's final octet (inclusive)


Once these values are populated, the script can be ran. While executing, it will prompt the user for information such as the Organization name, the number of networks to add to the VDC, and the Cloud Director instance to connect to.

## Related Links

* https://www.powershellgallery.com/packages/VMware-vCD-Module/1.2.3/Content/functions%5CNew-MyEdgeGateway.psm1
* https://blog.tyang.org/2010/09/16/powershell-function-validate-subnet-mask/
