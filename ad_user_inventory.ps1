# ============================================================
# ad_user_inventory.ps1
# Inventario de usuarios/computadores do AD para Zabbix
# (dashboard: usuarios ativos/desativados, contas de servico,
#  computadores obsoletos, breakdown por departamento)
#
# Execucao: Task Scheduler (recomendado 1x/dia)
# Resultados salvos em:
#   C:\Scripts\ad_user_inventory_status.txt   (metricas gerais)
#   C:\Scripts\ad_user_departments.json       (breakdown por depto, formato LLD Zabbix)
#
# Regras de negocio:
#   - Contas de servico = SamAccountName comecando com "svc-" ou "srv-"
#     (nao entram no breakdown por departamento nem nos totais de usuario)
#   - Departamento = nome da OU imediata na DistinguishedName do usuario
#   - "Desativado ha mais de 90 dias" usa whenChanged como aproximacao
#     da data de desativacao (AD nao guarda a data exata do disable)
# ============================================================
$statusFile = "C:\Scripts\ad_user_inventory_status.txt"
$deptFile   = "C:\Scripts\ad_user_departments.json"

$results = [ordered]@{
    TotalUsers                     = -1
    ActiveUsers                    = -1
    DisabledUsers                  = -1
    ServiceAccounts                = -1
    ServiceAccountsPwdNeverExpires = -1
    DisabledOver90Days             = -1
    ComputersTotal                  = -1
    ComputersStale90d               = -1
    ErrorFlag                       = 0
}

function Write-Status {
    $lines = foreach ($key in $results.Keys) { "$key=$($results[$key])" }
    $lines | Out-File -FilePath $statusFile -Encoding ASCII
}

function Get-Department {
    # Padrao de OU: Dominio > Empresa > Departamento > Usuarios (ou Computadores)
    # O departamento e a OU IMEDIATAMENTE ACIMA da OU "Usuarios" no caminho do objeto.
    # Ex: CN=Joao,OU=Usuarios,OU=Financeiro,OU=NomeEmpresa,DC=empresa,DC=local -> "Financeiro"
    param([string]$DistinguishedName)

    $ouParts = ($DistinguishedName -split ',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -like "OU=*" } |
        ForEach-Object { $_.Substring(3) }

    $usuariosIndex = -1
    for ($i = 0; $i -lt $ouParts.Count; $i++) {
        if ($ouParts[$i] -match '^Usu[aá]rios?$') {
            $usuariosIndex = $i
            break
        }
    }

    if ($usuariosIndex -ge 0 -and ($usuariosIndex + 1) -lt $ouParts.Count) {
        return $ouParts[$usuariosIndex + 1]
    }

    # Fallback: se nao encontrar a OU "Usuarios" no caminho (estrutura fora do padrao),
    # usa a OU imediata do objeto para nao perder o dado.
    if ($ouParts.Count -gt 0) {
        return $ouParts[0]
    }

    return "Sem-OU"
}

Import-Module ActiveDirectory -ErrorAction SilentlyContinue
if (-not (Get-Module ActiveDirectory)) {
    $results.ErrorFlag = 1
    Write-Status
    '{"data":[]}' | Out-File -FilePath $deptFile -Encoding UTF8
    exit 1
}

# ---- Coleta de usuarios --------------------------------------
try {
    $allUsers = Get-ADUser -Filter * -Properties Enabled, PasswordNeverExpires, DistinguishedName, whenChanged -ErrorAction Stop

    $serviceAccounts = $allUsers | Where-Object { $_.SamAccountName -match '^(svc-|srv-)' }
    $humanUsers      = $allUsers | Where-Object { $_.SamAccountName -notmatch '^(svc-|srv-)' }

    $results.TotalUsers    = ($humanUsers | Measure-Object).Count
    $results.ActiveUsers   = ($humanUsers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $results.DisabledUsers = ($humanUsers | Where-Object { $_.Enabled -eq $false } | Measure-Object).Count

    $results.ServiceAccounts = ($serviceAccounts | Measure-Object).Count
    $results.ServiceAccountsPwdNeverExpires = ($serviceAccounts | Where-Object { $_.PasswordNeverExpires -eq $true } | Measure-Object).Count

    $cutoff = (Get-Date).AddDays(-90)
    $results.DisabledOver90Days = ($humanUsers | Where-Object {
        $_.Enabled -eq $false -and $_.whenChanged -lt $cutoff
    } | Measure-Object).Count
} catch {
    $results.ErrorFlag = 1
}

# ---- Breakdown por departamento (apenas usuarios humanos) ----
$deptData = @()
try {
    $deptGroups = $humanUsers | Group-Object { Get-Department $_.DistinguishedName }
    foreach ($g in $deptGroups) {
        $active   = ($g.Group | Where-Object { $_.Enabled -eq $true }  | Measure-Object).Count
        $disabled = ($g.Group | Where-Object { $_.Enabled -eq $false } | Measure-Object).Count
        $deptData += [ordered]@{
            "{#DEPT}"     = $g.Name
            "{#ACTIVE}"   = "$active"
            "{#DISABLED}" = "$disabled"
            "{#TOTAL}"    = "$($g.Count)"
        }
    }
} catch {
    $results.ErrorFlag = 1
}

# ---- Coleta de computadores -----------------------------------
try {
    $allComputers = Get-ADComputer -Filter * -Properties LastLogonDate -ErrorAction Stop
    $results.ComputersTotal = ($allComputers | Measure-Object).Count
    $results.ComputersStale90d = ($allComputers | Where-Object {
        (-not $_.LastLogonDate) -or ($_.LastLogonDate -lt $cutoff)
    } | Measure-Object).Count
} catch {
    $results.ErrorFlag = 1
}

# ---- Gravar arquivos --------------------------------------------
Write-Status

$deptJson = @{ data = $deptData } | ConvertTo-Json -Depth 4 -Compress
$deptJson | Out-File -FilePath $deptFile -Encoding UTF8

if ($results.ErrorFlag -eq 1) { exit 2 } else { exit 0 }
