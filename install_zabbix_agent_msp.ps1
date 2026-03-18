# ===============================
# Zabbix Agent2 MSP Auto Deploy
# ===============================

$ScriptsPath = "C:\Scripts"
$AgentFolder = "C:\Program Files\Zabbix Agent 2"
$ConfigPath = "$AgentFolder\zabbix_agent2.conf"

$GitUpdateScript = "https://raw.githubusercontent.com/MarceloRC/Zabbix-Install/main/windows_update_check.ps1"
$GitADScript = "https://raw.githubusercontent.com/MarceloRC/Zabbix-Install/main/ad_replication.ps1"

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

$UseDetected = Read-Host "Usar este gateway como Zabbix Server? (Y/N)"

if ($UseDetected -eq "N" -or $UseDetected -eq "n") {
    $Gateway = Read-Host "Digite o IP do Zabbix Server"
}
else {
    $Gateway = $DetectedGateway
}

Write-Host "Zabbix Server configurado como: $Gateway"

# Hostname
$hostname = $env:COMPUTERNAME
$domain = (Get-CimInstance Win32_ComputerSystem).Domain

if ($domain -and $domain -ne $hostname) {
    $fqdn = "$hostname.$domain"
} else {
    $fqdn = $hostname
}

Write-Host "Hostname: $fqdn"

# Baixar Agent
Write-Host "Baixando Zabbix Agent..."
Invoke-WebRequest $AgentURL -OutFile $AgentInstaller

# =========================
# LIMPEZA COMPLETA
# =========================
Write-Host "========== INICIANDO LIMPEZA COMPLETA ZABBIX =========="

$services = @("Zabbix Agent","Zabbix Agent 2")

foreach ($svc in $services) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service) {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        sc.exe delete "$svc" | Out-Null
    }
}

$serviceRegPaths = @(
"HKLM:\SYSTEM\CurrentControlSet\Services\Zabbix Agent",
"HKLM:\SYSTEM\CurrentControlSet\Services\Zabbix Agent 2",
"HKLM:\SYSTEM\ControlSet001\Services\Zabbix Agent",
"HKLM:\SYSTEM\ControlSet001\Services\Zabbix Agent 2",
"HKLM:\SYSTEM\ControlSet002\Services\Zabbix Agent",
"HKLM:\SYSTEM\ControlSet002\Services\Zabbix Agent 2"
)

foreach ($path in $serviceRegPaths) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$eventPaths = @(
"HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application\Zabbix Agent",
"HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application\Zabbix Agent 2",
"HKLM:\SYSTEM\ControlSet001\Services\EventLog\Application\Zabbix Agent",
"HKLM:\SYSTEM\ControlSet001\Services\EventLog\Application\Zabbix Agent 2",
"HKLM:\SYSTEM\ControlSet002\Services\EventLog\Application\Zabbix Agent",
"HKLM:\SYSTEM\ControlSet002\Services\EventLog\Application\Zabbix Agent 2"
)

foreach ($path in $eventPaths) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$paths = @(
"C:\Program Files\Zabbix Agent",
"C:\Program Files\Zabbix Agent 2",
"C:\Program Files (x86)\Zabbix Agent",
"C:\Program Files (x86)\Zabbix Agent 2"
)

foreach ($p in $paths) {
    if (Test-Path $p) {
        Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "========== LIMPEZA FINALIZADA =========="

# =========================
# INSTALAÇÃO
# =========================
Write-Host "Instalando Agent..."

Unblock-File $AgentInstaller

Start-Process "msiexec.exe" -Wait -ArgumentList @(
"/i","`"$AgentInstaller`"",
"/qn","/norestart",
"SERVER=$Gateway",
"SERVERACTIVE=$Gateway",
"HOSTNAME=$fqdn"
)

Start-Sleep 5

# =========================
# CONFIG
# =========================
if (Test-Path $ConfigPath) {
    Copy-Item $ConfigPath "$ConfigPath.bak" -Force
}

Invoke-WebRequest $GitUpdateScript -OutFile "$ScriptsPath\windows_update_check.ps1"
Invoke-WebRequest $GitADScript -OutFile "$ScriptsPath\ad_replication.ps1"

$config = @"
LogFile=C:\Program Files\Zabbix Agent 2\zabbix_agent2.log
Server=$Gateway
Hostname=$fqdn
ControlSocket=\\.\pipe\agent.sock
UnsafeUserParameters=1
Include=.\zabbix_agent2.d\plugins.d\*.conf
UserParameter=windows.update.total,powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content C:\Scripts\windows_update_status.txt | Select-String 'TotalUpdates').ToString().Split('=')[1]"
UserParameter=ad.replication.status,powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\ad_replication.ps1"
"@

$config | Out-File -Encoding ascii $ConfigPath

Write-Host "Configuração aplicada"

# =========================
# SERVIÇO (INTELIGENTE)
# =========================
$serviceName = "Zabbix Agent 2"
$exePath = "C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe"

$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($svc) {
    Write-Host "Serviço já existe, reiniciando..."
    Restart-Service $serviceName -Force
}
else {
    Write-Host "Serviço não encontrado, criando manualmente..."

    if (Test-Path $exePath) {
        & "$exePath" --config "$ConfigPath" --install
        Start-Sleep 2
        Start-Service $serviceName
        Write-Host "Serviço criado e iniciado."
    }
    else {
        Write-Host "❌ Executável não encontrado!"
    }
}

Write-Host ""
Write-Host "ZABBIX AGENT INSTALADO E CONFIGURADO"

# =========================
# EXECUTAR CHECK
# =========================
powershell C:\Scripts\windows_update_check.ps1

# =========================
# TASK
# =========================
$CreateTask = Read-Host "Deseja criar a tarefa de Windows Update? (Y/N)"

if ($CreateTask -match "^[Yy]$") {

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
        -Force

    Write-Host "Task criada com sucesso."
}
