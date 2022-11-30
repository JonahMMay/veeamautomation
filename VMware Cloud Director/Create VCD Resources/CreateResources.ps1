Set-ExecutionPolicy Bypass -Scope Process -Force

Function New-MyEdgeGateway {
<#
.SYNOPSIS
    Creates a new Edge Gateway with Default Parameters

.DESCRIPTION
    Creates a new Edge Gateway with Default Parameters

    Default Parameters are:
    * Size
    * HA State
    * DNS Relay


.NOTES
    File Name  : New-MyEdgeGateway.ps1
    Author     : Markus Kraus
    Version    : 1.0
    State      : Ready

.LINK
    https://mycloudrevolution.com/

.EXAMPLE
    New-MyEdgeGateway -Name "TestEdge" -OrgVDCName "TestVDC" -OrgName "TestOrg" -ExternalNetwork "ExternalNetwork" -IPAddress "192.168.100.1" -SubnetMask "255.255.255.0" -Gateway "192.168.100.254" -IPRangeStart ""192.168.100.2" -IPRangeEnd ""192.168.100.3" -Verbose

.PARAMETER Name
    Name of the New Edge Gateway as String

.PARAMETER OrgVDCName
    OrgVDC where the new Edge Gateway should be created as string

.PARAMETER OrgName
    Org where the new Edge Gateway should be created as string

.PARAMETER ExternalNetwork
     External Network of the new Edge Gateway as String

.PARAMETER IPAddress
     IP Address of the New Edge Gateway as IP Address

.PARAMETER SubnetMask
     Subnet Mask of the New Edge Gateway as IP Address

.PARAMETER Gateway
     Gateway of the New Edge Gateway as IP Address

.PARAMETER IPRangeStart
     Sub Allocation IP Range Start of the New Edge Gateway as IP Address

.PARAMETER IPRangeEnd
     Sub Allocation IP Range End of the New Edge Gateway as IP Address

.PARAMETER Timeout
    Timeout for the Edge Gateway to get Ready

    Default: 120s

#>
    Param (
        [Parameter(Mandatory=$True, ValueFromPipeline=$False, HelpMessage="Name of the New Edge Gateway as String")]
        [ValidateNotNullorEmpty()]
            [String] $Name,
        [Parameter(Mandatory=$True, ValueFromPipeline=$False, HelpMessage="OrgVDC where the new Edge Gateway should be created as string")]
        [ValidateNotNullorEmpty()]
            [String] $OrgVdcName,
        [Parameter(Mandatory=$True, ValueFromPipeline=$False, HelpMessage="Org where the new Edge Gateway should be created as string")]
        [ValidateNotNullorEmpty()]
            [String] $OrgName,
        [Parameter(Mandatory=$True, ValueFromPipeline=$False, HelpMessage="External Network of the New Edge Gateway as String")]
        [ValidateNotNullorEmpty()]
            [String] $ExternalNetwork,
        [Parameter(Mandatory=$True, ValueFromPipeline=$False, HelpMessage="IP Address of the New Edge Gateway as IP Address")]
        [ValidateNotNullorEmpty()]
            [IPAddress] $IPAddress,
        [Parameter(Mandatory=$True, ValueFromPipeline=$False, HelpMessage="Subnet Mask of the New Edge Gateway as IP Address")]
        [ValidateNotNullorEmpty()]
            [IPAddress] $SubnetMask,
        [Parameter(Mandatory=$True, ValueFromPipeline=$False, HelpMessage="Gateway of the New Edge Gateway as IP Address")]
        [ValidateNotNullorEmpty()]
            [IPAddress] $Gateway,
        [Parameter(Mandatory=$False, ValueFromPipeline=$False, HelpMessage="Sub Allocation IP Range Start the New Edge Gateway as IP Address")]
            [IPAddress] $IPRangeStart,
        [Parameter(Mandatory=$False, ValueFromPipeline=$False, HelpMessage="Sub Allocation IP Range End the New Edge Gateway as IP Address")]
            [IPAddress] $IPRangeEnd,
        [Parameter(Mandatory=$False, ValueFromPipeline=$False,HelpMessage="Timeout for the Edge Gateway to get Ready")]
        [ValidateNotNullorEmpty()]
            [int] $Timeout = 120
    )
    Process {

    ## Get Org vDC
    Write-Verbose "Get Org vDC"
    [Array] $orgVdc = Get-Org -Name $OrgName | Get-OrgVdc -Name $OrgVdcName

    if ( $orgVdc.Count -gt 1) {
        throw "Multiple OrgVdcs found!"
        }
        elseif ( $orgVdc.Count -lt 1) {
            throw "No OrgVdc found!"
            }
    ## Get External Network
    Write-Verbose "Get External Network"
    $extNetwork = Get-ExternalNetwork | Get-CIView -Verbose:$False | Where-Object {$_.name -eq $ExternalNetwork}

    ## Build EdgeGatway Configuration
    Write-Verbose "Build EdgeGatway Configuration"
    $EdgeGateway = New-Object VMware.VimAutomation.Cloud.Views.Gateway
    $EdgeGateway.Name = $Name
    $EdgeGateway.Configuration = New-Object VMware.VimAutomation.Cloud.Views.GatewayConfiguration
    #$EdgeGateway.Configuration.BackwardCompatibilityMode = $false
    $EdgeGateway.Configuration.GatewayBackingConfig = "compact"
    $EdgeGateway.Configuration.UseDefaultRouteForDnsRelay = $true
    $EdgeGateway.Configuration.HaEnabled = $false

    $EdgeGateway.Configuration.EdgeGatewayServiceConfiguration = New-Object VMware.VimAutomation.Cloud.Views.GatewayFeatures
    $EdgeGateway.Configuration.GatewayInterfaces = New-Object VMware.VimAutomation.Cloud.Views.GatewayInterfaces

    $EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface = New-Object VMware.VimAutomation.Cloud.Views.GatewayInterface
    $EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface[0].name = $extNetwork.Name
    $EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface[0].DisplayName = $extNetwork.Name
    $EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface[0].Network = $extNetwork.Href
    $EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface[0].InterfaceType = "uplink"
    $EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface[0].UseForDefaultRoute = $true
    $EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface[0].ApplyRateLimit = $false

    $ExNetexternalSubnet = New-Object VMware.VimAutomation.Cloud.Views.SubnetParticipation
    $ExNetexternalSubnet.Gateway = $Gateway.IPAddressToString
    $ExNetexternalSubnet.Netmask = $SubnetMask.IPAddressToString
    $ExNetexternalSubnet.IpAddress = $IPAddress.IPAddressToString
    #$ExNetexternalSubnet.IpRanges = New-Object VMware.VimAutomation.Cloud.Views.IpRanges
    #$ExNetexternalSubnet.IpRanges.IpRange = New-Object VMware.VimAutomation.Cloud.Views.IpRange
    #$ExNetexternalSubnet.IpRanges.IpRange[0].StartAddress = $IPRangeStart.IPAddressToString
    #$ExNetexternalSubnet.IpRanges.IpRange[0].EndAddress =   $IPRangeEnd.IPAddressToString

    $EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface[0].SubnetParticipation = $ExNetexternalSubnet

    ## Create EdgeGatway
    Write-Verbose "Create EdgeGatway"
    $CreateEdgeGateway = $orgVdc.ExtensionData.CreateEdgeGateway($EdgeGateway)

    ## Wait for EdgeGatway to become Ready
    Write-Verbose "Wait for EdgeGatway to become Ready"
    while((Search-Cloud -QueryType EdgeGateway -Name $Name -Verbose:$False).IsBusy -eq $True){
        $i++
        Start-Sleep 5
        if($i -gt $Timeout) { Write-Error "Creating Edge Gateway."; break}
        Write-Progress -Activity "Creating Edge Gateway" -Status "Wait for Edge to become Ready..."
    }
    Write-Progress -Activity "Creating Edge Gateway" -Completed
    Start-Sleep 1

    Search-Cloud -QueryType EdgeGateway -Name $Name | Select-Object Name, IsBusy, GatewayStatus, HaStatus | Format-Table -AutoSize


    }
}

