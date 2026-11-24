# Baseline operacional e matriz de divergências — 24/11/2026

## 1. Finalidade e regra de governança

Este documento registra o estado operacional observado no host `loadtester-lab` em 24/11/2026 e o compara com a configuração versionada na branch `main) do repositório.

**Regra principal da PoC:** tornar a arquitetura operacional e reproduzível em escala maior, com vistas à operação em produção. A VM atual é um ambiente experimental de referência; seus limites não devem ser tratados como dimensionamento de produção.

A baseline de runtime aqui registrada foi aceita como referência experimental para a próxima campanha Taurus. Isso não significa que todas as configurações estejam reconciliadas, que o ambiente tenha sido homologado para produção ou que a capacidade acima de dois usuários virtuais esteja comprovada.

Este documento é uma fotografia histórica. Valores dinâmicos, estados de containers, métricas e disponibilidade devem ser novamente coletados antes de cada campanha.

## 2. Identificação do ambiente

| Item | Valor observado |
|---|---|
| Host | `loadtester-lab` |
| Sistema operacional | Debian GNU/Linux 13.6 (trixie) |
| Virtualização | VMware ESXi 7.0 U2 |
| CPU virtual | 2 vCPUs |
| Memória configurada | 4 GB |
| RAM total reconhecida | aproximadamente 3,8 GiB |
| IP do host | `10.1.100.27` |
| Interface | `ens160` |
| Docker Engine | 26.1.5+dfsg1 |
| Docker Compose | 2.26.1-4 |
| Taurus | 1.17.1 |
| Python | 3.13 |
| Projeto Compose identificado nos labels | `selenium-grid` |
| Rede Docker | `e03_selenium-grid` |

## 3. Estado observado do runtime

### 3.1 Containers

Na coleta de 24/11/2026, os sete containers abaixo estavam em execução:

| Container | Imagem observada | Estado/observação |
|---|---|---|
| `node-exporter` | `prom/node-exporter:v1.8.2` | Em execução; modo de rede host |
| `cadvisor` | `gcr.io/cadvisor/cadvisor:v0.49.1` | Em execução; healthy |
| `prometheus` | `prom/prometheus:v2.54.1` | Em execução; API healthy/ready |
| `grafana` | `grafana/grafana:11.2.0` | Em execução |
| `selenium-hub` | `selenium/hub:4.48.0-20260905` | Em execução; healthy |
| `chrome-node-1` | `selenium/node-chrome:4.48.0-20260905` | Em execução |
| `chrome-node-2` | `selenium/node-chrome:4.48.0-20260905` | Em execução |

Todos os containers apresentavam label de projeto Compose `selenium-grid`. Os labels apontam para o diretório de trabalho `/home/edsonc` e para o arquivo `/home/edsonc/docker-compose.yml` na criação dos containers. Esses labels registram a origem declarada no momento da criação, mas não provam que o conteúdo atual desse arquivo seja idêntico ao conteúdo usado naquela criação.

### 3.2 Selenium Grid

- Endpoint consultado: `http://127.0.0.1:4444/status`.
- `ready=true`.
- Dois Nodes registrados e com disponibilidade `UP`.
- Um slot por Node.
- Duas vagas livres no momento da coleta.
- Sessões ativas: zero. A contagem correta considera slots cujo campo `session` não é nulo; a quantidade de slots não representa sessões em execução.

### 3.3 Prometheus e alvos

- `/-/healthy`: HTTP 200.
- `/-/ready`: HTTP 200.
- Três alvos ativos e todos `health=up`: Prometheus, Node Exporter e cAdvisor.
- Configuração efetivamente carregada: scrape interval global de 10 segundos.
- Prometheus target: `prometheus:9090`.
- Node Exporter target: `10.1.100.27:9100`.
- cAdvisor target: `cadvisor:8080`, com scrape timeout de 9 segundos.
- Retenção efetiva: 2 horas.
- `web.enable-lifecycle=false`.

A configuração carregada foi consultada pela API `/api/v1/status/config`; os argumentos e flags foram conferidos por `docker inspect`, `ps` dentro do container e `/api/v1/status/flags`.

### 3.4 Rede e mounts

