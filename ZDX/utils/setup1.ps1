$autologon = "C:\Autologon64.exe"
$username = "zdx"
$domain = hostname
$password = "PASSHERE"

Invoke-WebRequest -Uri  https://download.sysinternals.com/files/AutoLogon.zip -UseBasicParsing -OutFile 'C:\\auto.zip'
Expand-Archive -Path 'C:\\auto.zip' -DestinationPath 'C:\\' -Force
Start-Process $autologon -ArgumentList $username,$domain,$password
Invoke-WebRequest -Uri  https://d32a6ru7mhaq0c.cloudfront.net/Zscaler-windows-4.3.0.131-installer-x64.msi -UseBasicParsing -OutFile 'C:\\zinstaller.msi'
msiexec /i C:\zinstaller.msi /quiet CLOUDNAME=zscalerthree HIDEAPPONLAUNCHUI=1 USERDOMAIN=thezerotrustexchange.com
