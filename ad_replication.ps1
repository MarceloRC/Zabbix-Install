$rep = repadmin /replsummary 2>&1 | Out-String

# Falha REAL: qualquer linha com " / " que NÃO seja 0 /
if ($rep -match "^\s+\S+\s+\d+\s*/\s*\d+" -and $rep -notmatch "^\s+\S+\s+0\s*/\s*\d+") {
    Write-Output 1
    exit
}

# Erros operacionais (RPC / 58), mas sem falha de replicação
if ($rep -match "operational errors|RPC| 58 ") {
    Write-Output 2
    exit
}

# Tudo OK
Write-Output 0