Function ValidSubnetMask ($strSubnetMask)
{
    <#
    .SYNOPSIS
        Checks if a subnet mask is valid
    
    .DESCRIPTION
        Checks if a subnet mask is valid

        Default parameters are:
        * strSubnetMask
    .EXAMPLE
        ValidSubnetMask(255.255.255.0)
    .PARAMETER strSubnetMask
        The subnet mask as a string
    #>
	$bValidMask = $true
	$arrSections = @()
	$arrSections += $strSubnetMask.split(".")
	#firstly, make sure there are 4 sections in the subnet mask
	if ($arrSections.count -ne 4) {$bValidMask =$false}
	
	#secondly, make sure it only contains numbers and it's between 0-255
	if ($bValidMask)
	{
		[reflection.assembly]::LoadWithPartialName("'Microsoft.VisualBasic") | Out-Null
		foreach ($item in $arrSections)
		{
			if (!([Microsoft.VisualBasic.Information]::isnumeric($item))) {$bValidMask = $false}
		}
	}
	
	if ($bValidMask)
	{
		foreach ($item in $arrSections)
		{
			$item = [int]$item
			if ($item -lt 0 -or $item -gt 255) {$bValidMask = $false}
		}
	}
	
	#lastly, make sure it is actually a subnet mask when converted into binary format
	if ($bValidMask)
	{
		foreach ($item in $arrSections)
		{
			$binary = [Convert]::ToString($item,2)
			if ($binary.length -lt 8)
			{
				do {
				$binary = "0$binary"
				} while ($binary.length -lt 8)
			}
			$strFullBinary = $strFullBinary+$binary
		}
		if ($strFullBinary.contains("01")) {$bValidMask = $false}
		if ($bValidMask)
		{
			$strFullBinary = $strFullBinary.replace("10", "1.0")
			if ((($strFullBinary.split(".")).count -ne 2)) {$bValidMask = $false}
		}
	}
	Return $bValidMask
}

