Connect-VBRServer -Server localhost

$certificate = Get-VBRCloudGatewayCertificate -FromStore | Where {$_.SubjectName -eq "CN=vspc.example.com"} | Sort-Object -Property NotBefore -Descending | Select -First 1

Add-VBRCloudGatewayCertificate -Certificate $certificate

Disconnect-VBRServer
