Invoke-Command -ComputerName 18.134.164.38 -Credential Administrator -ScriptBlock {

$FilePath = 'C:\inetpub\wwwroot\iisstart.htm'

Clear-Content $FilePath
Add-Content -Path $FilePath -Value '<html> <h2>WebServer Build by Powershell! <font color="red"> v5.1.19041.610 </font> </h2><br> Owner Valeii Holubiuk <br> </html>'
Write-Output 'Correct'
}