# Check if the PowerCLI module has been installed. If it hasn't, install it silently
if (-not(Get-InstalledModule VMWare.VimAutomation.Core -ErrorAction SilentlyContinue)) {
    Write-Host "Installing PowerCLI module..."
    Install-PackageProvider NuGet -Force
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module VMware.PowerCLI
    Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false
}

# Import VMware.VimAutomation.Core module.
# VMware.PowerCLI is not imported because the entire module is not needed.
# Loading the smaller module saves time (30 sec vs. 3 sec on computer script was created on)
Write-Host "Initializing PowerCLI module..."
try {
    Import-Module VMware.VimAutomation.Core
    Write-Host "PowerCLI Initialized."
}
catch {
    Write-Host -NoNewLine "Failed to import PowerCLI module. Press any key to exit."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
    exit(1)
}

# Check to see which location the resources will be created in (for multiple VCD instances)
$valid = $false
do {
    Write-Host ""
    Write-Host ""
    Write-Host "Which datacenter is the test being performed in?"
    Write-Host "[1] Las Vegas"
    Write-Host "[2] Grand Rapids"
    $DCinput = Read-Host -Prompt "Datacenter"
    if($DCinput -eq 1 -or $DCinput -eq 2) {
        $valid = $true
        Write-Host ""
    }
    else {
        Write-Host "Invalid response, please try again."
        Write-Host ""
        Write-Host ""
    }
} while (!$valid)

