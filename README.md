# Zabbix Agent2 MSP Deployment

Script automatizado para **instalação e configuração padronizada do Zabbix Agent2 em servidores Windows**.

Este projeto foi criado para ambientes **MSP / NOC**, permitindo que servidores sejam adicionados ao monitoramento em poucos segundos com configuração consistente.

---

# Objetivo

Automatizar completamente o processo de:

* download do Zabbix Agent2 LTS
* instalação silenciosa
* configuração padronizada
* download de scripts auxiliares
* configuração de monitoramentos adicionais

Tudo com **um único script PowerShell**.

---

# Estrutura do Repositório

```
zabbix-msp
│
├── install
│   install_zabbix_agent_msp.ps1
│
├── scripts
│   windows_update_check.ps1
│   ad_replication.ps1
│
└── README.md
```

| Pasta   | Descrição                                  |
| ------- | ------------------------------------------ |
| install | Script principal de instalação             |
| scripts | Scripts auxiliares monitorados pelo Zabbix |
| README  | Documentação do projeto                    |

---

# O que o Script Faz

O script `install_zabbix_agent_msp.ps1` executa automaticamente:

1. Download do **Zabbix Agent2 LTS**
2. Instalação silenciosa
3. Criação da pasta `C:\Scripts`
4. Download dos scripts de monitoramento
5. Detecção automática do **Gateway da rede**
6. Configuração do arquivo `zabbix_agent2.conf`
7. Configuração do **Hostname FQDN**
8. Ativação de `UnsafeUserParameters`
9. Reinício do serviço do agente

Após executar o script o servidor já estará pronto para ser monitorado.

---

# Configuração Automática

O script detecta automaticamente:

### Gateway da rede

Usado como servidor Zabbix.

Exemplo:

```
Server=192.168.1.1
```

### Hostname FQDN

Exemplo:

```
srv-dc01.empresa.local
```

---

# Monitoramentos Incluídos

## Windows Updates

Script:

```
windows_update_check.ps1
```

Itens monitorados:

| Item                    | Descrição                  |
| ----------------------- | -------------------------- |
| windows.update.total    | Total de updates pendentes |
| windows.update.critical | Updates críticos           |
| windows.update.security | Updates de segurança       |
| windows.update.reboot   | Necessidade de reboot      |
| windows.update.service  | Serviço Windows Update     |
| windows.update.days     | Dias desde último update   |

---

## Active Directory Replication

Script:

```
ad_replication.ps1
```

Item monitorado:

```
ad.replication.status
```

Retornos:

| Valor | Significado         |
| ----- | ------------------- |
| 0     | Replicação OK       |
| 1     | Falha de replicação |
| 2     | Erro operacional    |

---

# Requisitos

* Windows Server 2012 ou superior
* PowerShell 5+
* Permissão de administrador
* Acesso à internet para download do agente

---

# Como Instalar

Executar PowerShell como **Administrador**.

Rodar o script:

```
powershell -ExecutionPolicy Bypass -File install_zabbix_agent_msp.ps1
```

---

# Instalação Remota (Recomendado)

Também é possível executar diretamente do Git:

```
irm https://SEU_REPOSITORIO/install/install_zabbix_agent_msp.ps1 | iex
```

---

# Arquivos Instalados

```
C:\Program Files\Zabbix Agent 2
C:\Scripts
```

Scripts instalados:

```
C:\Scripts\windows_update_check.ps1
C:\Scripts\ad_replication.ps1
```

---

# Configuração do Agent

Arquivo:

```
C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf
```

Configurações principais:

```
Server=<Gateway da rede>
Hostname=<FQDN do servidor>
UnsafeUserParameters=1
```

---

# Reinício do Serviço

Após configuração o serviço é reiniciado automaticamente:

```
Zabbix Agent 2
```

---

# Boas Práticas para MSP

Recomenda-se utilizar:

* Template dedicado no Zabbix
* Proxy Zabbix por cliente
* Monitoramento de patching centralizado

---

# Segurança

O script cria backup automático do arquivo de configuração:

```
zabbix_agent2.conf.bak
```

---

# Licença

Uso livre para ambientes de monitoramento baseados em Zabbix.

---

# Autor

Projeto desenvolvido para automação de ambientes MSP e NOC.
