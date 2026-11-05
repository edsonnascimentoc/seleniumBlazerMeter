# seleniumBlazerMeter

PoC de geração de carga funcional com **Taurus CLI 1.17.1 + Selenium 4 + Selenium Grid 4 + Chrome**, com Docker e observabilidade por Prometheus/Grafana. O foco é medir o tempo de navegação/renderização DOM da aplicação VMware ESXi, caracterizar o comportamento com dois browsers concorrentes e auditar o ciclo de vida dos processos nos Chrome Nodes.

## Arquitetura

```mermaid
flowchart LR
    A["Taurus CLI 1.17.1\nloadtester-lab"] --> B["pytest runner\ntest_esxi.py"]
    B -->|W3C Remote WebDriver| C["Selenium Hub :4444"]
    C --> D["Chrome Node 1\n1 sessão"]
    C --> E["Chrome Node 2\n1 sessão"]
    D --> F["VMware ESXi\n10.1.100.102"]
    E --> F
    G["Node Exporter :9100"] --> H["Prometheus :9090"]
    I["cAdvisor :8080"] --> H
    H --> J["Grafana :3000"]
```

- **Taurus**: orquestra a campanha, controla concorrência, ramp-up e duração, e agrega estatísticas.
- **pytest**: runner explícito do Taurus para executar o script Python; o teste é implementado como `unittest.TestCase`, compatível com descoberta pelo pytest.
- **Selenium WebDriver W3C**: cria sessões remotas no endpoint canônico do Grid.
- **Selenium Hub**: distribui sessões pelos Nodes disponíveis.
- **Chrome Nodes**: executam o Chrome headless; cada Node aceita uma sessão simultânea (`SE_NODE_MAX_SESSIONS=1`).
- **Docker Compose**: mantém os serviços na rede `e03_selenium-grid`; `init: true` nos Nodes faz o `docker-init` atuar como PID 1 e recolher processos filhos.
- **Node Exporter/cAdvisor → Prometheus → Grafana**: coletam e apresentam métricas do host e dos containers. O arquivo `prometheus.yml` configura os três alvos de scraping: `node-exporter:9100`, `cadvisor:8080` e `prometheus:9090`.

Caminho de carga: `Taurus → pytest → Selenium WebDriver → Selenium Hub → Chrome Node → Chrome → ESXi`.

## Ambiente homologado

| Item | Valor |
|---|---|
| Host de execução | `loadtester-lab` |
| Sistema operacional | Debian GNU/Linux 13 (trixie) |
| CPU / memória | 2 vCPUs / 3,8 GiB RAM (relato do host) |
| Taurus | 1.17.1 |
| Aplicação alvo | `https://10.1.100.102/` |
| Grid | Selenium 4, Hub + 2 Chrome Nodes |
| Concorrência | 2 usuários virtuais / 2 sessões |
| Estratégia de carregamento | `page_load_strategy = "eager"` |
| Janela | 04/11/2026, 11:32:06–11:35:48 |
| Duração informada | 03min27s |
| Exit code Taurus | `0` |

> **Nota sobre a duração:** 11:32:06–11:35:48 corresponde aritmeticamente a **3min42s**, enquanto o dossiê informa **3min27s**. Esta revisão não escolhe um dos valores sem o log original do Taurus. Para análises temporais, usar o timestamp do log como fonte primária e corrigir este registro após conferência.

## Recursos e contenção da VM

A VM de referência possui **2 vCPUs e 4 GB de RAM**. Os limites individuais de CPU declarados no Compose somam **2,25 vCPU** (node-exporter 0,15; cAdvisor 0,10; Prometheus 0,30; Grafana 0,20; Hub 0,30; Chrome Node 1 0,60; Chrome Node 2 0,60). Esses valores são **limites máximos individuais, não reservas dedicadas**; o Docker pode compartilhar CPU e haverá contenção quando a demanda simultânea superar a capacidade da VM. Isso é uma característica do ambiente PoC, não uma alegação de capacidade para cargas maiores.

### Memória compartilhada do Chrome

