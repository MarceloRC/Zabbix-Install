# ===============================
# Zabbix Agent2 MSP Auto Deploy
# ===============================

$ScriptsPath = "C:\Scripts"
$AgentFolder = "C:\Program Files\Zabbix Agent 2"
$ConfigPath = "$AgentFolder\zabbix_agent2.conf"

# AJUSTAR SEU GITHUB
$GitUpdateScript = "https://raw.githubusercontent.com/MarceloRC/Zabbix-Install/refs/heads/main/windows_update_check.ps1"
$GitADScript = "https://raw.githubusercontent.com/MarceloRC/Zabbix-Install/refs/heads/main/ad_replication.ps1"

# URL LTS (Zabbix 7 LTS)
$AgentURL = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/7.0.23/zabbix_agent2_plugins-7.0.23-windows-amd64.msi"
$AgentInstaller = "$env:TEMP\zabbix_agent2.msi"

Write-Host "===== ZABBIX MSP INSTALL ====="

# Criar pasta Scripts
if (!(Test-Path $ScriptsPath)) {
    New-Item -ItemType Directory -Path $ScriptsPath | Out-Null
}

# Detectar Gateway
$Gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
Sort-Object RouteMetric |
Select-Object -First 1).NextHop

Write-Host "Gateway detectado: $Gateway"

# Hostname FQDN
$hostname = $env:COMPUTERNAME
$domain = (Get-CimInstance Win32_ComputerSystem).Domain

if ($domain -and $domain -ne $hostname) {
    $fqdn = "$hostname.$domain"
}
else {
    $fqdn = $hostname
}

Write-Host "Hostname: $fqdn"

# Baixar Agent
Write-Host "Baixando Zabbix Agent..."

Invoke-WebRequest $AgentURL -OutFile $AgentInstaller

# Instalar Agent silencioso
Write-Host "Instalando Agent..."

Start-Process msiexec.exe -Wait -ArgumentList "/i $AgentInstaller /qn"

Start-Sleep 5

# Backup config original
if (Test-Path $ConfigPath) {
    Copy-Item $ConfigPath "$ConfigPath.bak" -Force
}

# Baixar scripts Git
Write-Host "Baixando scripts..."

Invoke-WebRequest $GitUpdateScript -OutFile "$ScriptsPath\windows_update_check.ps1"
Invoke-WebRequest $GitADScript -OutFile "$ScriptsPath\ad_replication.ps1"

# Criar config Zabbix
$config = @"
LogFile=C:\Program Files\Zabbix Agent 2\zabbix_agent2.log
Server=$Gateway
Hostname=$fqdn
ControlSocket=\\.\pipe\agent.sock

UnsafeUserParameters=1

Include=.\zabbix_agent2.d\plugins.d\*.conf

UserParameter=windows.update.total,powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content C:\Scripts\windows_update_status.txt | Select-String 'TotalUpdates').ToString().Split('=')[1]"

UserParameter=windows.update.critical,powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content C:\Scripts\windows_update_status.txt | Select-String 'CriticalUpdates').ToString().Split('=')[1]"

UserParameter=windows.update.security,powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content C:\Scripts\windows_update_status.txt | Select-String 'SecurityUpdates').ToString().Split('=')[1]"

UserParameter=windows.update.reboot,powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content C:\Scripts\windows_update_status.txt | Select-String 'RebootRequired').ToString().Split('=')[1]"

UserParameter=windows.update.service,powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content C:\Scripts\windows_update_status.txt | Select-String 'WUServiceRunning').ToString().Split('=')[1]"

UserParameter=windows.update.days,powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content C:\Scripts\windows_update_status.txt | Select-String 'DaysSinceLastUpdate').ToString().Split('=')[1]"

UserParameter=ad.replication.status,powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\ad_replication.ps1"
"@

$config | Out-File -Encoding ascii $ConfigPath

Write-Host "Configuração aplicada"

# Reiniciar serviço
Restart-Service "Zabbix Agent 2" -Force

Write-Host ""
Write-Host "ZABBIX AGENT INSTALADO E CONFIGURADO"