switch($DCinput) {
    1 {
        Write-Host "Las Vegas selected. Connecting to VCD..."
        $VCDServer = "vcdurl.example.com"
        $pVDCName = "vCloud VDC Name"
        $netPoolName = "vCloud Network Pool Name"
        $sPolicyName = "Target Production Storage Policy"
        $IRPolicyName = "VeeamBackup IR Datastore"
        $defSPolicyName = "VCD Default Storage Policy Name"
        $EGNetwork = "Network_to_Use"
        $EGgateway = "0.0.0.0"
        $EGSubnet = "255.255.255.0"
        $EGIP = "0.0.0."
        $octetMin = 34
        $octetMax = 62
    }
    2 {
        Write-Host "Grand Rapids selected. Connecting to VCD..."
        $VCDServer = "vcdurl.example.com"
        $pVDCName = "vCloud VDC Name"
        $netPoolName = "vCloud Network Pool Name"
        $sPolicyName = "Target Production Storage Policy"
        $IRPolicyName = "VeeamBackup IR Datastore"
        $defSPolicyName = "VCD Default Storage Policy Name"
        $EGNetwork = "Network_to_Use"
        $EGgateway = "0.0.0.0"
        $EGSubnet = "255.255.255.0"
        $EGIP = "0.0.0."
        $octetMin = 34
        $octetMax = 62
    }
}

# prompt for credentials until successfully connected to VCD
# if SSO configured on computer running script and VCD, the logged in account will be used
$connected = $false
do {
    if(Connect-CIServer -Server $VCDServer) {
        $connected = $true
    }
} while(!$connected)

# Create the organization, using an org name and company name provided by the user
$OrgName = Read-Host -Prompt "Please enter the organization name"
$org = Get-Org -Name $OrgName -ErrorAction SilentlyContinue
if($null -ne $org) {
    Write-Host "Organization already exists. Skipping creation."
}
else {
    try {
        $companyName = Read-Host -Prompt "Please enter the company name"
        $org = New-Org -Name $OrgName -FullName $companyName
    }
    catch {
        Write-Error $Error[0]
        Write-Host -NoNewLine "Failed to create VCD organization. Press any key to exit."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        exit(1)
    }
}

# Retrieve provider vdc information for use later
Write-Host "Retrieving Provider VDC information..."
$pVDC = Get-ProviderVdc -Name $pVDCName | Select -First 1
if($null -eq $org) {
    Write-Host -NoNewline "Unable to retrieve provider VDC information. Press any key to exit."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
    exit(1)
}

