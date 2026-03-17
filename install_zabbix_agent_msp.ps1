# ===============================
# Zabbix Agent2 MSP Auto Deploy
# ===============================

$ScriptsPath = "C:\Scripts"
$AgentFolder = "C:\Program Files\Zabbix Agent 2"
$ConfigPath = "$AgentFolder\zabbix_agent2.conf"

# AJUSTAR SEU GITHUB
$GitUpdateScript = "https://raw.githubusercontent.com/MarceloRC/Zabbix-Install/main/windows_update_check.ps1"
$GitADScript = "https://raw.githubusercontent.com/MarceloRC/Zabbix-Install/main/ad_replication.ps1"

# URL LTS (Zabbix 7 LTS)
$AgentURL = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/7.0.23/zabbix_agent2-7.0.23-windows-amd64-openssl.msi"
$AgentInstaller = "C:\Scripts\zabbix_agent2.msi"

Write-Host "===== ZABBIX MSP INSTALL ====="

# Criar pasta Scripts
if (!(Test-Path $ScriptsPath)) {
    New-Item -ItemType Directory -Path $ScriptsPath | Out-Null
}

# Detectar Gateway
$DetectedGateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
Sort-Object RouteMetric |
Select-Object -First 1).NextHop

Write-Host ""
Write-Host "Gateway detectado: $DetectedGateway"

# Perguntar se quer usar o detectado
$UseDetected = Read-Host "Usar este gateway como Zabbix Server? (Y/N)"

if ($UseDetected -eq "N" -or $UseDetected -eq "n") {
    $Gateway = Read-Host "Digite o IP do Zabbix Server"
}
else {
    $Gateway = $DetectedGateway
}

Write-Host "Zabbix Server configurado como: $Gateway"

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

Unblock-File $AgentInstaller

Start-Process "msiexec.exe" -Wait -ArgumentList @(
    "/i",
    "`"$AgentInstaller`"",
    "/qn",
    "/norestart",
    "SERVER=$Gateway",
    "SERVERACTIVE=$Gateway",
    "HOSTNAME=$fqdn"
)
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
Write-Host ""
Write-Host "Executar politica de Update"
powershell C:\Scripts\windows_update_check.ps1
# ===============================
# CRIAR TASK WINDOWS UPDATE
# ===============================

$CreateTask = Read-Host "Deseja criar a tarefa de Windows Update? (Y/N)"

if ($CreateTask -eq "Y" -or $CreateTask -eq "y") {

    Write-Host "Criando Task Scheduler..."

    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\windows_update_check.ps1"

    $Trigger1 = New-ScheduledTaskTrigger -Daily -At 13:00
    $Trigger2 = New-ScheduledTaskTrigger -Daily -At 03:00
    $Trigger3 = New-ScheduledTaskTrigger -AtLogOn

    $Principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    Register-ScheduledTask `
        -TaskName "Zabbix-Windows-Update-Check" `
        -Action $Action `
        -Trigger @($Trigger1, $Trigger2, $Trigger3) `
        -Principal $Principal `
        -Description "Verificação de atualizações para Zabbix" `
        -Force

    Write-Host "Task criada com sucesso."
}
else {
    Write-Host "Task não criada."
}
