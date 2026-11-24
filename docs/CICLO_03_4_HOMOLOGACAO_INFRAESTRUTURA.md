# Ciclo 03.4 — Homologação da infraestrutura

**Projeto:** seleniumBlazerMeter — PoC Selenium Grid + Taurus  
**Ambiente de referência atual:** VM experimental `loadtester-lab` (Debian 13.6, ESXi 7.0 U2, 2 vCPU, 4 GB)  
**Objetivo:** tornar a arquitetura operacional, observável e reproduzível, com critérios verificáveis para futura implantação em ambiente de produção.

> **Estado:** preparação documental e inventário em andamento. Nenhuma campanha Taurus foi executada nesta retomada. A VM de 2 vCPU / 4 GB é laboratório de referência, não infraestrutura homologada para produção.

## 1. Princípios de execução e governança

1. Não alterar serviços, imagens, Compose, limites, redes, mounts, volumes ou configurações do host sem aprovação explícita.
2. Não remover nem podar volumes históricos ou backups.
3. Não matar processos zumbi, ocultar alertas ou flexibilizar verificações para obter aprovação artificial.
4. Não executar `run_pipeline.sh` nem Taurus sem autorização específica posterior.
5. Toda execução deve possuir identificador, diretório exclusivo de evidências, hashes dos arquivos, horários com fuso, exit code e snapshots antes/depois.
6. Uma campanha funcional bem-sucedida não comprova capacidade, segurança, escalabilidade ou prontidão para produção.
7. O estado real do runtime deve ser confrontado com a configuração versionada; não presumir equivalência a partir de nomes de arquivos ou labels Docker.

## 2. Sequência e estado das etapas

| Etapa | Escopo | Estado atual | Critério para avançar |
|---|---|---|---|
| E1 — Inventário e baseline | Consolidar ambiente, processos, recursos e lacunas | Parcialmente concluída | Fechar inventário e identificar divergências/lacunas |
| E2 — Arquitetura | Versões, serviços, limites, volumes, redes e mounts | Inventário documental parcial | Snapshot atual de `docker inspect` e comparação com Compose |
| E3 — Observabilidade | Dashboard, targets, métricas e coleta externa | Parcialmente concluída | Targets UP e coleta validada de filesystem/rede |
| D — Campanha controlada | Execução Taurus supervisionada | **Bloqueada — sem autorização** | Preflight revisado, limites de parada e autorização específica |
| E4 — Evidências | Relatórios Taurus, amostras, logs e métricas finais | Não iniciada | Campanha D concluída |
| E5 — Correlação | Linha do tempo e correlação de CPU, RAM, filesystem, rede e containers | Não iniciada | Evidências com relógios e intervalos coerentes |
| F — Avaliação/homologação | Critérios de aceite, limites, pendências e plano de produção | Não iniciada | Análise E4/E5 e decisão formal |

### 2.1 E1 — Inventário e baseline

Referências documentais:
- `docs/BASELINE_OPERACIONAL_2026-11-24.md`: arquitetura, divergências e snapshots históricos.
- `docs/DEBITOS_TECNICOS.md`: DT-001 e campanhas de diagnóstico.
- coleta E1.1 de 24/11/2026 às 14:27:50 -03:00: CPU, RAM, swap, PSI, Docker stats, Grid e targets Prometheus.
- coleta E1.2 complementar: processos com RSS elevado, `vmstat`, PSI e `iostat`.

Conclusões atuais:
- Grid estava pronto, com dois Nodes UP, um slot por Node e zero sessões ativas no snapshot E1.1.
- Os três targets Prometheus estavam UP.
- RAM disponível no E1.1 era aproximadamente 765 MiB; swap usada aproximadamente 1,2 GiB.
- E1.2 demonstrou pressão de memória/I/O pelo PSI e consumo relevante do Firefox/desktop; não demonstrou CPU continuamente saturada nem saturação persistente do dispositivo nas amostras.
- DT-001 permanece aberto e a auditoria ambiental anteriormente retornou código 1 pela presença dos zombies.

Lacunas E1: falta uma coleta única e temporalmente sincronizada imediatamente antes da campanha; faltam inventário atualizado de filesystem/inodes, tráfego de rede e throughput, identificação completa de processos concorrentes e captura de evidências externas com relógios sincronizados.

### 2.2 E2 — Auditoria de arquitetura e arquivos

Antes de qualquer execução, conferir e registrar:
- `run_pipeline.sh`: conteúdo integral, permissões, dependências, fluxo, comandos disparados, caminhos de saída e comportamento em falha.
- `taurus-esxi-poc.yml`: executor, cenário, concorrência, ramp-up, duração, reporting e caminhos referenciados.
- `test_esxi.py`: URL alvo, operações realizadas, timeouts, asserts, dependências e efeitos colaterais.
- diretórios de evidências: conteúdo, permissões, espaço livre, nomenclatura e risco de sobrescrita.
- `docker-compose.yml` e `prometheus.yml`: comparação com configuração efetiva do runtime.
- versões e digests das imagens, variáveis de ambiente não secretas, limites, healthchecks, redes, mounts e volumes.