| Componente | Estado observado |
|---|---|
| Rede de Prometheus | `e03_selenium-grid`, IP `172.21.0.7` |
| Rede de cAdvisor | `e03_selenium-grid`, IP `172.21.0.2` |
| Node Exporter | `NetworkMode=host` |
| Configuração Prometheus montada | `/home/edsonc/prometheus.yml:/etc/prometheus/prometheus.yml:ro` |
| Dados Prometheus | Volume `selenium-grid_prometheus_data` em `/prometheus` |
| Dados Grafana | Volume `selenium-grid_grafana_data` em `/var/lib/grafana` |

O arquivo externo `/home/edsonc/prometheus.yml` e o arquivo versionado no momento da inspeção anterior tinham o mesmo SHA-256, mas eram caminhos distintos. O SHA registrado para o arquivo externo era `5b08a98dac400ed3c4088ffdf4c6825244a92c8c9abbc47ac5aa904f3a29a285`. O conteúdo efetivamente carregado no runtime é a referência para a campanha, não a suposição de que o bind mount aponta para o caminho do repositório.

### 3.5 Limites de recursos observados

| Container | Limite efetivo observado |
|---|---:|
| cAdvisor | 0,25 CPU / 200 MiB |
| Prometheus | Não foi identificada divergência de limite no diagnóstico resumido; confirmar por nova inspeção antes de outra campanha |
| Node Exporter | 0,15 CPU / 64 MiB conforme configuração/referência previamente inspecionada; reconfirmar no snapshot pré-campanha |
| Outros serviços | Usar o snapshot de `docker inspect` da campanha como evidência primária; não inferir limites efetivos apenas pelo YAML versionado |

**Divergência confirmada para cAdvisor:** o container em execução tinha `NanoCpus=250000000` (0,25 CPU) e memória de `209715200` bytes (200 MiB). O Compose versionado declara 0,10 CPU e 128 MiB.

## 4. Condição do host no snapshot de 24/11/2026

Horário informado para a coleta: 08:48:55, fuso `-03:00`.

| Indicador | Valor observado |
|---|---:|
| Load average (1 / 5 / 15 min) | 1,43 / 0,80 / 0,35 |
| RAM total | 3,8 GiB |
| RAM usada | 3,2 GiB |
| RAM disponível | 631 MiB |
| Swap total | aproximadamente 2,6 GiB |
| Swap usada | aproximadamente 1,2 GiB |
| Disco raiz | 47 GiB total; 21 GiB usados; 24 GiB livres (46%) |
| Inodes usados | 12% |
| OOM kills observados em `vmstat` | 0 |

Processos com RSS elevado no snapshot incluíam Isolated Web Co (~752 MiB), Firefox ESR (~358 MiB), gnome-text-edit (~333 MiB), gnome-shell (~208 MiB) e gnome-software (~163 MiB). Esses processos fazem parte do contexto de uso do host e podem competir por recursos com a campanha.

### 4.1 PSI e interpretação

| Pressão | avg10 | avg60 | avg300 |
|---|---:|---:|---:|
| CPU — some | 11,20 | 15,82 | 12,99 |
| Memória — some | 0,00 | 0,38 | 0,72 |
| Memória — full | 0,00 | 0,23 | 0,47 |
| I/O — some | 0,10 | 1,43 | 2,58 |
| I/O — full | 0,06 | 0,83 | 1,80 |

PSI representa tempo de contenção/pressão, não percentual de utilização direta do recurso. Os valores históricos de memória e I/O indicam períodos de pressão; o `avg10=0` para memória no instante da coleta não elimina a existência de pressão em janelas anteriores. Swap utilizada e PSI devem ser acompanhados durante a campanha. Zero OOM kills até o snapshot não garante que não ocorrerão sob carga adicional.

O destino ESXi `https://10.1.100.102/ui/` respondeu HTTP 200 em aproximadamente 0,144 segundo no teste de conectividade do snapshot. Esse tempo é uma verificação pontual, não uma medição de desempenho representativa.

## 5. Matriz de divergências: runtime versus branch main

Os valores de repositório abaixo foram conferidos nos arquivos da branch `main` durante a preparação desta revisão. Os hashes identificam os blobs lidos:

- `docker-compose.yml`: `6a1c7345863f68cc03ba54d927c93f4720f034a9`
- `prometheus.yml`: `3463ddcff2810e7cbfebbbb15943c17e4a50876b`
- Branch de referência: `main`