# Create & configure virtual data center for the new org
# Enable thin provisioning
# Add storage policies
# Change default storage policy to newly added one
# Remove default storage policy added at creation
$orgVDC = Get-OrgVdc -Name $OrgName -ErrorAction SilentlyContinue
if($null -ne $orgVDC) {
    Write-Host "Organization VDC already exists. Skipping creation."
}
else {
    try {
        Write-Host "Creating virtual data center for organization..."
        $netPool = Get-NetworkPool -Name $netPoolName | Select -First 1
        $orgVDC = New-OrgVdc -Name $OrgName -AllocationModelPayAsYouGo -Org $org -ProviderVdc $pVDC -VMCpuCoreMHz 2000 -NetworkPool $netPoolName

        Write-Host "Enabling thin provisioning on data center..."
        $edit = Set-OrgVdc -OrgVdc $orgVDC -ThinProvisioned $true

        # Get the object representing the new Storage Profile in the Provider vDC
        $PvDCProfile = search-cloud -QueryType ProviderVdcStorageProfile -Name $sPolicyName | Get-CIView

        $spParams = new-object VMware.VimAutomation.Cloud.Views.VdcStorageProfileParams
        $spParams.ProviderVdcStorageProfile = $PvDCProfile.href
        $spParams.Limit = 0
        $spParams.Units = "MB"
        $spParams.Enabled = $true
        $spParams.Default = $false

        $UpdateParams = new-object VMware.VimAutomation.Cloud.Views.UpdateVdcStorageProfiles
        $UpdateParams.AddStorageProfile = $spParams

        $create = $orgVDC.ExtensionData.CreateVdcStorageProfile($UpdateParams)

        # Get object representing the new Storage Profile in the Org vDC
        $newvDCProfile = search-cloud -querytype AdminOrgVdcStorageProfile | where {($_.Name -match $sPolicyName) -and ($_.VdcName -eq $orgVDC.Name)} | Get-CIView
        $return = $newvDCProfile.UpdateServerData()

        # Get the object representing the new Storage Profile in the Provider vDC
        $PvDCProfile = search-cloud -QueryType ProviderVdcStorageProfile -Name $IRPolicyName | Get-CIView

        $spParams2 = new-object VMware.VimAutomation.Cloud.Views.VdcStorageProfileParams
        $spParams2.ProviderVdcStorageProfile = $PvDCProfile.href
        $spParams2.Limit = 0
        $spParams2.Units = "MB"
        $spParams2.Enabled = $true
        $spParams2.Default = $false

        $UpdateParams2 = new-object VMware.VimAutomation.Cloud.Views.UpdateVdcStorageProfiles
        $UpdateParams2.AddStorageProfile = $spParams2

        $create = $orgVDC.ExtensionData.CreateVdcStorageProfile($UpdateParams2)

        # Get object representing the new Storage Profile in the Org vDC
        $newvDCProfile2 = search-cloud -querytype AdminOrgVdcStorageProfile | where {($_.Name -match $IRPolicyName) -and ($_.VdcName -eq $orgVDC.Name)} | Get-CIView

        # Make the new Storage Profile the default
        $newvDCProfile2.Default = $True
        $return = $newvDCProfile2.UpdateServerData()

        # Get object representing the * (Any) Profile in the Org vDC
        $orgvDCAnyProfile = search-cloud -querytype AdminOrgVdcStorageProfile | Where-Object {($_.Name -match $defSPolicyName) -and ($_.VdcName -eq $orgVdc.Name)} | Get-CIView

        # Disable the "* (any)" Profile
        $orgvDCAnyProfile.Enabled = $False
        $return = $orgvDCAnyProfile.UpdateServerData()

        # Remove the "* (any)" profile form the Org vDC completely
        $ProfileUpdateParams = new-object VMware.VimAutomation.Cloud.Views.UpdateVdcStorageProfiles
        $ProfileUpdateParams.RemoveStorageProfile = $orgvDCAnyProfile.href
        $remove = $orgvdc.extensiondata.CreatevDCStorageProfile($ProfileUpdateParams)
    }
    catch {
        Write-Error $Error[0]
        Write-Host -NoNewLine "Failed to create Virtual data center. Press any key to exit."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        exit(1)
    }
}

# Create an Edge Gateway for the organization
$edgeGateway = Get-EdgeGateway -Name "$OrgName-EG" -ErrorAction SilentlyContinue
if($null -ne $edgeGateway) {
    Write-Host "Edge gateway already deployed. Skipping creation."
}
else {
    try {
        $inputPrompt = "Enter the final octet for the Edge Gateway IP (" + $EGIP + "X)"
        $validIP = $false
        do {
            $input = Read-Host -Prompt $inputPrompt
            try {
                if($input -ge $octetMin -and $input -le $octetMax) {
                    $IP = [IPAddress]($EGIP + $input)
                    $validIP = $true
                }
                else {
                    Write-Host "Invalid value entered. Please try again."
                    Write-Host ""
                    Write-Host ""
                }
            }
            catch {
                Write-Host "Invalid value entered. Please try again."
                Write-Host ""
                Write-Host ""
            }
        } while(!$validIP)
        $edgeGateway = New-MyEdgeGateway -Name "$OrgName-EG" -OrgVDCName $orgVDC.Name -OrgName $org.Name -ExternalNetwork $EGNetwork -IPAddress $IP -SubnetMask $EGSubnet -Gateway $EGgateway
        $edgeGateway = Get-EdgeGateway -Name "$OrgName-EG" -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error $Error[0]
        Write-Host -NoNewLine "Failed to create edge gateway. Press any key to exit."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        exit(1)
    }
}