O Compose configura `shm_size: 512mb` em cada Chrome Node. O script Selenium também usa `--disable-dev-shm-usage`, que instrui o Chrome a evitar o `/dev/shm` convencional e utilizar um diretório temporário alternativo. Portanto, o valor de `shm_size` não deve ser interpretado isoladamente como a memória efetivamente utilizada pelo navegador. A configuração é mantida como parte do ambiente reportado; alterações devem ser avaliadas por nova execução funcional.

## Resultado homologado — campanha de 04/11/2026

| Métrica | Resultado |
|---|---:|
| Amostras (samples) | **63** |
| Taxa de sucesso | **100,00%** |
| Falhas | **0,00%** |
| Tempo médio | **6,239 s** |
| Tempo mínimo | **3,110 s** |
| P50 / mediana | **5,840 s** |
| P90 | **8,120 s** |
| P95 | **9,450 s** |
| P99 | **11,210 s** |
| Tempo máximo | **12,430 s** |
| Exit code | **0 — Done performing** |

Os percentis são estatísticas reportadas pelo Taurus para o label `test_access_esxi`. Eles representam os tempos das amostras funcionais reportadas pela campanha; não devem ser confundidos com percentis de latência HTTP de um teste de protocolo, nem com métricas calculadas pelo Prometheus.

### Leitura operacional

- O P50 de 5,840 s representa a mediana das amostras.
- O P90 de 8,120 s e o P95 de 9,450 s descrevem a cauda superior observada na campanha.
- O P99 de 11,210 s e o máximo de 12,430 s registram os tempos mais altos observados.
- O resultado comprova a execução bem-sucedida desta campanha com dois usuários virtuais. **Não comprova capacidade homologada para concorrência superior, nem capacidade máxima do Grid ou do host.**

## Auditoria pós-carga — 04/11/2026

O relatório fornecido para a execução de `check_poc_environment.sh` registrou:

| Verificação | Resultado reportado |
|---|---|
| Debian 13 trixie | PASS |
| Docker Engine 26.1.5+dfsg1 | PASS |
| Acesso ao socket Docker sem sudo | PASS |
| Selenium Hub `ready=true` | PASS |
| Nodes registrados | 2 |
| PID 1 via `docker-init` nos dois Nodes | PASS |
| Processos zombies nos Nodes | 0 |
| Node Exporter `/metrics` | PASS |
| cAdvisor `/metrics` | PASS |
| Prometheus targets | Todos `UP` |
| Chrome Node → ESXi | HTTP 200 |

O resultado demonstra ambiente operacional e ausência de zombies no instante da auditoria pós-carga. É uma observação pontual pós-campanha, não uma garantia de ausência de zombies em todas as execuções futuras.

## Consultas PromQL homologadas no dossiê

### cAdvisor — containers e Chrome Nodes

**Uso de CPU por Chrome Node (% de um core):**

```promql
sum(rate(container_cpu_usage_seconds_total{name=~"chrome-node.*"}[1m])) by (name) * 100
```

**Memória working set dos Chrome Nodes (MiB):**

```promql
container_memory_working_set_bytes{name=~"chrome-node.*"} / 1024 / 1024
```

**Containers de teste observados recentemente:**

```promql
count by (name) (container_last_seen{name=~"chrome-node.*|selenium-hub"})
```

### Node Exporter — host

**Load average de 1 minuto:**

```promql
node_load1
```

**Load average de 5 minutos:**

```promql
node_load5
```

**Memória física usada (MiB), calculada como total menos disponível:**

```promql
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1024 / 1024
```

**Disponibilidade dos alvos de monitoramento:**

```promql
up{job=~"node-exporter|cadvisor|prometheus"}
```

> As expressões acima são as consultas registradas como homologadas no dossiê da campanha. A série `container_*` depende da configuração de coleta do cAdvisor e dos labels efetivamente expostos; validar o resultado no Prometheus quando houver alteração de versão/configuração.

## Configuração e execução

Arquivos principais na raiz:

- `docker-compose.yml` — Hub, dois Chrome Nodes, Node Exporter, cAdvisor, Prometheus e Grafana.
- `prometheus.yml` — configuração de scraping para Prometheus.
- `check_poc_environment.sh` — auditoria pré/pós-carga.
- `test_esxi.py` — teste Selenium remoto para o console ESXi.
- `taurus-esxi-poc.yml` — cenário Taurus com concorrência 2, ramp-up 20s e hold-for 3m.
- `README.md` — arquitetura e registro da homologação.

