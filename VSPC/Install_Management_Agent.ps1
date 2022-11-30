Set-ExecutionPolicy Bypass -Scope Process -Force

#import PowerShell module if not v11
try {
    asnp VeeamPSSnapin
}
catch {}

#get list of cloud jobs and cloud repos
$cloudJobs = Get-VBRJob | Where {$_.isCloudTargetJob() -eq $True -and $_.Info.IsScheduleEnabled -eq $True}
$cloudRepos = Get-VBRBackupRepository | Where {$_.Type -eq "Cloud" -and $_.Host.Name -like "*example.com*" -and $_.IsAvailable -eq $True}

#compare cloud job target locations to repos to determine which holds the most jobs
$mostUsedCount = 0
$mostUsedRepo = ""
foreach($cloudRepo in $cloudRepos) {
    $count = ($cloudJobs | Where {$_.TargetHostId -eq $cloudRepo.Host.Id}).Count
    if($count -gt $mostUsedCount) {
        $mostUsedCount = $count
        $mostUsedRepo = $cloudRepo
    }
}

#install the VSPC management agent, linked to the service provider with the most jobs pointed to it
$cloudProvider = Get-VBRCloudProvider -Name $mostUsedRepo.Host.Name
Set-VBRCloudProvider -CloudProvider $cloudProvider -InstallManagementAgent
