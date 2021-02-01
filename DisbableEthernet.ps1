#Disable and enable network Ethernet interface via local windows admin.

#Local admin credentials
$adminlogin = "ADMIN LOGIN"
$adminPassword = "ADMIN PASSWORD"

#create a secure string
$securePassword = convertto-securestring $adminPassword -asplaintext -force

#create PSCredential object
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $adminlogin,$securePassword

#Get system info
Write-host "Windows verion: " (Get-WmiObject win32_operatingsystem).caption
Write-host "Computer name: " $env:computername
Write-host "User name: " $env:UserName

#Get status network card
$adapter = Get-NetAdapter -Name "Ethernet"
$adapterstatus = $adapter.AdminStatus

Write-host "Now Ethernet interfase is "$adapterstatus

#sleepTimer
Start-Sleep -s 4

#Disable or Enable network interface Ethernet
if ( $adapterstatus -eq 'Up' ) { 
    Start-Process powershell -Credential $credential -ArgumentList '-noprofile -command & {Start-Process PowerShell -verb runas -ArgumentList ''Write-host "Turn OFF Ethernet Adapter"; Disable-NetAdapter -Name "Ethernet" -Confirm: "$false"; Write-host "Done"; Start-Sleep -s 3 ''}'
}
elseif ($adapterstatus -eq 'Down') {
    Start-Process powershell -Credential $credential -ArgumentList '-noprofile -command & {Start-Process PowerShell -verb runas -ArgumentList ''Write-host "Turn ON Ethernet Adapter"; Enable-NetAdapter -Name "Ethernet" -Confirm: "$false"; Write-host "Done"; Start-Sleep -s 3''}' 
}