# Prompt for networks to add to EG and create them
$networks = Get-OrgVdcNetwork -OrgVdc $orgVDC
$netCount = $networks.Count
if($netCount -eq 1) {
    Write-Host "A network has already been created. Skipping configuration."
}
elseif($netCount -gt 1) {
    Write-Host "$netCount networks have already been created. Skipping configuration."
}
else {
    $validInt = $false
    do {
        [int]$numNetworks = Read-Host -Prompt "How many networks would you like to configure"
        if($null -ne $numNetworks) {
            $validInt = $true
        }
        else {
            Write-Host "Invalid entry. Please try again."
            Write-Host ""
            Write-Host ""
        }
    } while(!$validInt)

    for($i = 1; $i -le $numNetworks; $i++) {
        $validGW = $false
        do {
            $input = Read-Host -Prompt "Enter the gateway address (ex. 192.168.0.1)"
            try {
                $gatewayIP = [IPAddress]$input
                $validGW = $true
            }
            catch {
                Write-Host "$input is not a valid IP address. Please try again."
                Write-Host ""
                Write-Host ""
            }
        } while(!$validGW)

        $validSubnet = $false
        do {
            $input = Read-Host -Prompt "Enter the network subnet mask (ex. 255.255.255.0)"
            if(validSubnetMask($input)) {
                $subnetMask = $input
                $validSubnet = $true
            }
            else {
                Write-Host "$input is not a valid subnet mask. Please try again."
                Write-Host ""
                Write-Host ""
            }
        } while(!$validSubnet)

        $netName = "$OrgName-Net" + "{0:D2}" -f $i
        try {
            $network = New-OrgVdcNetwork -EdgeGateway $edgeGateway -Gateway $gatewayIP -Routed -Name $netName -Netmask $subnetMask -OrgVdc $orgVDC

            $primaryConf = Read-Host -Prompt "Would you like to set a primary DNS IP for this network (y/n)"
            $primaryConf = $primaryConf.ToLower()
            if($primaryConf -eq "y" -or $primaryConf -eq 'yes') {
                $input = Read-Host -Prompt "Enter the Primary DNS Address"
                $validIP = $false
                do {
                    try {
                        $PrimaryDNS = [IPAddress]$input
                        $validIP = $true
                    }
                    catch {
                        Write-Host "$input is not a valid IP address. Please try again."
                        Write-Host ""
                        Write-Host ""
                    }
                } while(!$validIP)

                $secondaryConf = Read-Host -Prompt "Would you like to set a secondary DNS IP for this network (y/n)"
                $secondaryConf = $primaryConf.ToLower()

                if($secondaryConf -eq 'y' -or $secondaryConf -eq 'yes') {
                    $input = Read-Host -Prompt "Enter the Secondary DNS Address"

                    $validIP = $false
                    do {
                        try {
                            $SecondaryDNS = [IPAddress]$input
                            $validIP = $true
                        }
                        catch {
                            Write-Host "$input is not a valid IP address. Please try again."
                            Write-Host ""
                            Write-Host ""
                        }
                    } while(!$validIP)

                    #Update both DNS here
                    $update = Set-OrgVdcNetwork -OrgVdcNetwork $network -PrimaryDns $PrimaryDNS -SecondaryDns $SecondaryDNS
                }
                else {
                    #Update only primary DNS here
                    $update = Set-OrgVdcNetwork -OrgVdcNetwork $network -PrimaryDns $PrimaryDNS
                }
            }
        }
        catch {
            Write-Error "Failed to create network $netName with gateway $gatewayIP and subnet $subnetMask."
        }
    }
}

Write-Host ""
Write-Host "Setup complete. Please launch Cloud Director to verify settings, configure VPNs, create users, and begin VM import."
Write-Host -NoNewLine "Press any key to exit."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
