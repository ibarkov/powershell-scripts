#Service names
$services = @('Spooler','TeamViewer')

#email credentials
#Send Email From:
$emailPass = 'password'
$emailName = 'test'

#email settings
$emailSrcAdress = 'test@gmail.com'
$emailDstAddress = 'test@outlook.com'
$smtpServer = "smtp.gmail.com"
$smtpPort = 587

$secpasswd = ConvertTo-SecureString $emailPass -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($emailName, $secpasswd)

#Send_message
Send-MailMessage -From $emailSrcAdress -To $emailDstAddress -Subject "Service status on $env:computername $(Get-Date -Format g)" -Body ($services | ForEach-Object {Get-Service -Name $_} | Format-Table -Wrap | Out-String) -SmtpServer $smtpServer -Port $smtpPort -credential $mycreds -UseSsl




