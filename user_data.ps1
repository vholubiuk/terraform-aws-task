<powershell>
Install-WindowsFeature -name Web-Server -IncludeManagementTools

Enable-PSRemoting
Start-Service WinRM
New-NetFirewallRule -DisplayName "Allow TCP 5985" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985
New-NetFirewallRule -DisplayName "Allow TCP 5986" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5986
</powershell>