| Área | Runtime observado | Repositório `main` | Avaliação |
|---|---|---|---|
| cAdvisor CPU | 0,25 CPU | 0,10 CPU | Divergência confirmada |
| cAdvisor memória | 200 MiB | 128 MiB | Divergência confirmada |
| Node Exporter rede | host | bridge `e03_selenium-grid` | Divergência confirmada |
| Node Exporter target Prometheus | `10.1.100.27:9100` | `node-exporter:9100` | Divergência confirmada |
| Scrape interval global | 10s | 15s | Divergência confirmada |
| cAdvisor scrape timeout | 9s | não declarado (default global do Prometheus) | Divergência de configuração |
| Prometheus retenção | 2h | 2h | Alinhado |
| Prometheus lifecycle | desabilitado | argumento não declarado | Alinhado com default observado |
| Bind mount do YAML | `/home/edsonc/prometheus.yml` | `./prometheus.yml` | Caminhos diferentes |
| Rede Prometheus | `e03_selenium-grid` | `e03_selenium-grid` | Alinhado |
| Volume Prometheus | `selenium-grid_prometheus_data` | volume Compose `prometheus_data` sob projeto/volume atual | Nome efetivo deve ser preservado e documentado |
| Projeto Compose | label `selenium-grid` | `name: seleniumblazermeter` | Divergência de identidade/projeto |
| cAdvisor métricas desabilitadas | inclui `advtcp` além de disk/diskIO/network/tcp/udp/percpu/sched/process | não inclui `advtcp` | Divergência de argumentos |

**Observação sobre o arquivo Compose externo:** o diagnóstico anterior identificou `/home/edsonc/docker-compose.yml` com hash `b55d313ac6787786fa22451312cedb3c092b5721d73187a9009e15da936ffb15`. Seu conteúdo atual indicava alguns parâmetros diferentes do runtime, como retenção `2d`, lifecycle habilitado e Node Exporter em bridge. Portanto, não deve ser tratado como fonte definitiva do estado de criação ou da execução atual. Labels Docker informam o caminho de origem registrado, não o histórico integral do conteúdo do arquivo.

## 6. Arquivos e dados que devem ser preservados

### 6.1 Volumes

Volumes identificados e que não devem ser removidos, podados ou recriados como parte desta etapa:

- `selenium-grid_prometheus_data`
- `selenium-grid_grafana_data`
- `edsonc_prometheus_data`
- `poc-loadtester_grafana_data`
- `poc-loadtester_prometheus_data`
- dois volumes históricos com nomes hash, ainda não atribuídos com segurança.

Não executar `docker volume prune`, `docker system prune --volumes`, remoção manual de volumes ou recriação destrutiva de serviços.

### 6.2 Backups locais

Preservar os seguintes backups reportados no repositório de trabalho:

- `check_poc_environment.sh.bak-fase03-04-20261119-162654`
- `docker-compose.yml.bak-fase03-04`
- `docker-compose.yml.bak-network-host-20261119-151311`
- `docker-compose.yml.bak-node-exporter-20261119-150233`
- `prometheus.yml.bak-fase03-04`
- `prometheus.yml.bak-network-host-20261119-151311`

A existência e o conteúdo desses arquivos devem ser conferidos no host antes de qualquer operação local. Esta documentação não os altera.

## 7. Campanha Taurus: referência de execução e segurança operacional

O manifesto versionado `taurus-esxi-poc.yml` define:

| Parâmetro | Valor |
|---|---|
| Executor | Selenium |
| Runner | pytest |
| Concorrência | 2 |
| Ramp-up | 20s |
| Hold-for | 3m |
| Script | `test_esxi.py` |
| Reporting | console + final-stats |
| Percentis | habilitados |

O teste usa Remote WebDriver no Grid local e acessa a interface de gerenciamento do ESXi em modo de verificação funcional. A execução gera tráfego real contra o destino.

### 7.1 Supervisão obrigatória

O `run_pipeline.sh` foi caracterizado como auditoria pré e pós-execução; ele não implementa monitoramento contínuo nem interrupção automática da campanha por pressão de recursos. Portanto:

