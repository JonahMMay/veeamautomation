Set-ExecutionPolicy Bypass -Scope Process -Force

#ignore SSL warnings
if (-not("dummy" -as [type])) {
    add-type -TypeDefinition @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public static class Dummy {
    public static bool ReturnTrue(object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors) { return true; }

    public static RemoteCertificateValidationCallback GetDelegate() {
        return new RemoteCertificateValidationCallback(Dummy.ReturnTrue);
    }
}
"@
}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [dummy]::GetDelegate()

#VSPC token and header
$token = '65f426212afc7351PqRYJS0tyrgCk2Wg1UT3T9NaYY6avBedY5E9m4oYOMfNUaom9nFKppn4D62C0ljsb4FFemM3OzYLFQofO1nJXMlgw6AJVXebPKa5OcWRcj5slnP9'
$headers = @{
    Authorization="Bearer $token"
}

#VSPC base url
$baseURL = "https://vspc/api/v3/"

Write-Host Getting inactive company list from VSPC...
#get list of inactive VSPC companies
$companies = @()
$running = $true
$count = 0
do {
    $companyURL = $baseURL + 'organizations/companies?filter=[{"property":"status","operation":"notEquals","collation":"ignorecase","value":"Active"}]&limit=500&offset=' + $count
    $results = (Invoke-RestMethod -Uri $companyURL -Method GET -Headers $headers).data
    $companies += $results
    if($results.Count -lt 500) {
        $running = $false
    }
    $count += 500
} while($running)


Write-Host Getting tenant information from VBR servers...
#get list of disabled tenants on hosts (to get VBR name)
[System.Collections.ArrayList]$tenants = @()
$running = $true
$count = 0
do {
    $tenantUrl = $baseURL + 'infrastructure/sites/tenants?filter=[{"property":"isEnabled","operation":"equals","collation":"ignorecase","value":"false"}]&limit=500&offset=' + $count
    $results = (Invoke-RestMethod -Uri $tenantURL -Method GET -Headers $headers).data
    $tenants += $results
    if($results.Count -lt 500) {
        $running = $false
    }
    $count += 500
} while($running)

#get VBR CC host information
$CChosts = @()
$running = $true
$count = 0
do {
    $hostUrl = $baseURL + 'infrastructure/sites?limit=500&offset=' + $count
    $results = (Invoke-RestMethod -Uri $hostURL -Method GET -Headers $headers).data
    $CChosts += $results
    if($results.Count -lt 500) {
        $running = $false
    }
    $count += 500
} while($running)


Write-Host Getting resource usage information...
#get backup and replication usage information and save to array
$Resources = @()
$ResourceInfo = ""
$count=0
foreach($company in $companies) {
    $string = "Collecting information for tenant (" + $count + "/" + $companies.Count + ") " + $company.name + "..."
    Write-host $string
    $siteURL = $baseURL + 'organizations/companies/' + $company.instanceUid + '/sites'
    $sites = (Invoke-RestMethod -Uri $siteURL -Method GET -Headers $headers).data
    #$sites
    
    foreach($site in $sites) {
        foreach($tenant in $tenants) {
            if($tenant.instanceUid -eq $site.cloudTenantUid) {
                $usageURL = $baseURL + 'organizations/companies/' + $company.instanceUid + '/sites/' + $site.siteUid + '/backupResources/usage'
                $usage = (Invoke-RestMethod -Uri $usageURL -Method GET -Headers $headers).data

                $RepUsageURL = $baseURL + 'organizations/companies/' + $company.instanceUid + '/sites/' + $site.siteUid + '/replicationResources/usage'
                $RepUsage = (Invoke-RestMethod -Uri $RepUsageURL -Method GET -Headers $headers).data

                if($null -eq $RepUsage.vCPUsConsumed) {
                    $vCPUsConsumed = 0
                }
                else {
                    $vCPUsConsumed = $RepUsage.vCPUsConsumed
                }

                foreach($CChost in $CChosts) {
                    if($tenant.backupServerUid -eq $CChost.siteUid) {
                        $ResourceInfo = [PSCustomObject]@{
                            'Tenant' = $tenant.Name
                            'VBR Host' = $CChost.siteName
                            'Backup Storage Used (GB)' = $usage.usedStorageQuota / 1024 / 1024 / 1024
                            'Replic Storage Used (GB)' = $RepUsage.storageUsage / 1024 /1024 /1024
                            'Replic Memory Used (GB)' = $RepUsage.memoryUsage / 1024 / 1024 / 1024
                            'Replic vCPUs' = $vCPUsConsumed
                        }
                        $Resources += $ResourceInfo
                        break
                    }
                }
                $lastTenant = $tenant
                break
            }
        }
        $tenants.Remove($tenant)
    }
    $count++
}

Write-Host Saving data...
#export usage information to CSV and save to downloads folder
$FilePath = $env:USERPROFILE + "\Downloads\OrphanedResources.csv"
$Resources | Export-CSV -Path $FilePath -NoTypeInformation
