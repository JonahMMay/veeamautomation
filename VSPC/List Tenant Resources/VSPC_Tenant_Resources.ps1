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

$baseURL = "https://vspc/api/v3/"

Write-Host Getting inactive company list from VSPC...
#get list of inactive VSPC companies
$companies = @()
$running = $true
$count = 0
do {
    $companyURL = $baseURL + 'organizations/companies?filter=[{"property":"status","operation":"notEquals","collation":"ignorecase","value":"Deleted"}]&limit=500&offset=' + $count
    $results = (Invoke-RestMethod -Uri $companyURL -Method GET -Headers $headers).data
    $companies += $results
    if($results.Count -lt 500) {
        $running = $false
    }
    $count += 500
} while($running)


Write-Host Getting tenant information from VBR servers...
#get list of tenants on hosts (to get VBR name)
[System.Collections.ArrayList]$tenants = @()
$running = $true
$count = 0
do {
    $tenantUrl = $baseURL + 'infrastructure/sites/tenants?limit=500&offset=' + $count
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
#get backup/replication information and save to array
$Resources = @()
$ResourceInfo = ""
$count = 1
foreach($company in $companies) {
    $string = "Collecting information for tenant (" + $count + "/" + $companies.Count + ") " + $company.name + "..."
    Write-host $string
    $siteURL = $baseURL + 'organizations/companies/' + $company.instanceUid + '/sites'
    $sites = (Invoke-RestMethod -Uri $siteURL -Method GET -Headers $headers).data
        
    foreach($site in $sites) {
        foreach($tenant in $tenants) {
            if($tenant.instanceUid -eq $site.cloudTenantUid) {
                #get replication resource usage
                $RepUsageURL = $baseURL + 'organizations/companies/' + $company.instanceUid + '/sites/' + $site.siteUid + '/replicationResources/usage'
                $RepUsage = (Invoke-RestMethod -Uri $RepUsageURL -Method GET -Headers $headers).data
                $repEnabled = 'N'
                
                if($null -eq $RepUsage.vCPUsConsumed) {
                    $vCPUsConsumed = 0
                }
                else {
                    $vCPUsConsumed = $RepUsage.vCPUsConsumed
                }
                
                if($RepUsage.Count -gt 0) {
                    $repEnabled = 'Y'
                }
                
                #get used backup space
                $usageURL = $baseURL + 'organizations/companies/' + $company.instanceUid + '/sites/' + $site.siteUid + '/backupResources/usage'
                $usage = (Invoke-RestMethod -Uri $usageURL -Method GET -Headers $headers).data
                $buEnabled = 'N'

                if($usage.Count -gt 0) {
                    $buEnabled = 'Y'
                    try {
                        #get parent repository id
                        $resourceURL = $baseURL + 'organizations/companies/' + $company.instanceUid + '/sites/' + $site.siteUid + '/backupResources/' + $usage.backupResourceUid
                        $resource = (Invoke-RestMethod -Uri $resourceURL -Method GET -Headers $headers).data
                        
                        #get parent repository information
                        $repoURL = $baseURL + 'infrastructure/backupServers/' + $resource.siteUid + '/repositories/' + $resource.repositoryUid
                        $repo = (Invoke-RestMethod -Uri $repoURL -Method GET -Headers $headers).data
                    }
                    catch {}
                }
                foreach($CChost in $CChosts) {
                    if($tenant.backupServerUid -eq $CChost.siteUid) {
                        $ResourceInfo = [PSCustomObject]@{
                            'Company' = $tenant.description
                            'Tenant' = $tenant.Name
                            'VBR Host' = $CChost.siteName
                            'Backup Enabled' = $buEnabled
                            'Replication Enabled' = $repEnabled
                            'Repository' = $repo.name
                            'Type' = $repo.type
                            'Repository Host' = $repo.hostName
                            'Backup Storage Used (TB)' = $usage.usedStorageQuota / 1024 / 1024 / 1024 / 1024
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
        $tenants.Remove($lastTenant)
    }
    $count++
}

Write-Host Saving data to CSV...
#export usage information to CSV and save to downloads folder
$FilePath = $env:USERPROFILE + "\Downloads\TenantResources.csv"
$Resources | Export-CSV -Path $FilePath -NoTypeInformation

#tell user file location and exit when any key is pressed
Write-Host 'Report available under' $FilePath
Write-Host -NoNewLine 'Press any key to exit...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