- acompanhar CPU, memória disponível, swap, PSI, I/O e estado dos containers durante toda a campanha;
- acompanhar readiness do Grid, disponibilidade dos dois Nodes e sessões ativas;
- acompanhar os três targets Prometheus;
- interromper manualmente a campanha se houver degradação relevante, perda de readiness, indisponibilidade de Node, risco de esgotamento de memória ou impacto operacional no host/destino;
- preservar logs e horários de qualquer anomalia;
- não executar campanhas progressivas de concorrência maior antes da análise desta execução.

Os limites de interrupção devem ser definidos antes de campanhas de maior intensidade. Esta baseline não estabelece um SLA nem limites universais de produção.

### 7.2 Critério de sucesso da execução

A campanha somente deve ser considerada tecnicamente concluída quando:
1. Taurus terminar e seu exit code for registrado;
2. relatório integral e arquivo de amostras forem preservados;
3. percentis e taxa de falha forem extraídos do relatório/artefato primário;
4. snapshots de host, Grid, containers e Prometheus forem coletados antes e depois;
5. anomalias e intervenções manuais forem registradas;
6. resultados forem correlacionados com a janela temporal da campanha.

A aprovação funcional de uma sessão ou a disponibilidade dos targets não equivale à aprovação de capacidade.

## 8. Evidências da próxima campanha — checklist

Criar um diretório exclusivo por execução, com timestamp e identificador único. Preservar, no mínimo:

- [ ] hash SHA-256 de `docker-compose.yml`, `prometheus.yml`, `taurus-esxi-poc.yml` e `test_esxi.py`;
- [ ] `docker compose ps` e `docker inspect` dos sete containers;
- [ ] argumentos, limites de CPU/memória, mounts, redes e labels;
- [ ] `/api/v1/status/config`, `/api/v1/status/flags` e `/api/v1/targets` do Prometheus;
- [ ] resposta integral de `http://127.0.0.1:4444/status`;
- [ ] CPU, memória, swap, PSI, load average, disco e processos do host antes/depois;
- [ ] métricas cAdvisor/Prometheus no início, durante e após a campanha;
- [ ] saída integral do Taurus, exit code, CSV de amostras e estatísticas;
- [ ] horários de início/fim e fuso horário;
- [ ] observações sobre Firefox, navegador do operador e outras atividades concorrentes;
- [ ] eventos, alertas, intervenções e motivo de eventual interrupção.

Os artefatos devem ser somente adicionados ao repositório após revisão de dados sensíveis, credenciais, tokens, cookies, IPs ou informações operacionais que não devam ser publicados.

## 9. Limites de interpretação e conclusões permitidas

Com os dados disponíveis, é possível afirmar:

- o Grid estava pronto, com dois Nodes disponíveis e sem sessões ativas no snapshot;
- Prometheus estava pronto e os três alvos de scraping estavam saudáveis;
- o runtime e o Compose versionado não eram equivalentes em diversos parâmetros;
- o host apresentava memória disponível limitada, swap utilizada e histórico de pressão de CPU/memória/I/O no PSI;
- o snapshot não registrava OOM kills;
- o ambiente estava operacional para uma campanha controlada, sujeita a supervisão.

Não é possível afirmar, com esta baseline:

- capacidade máxima ou sustentável da arquitetura;
- comportamento sob concorrência superior a dois usuários;
- ausência de gargalos durante a campanha;
- dimensionamento necessário para produção;
- equivalência reproduzível entre runtime e repositório;
- cobertura integral de observabilidade do host, Grid, ESXi e aplicação alvo.

## 10. Próximos passos

1. Usar esta baseline como referência documental da campanha controlada com os parâmetros Taurus já definidos.
2. Executar a campanha somente após auditoria prévia e com supervisão ativa.
3. Preservar as evidências listadas na seção 8.
4. Analisar os resultados e localizar o primeiro gargalo observável.
5. Em etapa separada, reconciliar Compose, Prometheus, redes, mounts, volumes e limites.
6. Criar procedimento de implantação reproduzível e validá-lo em ambiente limpo, sem remover os volumes ou backups históricos.
7. Planejar campanhas graduais de escala apenas após definir critérios de parada, observabilidade e proteção do ambiente.

---

**Status deste documento:** baseline documental preparada a partir dos diagnósticos fornecidos e dos arquivos lidos na branch `main`. Não houve alteração de containers, serviços, volumes, configurações de runtime ou arquivos da branch `main`. A campanha Taurus subsequente ainda depende de auditoria pré-execução e supervisão.
