# ============================================================
# Check-ADIntegrity.ps1
# Validacao de integridade do Active Directory para Zabbix
#
# Codigos de retorno:
#   0 = Tudo OK
#   1 = Falha de replicacao AD (repadmin)
#   2 = Erro operacional / RPC / latencia
#   3 = DC com problema detectado pelo dcdiag
#   4 = SYSVOL nao compartilhado
# ============================================================

# ---- 1. Replicacao AD (repadmin /replsummary) ---------------
try {
    $replLines = repadmin /replsummary 2>&1
    $hasReplError = $false

    foreach ($line in $replLines) {
        # Captura linhas com formato: <DC>  X / Y  (X = falhas)
        if ($line -match "^\s+\S+\s+(\d+)\s*/\s*\d+") {
            if ([int]$matches[1] -gt 0) {
                $hasReplError = $true
                break
            }
        }
    }

    if ($hasReplError) {
        Write-Output 1
        exit
    }
} catch {
    Write-Output 1
    exit
}

# ---- 2. Erros operacionais / RPC / latencia -----------------
try {
    $replStr = $replLines | Out-String

    # Verifica falhas consecutivas no showrepl
    $showrepl = repadmin /showrepl 2>&1 | Out-String
    $hasOpError = (
        $replStr  -match "operational error|RPC Server Unavailable|error 58" -or
        $showrepl -match "consecutivefailures\s*:\s*[1-9]" -or
        $showrepl -match "Last attempt.*failed"
    )

    if ($hasOpError) {
        Write-Output 2
        exit
    }
} catch {
    Write-Output 2
    exit
}

# ---- 3. Saude do DC (dcdiag) --------------------------------
try {
    $dcdiag = dcdiag /test:advertising /test:netlogons /test:dns /test:replications 2>&1 | Out-String

    if ($dcdiag -match "failed|FAIL") {
        Write-Output 3
        exit
    }
} catch {
    Write-Output 3
    exit
}

# ---- 4. SYSVOL compartilhado --------------------------------
try {
    $shares = net share 2>&1 | Out-String

    if ($shares -notmatch "SYSVOL") {
        Write-Output 4
        exit
    }
} catch {
    Write-Output 4
    exit
}
# ---- 5. Verificar se Policies tem conteudo no SYSVOL -------
$domain = (Get-ADDomain).DNSRoot
$policies = Get-ChildItem "C:\WINDOWS\SYSVOL\sysvol\$domain\Policies" -ErrorAction SilentlyContinue

if ($null -eq $policies -or $policies.Count -eq 0) {
    Write-Output 5
    exit
}

# ---- Tudo OK ------------------------------------------------
Write-Output 0