A auditoria deve determinar exatamente o que será executado e onde os artefatos serão gravados. Não executar o pipeline nesta etapa.

**Critério E2:** produzir manifesto de execução com SHA-256 dos arquivos, comandos exatos, working directory, pré-requisitos, efeitos esperados e caminhos de evidência. Segredos devem ser omitidos ou mascarados.

### 2.3 E3 — Preparação da observabilidade

Preparar o dashboard **PoC - Selenium Grid & Infraestrutura — Fase 03**:
- selecionar intervalo temporal que cubra baseline, campanha e pós-campanha;
- validar atualização e timestamps;
- preservar evidência dos painéis e consultas utilizados;
- confirmar Prometheus, Node Exporter e cAdvisor como targets UP;
- validar disponibilidade e cardinalidade das métricas necessárias.

A coleta externa deve complementar as séries Prometheus, sobretudo onde a configuração atual do cAdvisor desabilita métricas.

**Filesystem:** registrar espaço total/usado/livre, percentual e inodes; observar I/O e latência por dispositivo quando disponíveis.

**Rede:** registrar bytes/packets RX/TX, erros/drops, throughput por intervalo, interface e conexões relevantes. Identificar origem e destino do tráfego de teste sem expor credenciais.

**Containers:** registrar CPU, memória, PIDs, reinícios, estado, limites efetivos e eventos; correlacionar com métricas do host.

**Critério E3:** evidência de targets saudáveis, dashboard pronto, consultas validadas e coleta externa testada sem iniciar Taurus.


### 2.4 Etapa A — auditoria estática inicial dos artefatos (24/11/2026)

Arquivos lidos diretamente da branch `main`; nenhum script foi executado.

| Artefato | SHA do blob | Resultado da inspeção |
|---|---|---|
| `run_pipeline.sh` | `8244deedbea9475a543e765d54cd72b6662deb47` | Fluxo e comandos identificados; possui auditoria pré/pós e executa `bzt` |
| `taurus-esxi-poc.yml` | `5e78d3dbe8e9c2ad63353b21117fc667ddf583eb` | Selenium/pytest, concorrência 2, ramp-up 20s, hold-for 3m, console e final-stats/percentis |
| `test_esxi.py` | `6a75c911b8ae4b0ead5d5ff5c24256e1f18e48bf` | Remote WebDriver no Hub local; acessa `https://10.1.100.102/ui/`; page-load timeout 45s, espera explícita 15s, pausa fixa 1s e assert de presença de “VMware” |
| `check_poc_environment.sh` | `6eb5637d3ac71c585e5c4ffb51ba26b42fb2da4b` | Verifica host/Docker/Grid/Nodes/zombies/exporters/targets e conectividade ESXi; não coleta filesystem/inodes nem tráfego/rede quantitativa |
| `pytest.ini` | `3755cd7fd02b0f85ef5fb5d209722d271d5d24f3` | Declara marker `pae_manual_auth`; o teste atual não o utiliza |

**Comportamento crítico do pipeline:** `run_pipeline.sh` usa `set -Eeuo pipefail` e chama `check_poc_environment.sh` antes de criar o diretório de artefatos e antes de definir `POST_AUDIT_REQUIRED=1`. Como a auditoria atual detecta um zombie em cada Chrome Node e retorna código 1, o Bash encerra o pipeline nessa chamada; portanto, no estado observado, a execução não chega ao comando `bzt`. O bloqueio é intencional e protege a campanha. Não contornar nem enfraquecer esse gate para iniciar Taurus.

Outras observações:
- O diretório `artifacts/` é criado dinamicamente pelo pipeline; não foi encontrado como diretório versionado na raiz consultada.
- O diretório `evidence/` não existe na árvore atual da branch `main`. Havia referência anterior a `evidence/` como conteúdo não rastreado no checkout local; seu conteúdo local não foi lido nesta auditoria remota e não deve ser presumido.
- A árvore da branch contém `dashboards/` com subdiretórios `exports/`, `generated/` e `originals/`; a existência do dashboard exato solicitado e seu estado atual ainda precisam ser verificados dentro desses diretórios/Grafana.
- O pipeline valida que exista exatamente um arquivo `*.ldjson`, que as amostras estejam `PASSED` e que não restem sessões no Grid. A auditoria pós-carga roda pelo trap de saída somente depois que `POST_AUDIT_REQUIRED` passa a 1.
- O pipeline não implementa monitoramento contínuo de CPU/RAM/PSI/filesystem/rede, limiares automáticos de interrupção ou captura externa sincronizada. A supervisão humana e a coleta complementar continuam obrigatórias.
- O teste utiliza `--ignore-certificate-errors` e `accept_insecure_certs=True`; isso é aceitável apenas como decisão explícita de laboratório. Não deve ser transportado para produção sem avaliação de TLS e confiança de certificados.
- A verificação de conteúdo `"VMware"` é um assert funcional simples; não mede por si só latência de usuário, disponibilidade de API, throughput ou capacidade de produção.