### Pré-requisitos

- Docker Engine e Docker Compose plugin instalados.
- `curl`, `jq`, `ps` e `pgrep` no host; `curl` e `ps` disponíveis nos Chrome Nodes para os checks correspondentes.
- Taurus CLI 1.17.1 e dependências Python do Selenium/pytest no host `loadtester-lab`.
- Rota de rede do Chrome Node para `10.1.100.102`.
- Os arquivos `docker-compose.yml` e `prometheus.yml` devem permanecer no mesmo diretório para que o bind mount relativo de configuração seja resolvido corretamente.

### Subir a infraestrutura

```bash
docker compose -f docker-compose.yml config
docker compose -f docker-compose.yml up -d
```

### Auditar o ambiente

```bash
chmod +x check_poc_environment.sh
./check_poc_environment.sh
```

### Executar a campanha

O manifesto usa o caminho absoluto homologado no host:

```bash
bzt taurus-esxi-poc.yml
```

O script deve estar em `/home/edsonc/test_esxi.py` no `loadtester-lab`. O Grid é acessado pelo host em `http://127.0.0.1:4444`.

## Decisões e limites conhecidos

1. `init: true` permanece habilitado nos dois Chrome Nodes para fornecer um processo init como PID 1.
2. `shm_size: 512mb` é o valor presente no `docker-compose.yml` fornecido para esta atualização. O registro histórico de 22/09/2026 menciona `2gb`; há, portanto, uma divergência documental que deve ser reconciliada com o Compose efetivamente usado na campanha antes de afirmar que o valor de SHM foi homologado em 04/11/2026.
3. Os limites `cpus` e `mem_limit` são declarados diretamente nos serviços Compose.
4. O serviço cAdvisor é privilegiado e expõe a porta 8080; restringir a exposição à rede administrativa/host firewall conforme a política operacional do ambiente.
5. As portas 9100, 8080, 9090, 3000 e 444x devem ser protegidas por firewall quando o host estiver em rede compartilhada.
6. A auditoria verifica HTTP 200 do ESXi; se a aplicação passar a responder legitimamente com redirecionamento, ajustar o critério de forma explícita, sem aceitar qualquer status como sucesso.
7. O script de auditoria reporta Firefox como aviso, pois o processo do operador compete por CPU/memória com a campanha.

## Histórico anterior — 22/09/2026

A documentação anterior registrou a correção do problema histórico de processos `[sh] <defunct>` associados ao Fluxbox/`fbsetbg`, reconstrução do Grid com Selenium `4.48.0-20260905`, dois Nodes, `init: true`, rede dedicada `e03_selenium-grid`, Xvfb ativo, VNC/noVNC desabilitados e zero zombies no baseline e após uma campanha controlada de sessões.

O status de 22/09/2026 registra `shm_size: 2gb`; o manifesto atualizado aqui traz `512mb`, conforme o artefato recebido. Essa diferença está destacada acima para não misturar duas configurações distintas.

Evidências históricas locais:
- `evidence/rebuild-final/`
- `evidence/session-campaign/`

## Próximos marcos

- Reconciliar o valor de `shm_size` com a configuração executada na campanha oficial.
- Arquivar o relatório integral do Taurus, os logs da auditoria e snapshots de estado do Grid/processos junto à campanha.
- Repetir campanhas em níveis progressivos de concorrência antes de declarar limites de capacidade acima de 2 VUs.
- Correlacionar percentis Taurus, ocupação dos slots, CPU/memória dos Nodes e estados pré/pós-sessão.

## Referências

- [Taurus — Selenium Executor](https://gettaurus.org/docs/Selenium/)
- [Taurus — Execution Settings](https://gettaurus.org/docs/ExecutionSettings/)
- [Docker Compose Specification](https://compose-spec.io/)
- [Selenium Grid](https://www.selenium.dev/documentation/grid/)
- [Matriz_de_fontes](./Matriz_de_fontes)
