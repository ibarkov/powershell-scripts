First, make sure the system is allowed to run scripts
Get-ExecutionPolicy -List

Install the policy
Set-ExecutionPolicy RemoteSigned

# powershell-scripts
DisbableEthernet - this script enable or disable network interfae with name "Ethernet"  as administrator, but script can be run user.

GetServiceStatus - This script send to email status Windows services, specified in the array $services