**Resultado da Etapa A:** leitura estática dos três artefatos principais e do script de auditoria concluída. A etapa A permanece **parcial**, pois falta conferir os diretórios de evidências locais, inventariar integralmente os exports do dashboard e validar permissões/dependências no host real. A campanha Taurus permanece bloqueada pelo gate de auditoria e sem autorização específica.

## 3. D — Campanha controlada (bloqueada)

A campanha só poderá começar após:
1. Etapas A/E2, B/E1 e C/E3 revisadas e consideradas suficientes.
2. Hashes dos quatro artefatos de execução registrados.
3. Baseline sincronizada e evidências prévias salvas.
4. Estado do Grid e dos três targets confirmado.
5. Critérios de interrupção definidos e aceitos.
6. Operador acompanhando a execução e capaz de interrompê-la.
7. Autorização específica e explícita do usuário para aquela execução.

### 3.1 Critérios de interrupção a definir antes da autorização

Não adotar limites numéricos arbitrários. Definir com base no comportamento de baseline e nos limites do host:
- RAM disponível e tendência de crescimento; PSI de memória; atividade de swap e OOM;
- PSI CPU, load e perda de capacidade de resposta do host;
- PSI I/O, espaço/inodes e degradação de filesystem;
- erros, drops ou perda de conectividade de rede;
- readiness do Hub, estado dos Nodes, slots e sessões;
- reinícios, unhealthy, OOMKilled ou degradação de containers;
- erro HTTP, latência anormal ou impacto no endpoint ESXi;
- qualquer impacto no uso operacional do host.

Interromper de forma controlada ao atingir qualquer limite aprovado ou diante de comportamento não previsto. Registrar horário, indicador, ação e responsável. Não continuar apenas para completar os três minutos previstos.

## 4. E4/E5 — Pós-campanha e correlação

Após autorização e execução:
- preservar saída integral do Taurus, exit code, logs, relatório, CSV de amostras e percentis;
- coletar snapshots finais do host, filesystem, rede, containers, Grid e Prometheus;
- exportar evidências Grafana com janela temporal explícita;
- registrar início/fim e fuso horário;
- correlacionar métricas em uma linha do tempo única;
- identificar lacunas, atrasos de scrape, séries ausentes e diferenças entre relógios;
- relacionar erros Taurus com sessões, Nodes, recursos e resposta do endpoint;
- registrar qualquer intervenção ou interrupção.

Não calcular percentis a partir de médias de painel. Usar amostras/relatório primário do Taurus e documentar população, unidade e janela.

## 5. F — Critérios de avaliação

A campanha experimental poderá ser considerada tecnicamente analisável se:
- Taurus tiver exit code e artefatos íntegros;
- Grid permanecer dentro dos critérios operacionais acordados;
- séries de CPU, memória, filesystem, rede e containers cobrirem a janela;
- timestamps forem correlacionáveis;
- erros e interrupções estiverem explicados ou registrados como inconclusivos.

A homologação para produção exige mais que a campanha atual. Critérios mínimos adicionais:
1. **Reprodutibilidade:** implantação em ambiente limpo a partir de artefatos versionados, sem depender de estado manual não documentado.
2. **Configuração reconciliada:** runtime e repositório equivalentes ou divergências explicitamente parametrizadas.
3. **Imagens e dependências:** versões e digests fixados, cadeia de suprimento e atualização controlada.
4. **Segurança:** segredos fora do repositório, TLS/autenticação adequados, menor privilégio, rede segmentada e política de logs.
5. **Capacidade:** campanhas graduais, concorrência e duração justificadas por SLOs, margem de recursos e comportamento do destino.
6. **Resiliência:** healthchecks, recuperação, limites, tratamento de processos filhos/zombies e testes de falha.
7. **Observabilidade:** métricas, logs, alertas, retenção, dashboards e procedimento de diagnóstico.
8. **Operação:** backup/restore, atualização/rollback, runbooks, ownership e resposta a incidentes.
9. **Aceite:** critérios quantitativos definidos antes dos testes e evidências repetíveis em mais de uma execução.

A VM experimental atual não deve ser declarada pronta para produção com base nos resultados de uma única campanha de dois usuários virtuais.

## 6. Próximas ações, em ordem

1. **A — Auditoria dos arquivos:** obter e revisar `run_pipeline.sh`, `taurus-esxi-poc.yml`, `test_esxi.py` e diretórios de evidência. Nenhuma execução.
2. **B — Baseline sincronizada:** nova coleta de host, memória, PSI, swap, filesystem, rede, Docker stats, Grid e targets.
3. **C — Observabilidade:** preparar dashboard e testar coleta externa de filesystem/rede.
4. Definir critérios de parada e revisar o preflight.
5. Solicitar autorização específica para D; sem ela, não executar.
6. Executar D sob supervisão; depois E4/E5 e F.

**Ponto de retomada:** Etapa A do roteiro operacional, começando pela auditoria estática dos quatro artefatos. Nenhum Taurus nem `run_pipeline.sh` será iniciado sem autorização.

---
