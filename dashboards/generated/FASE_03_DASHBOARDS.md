# Fase 03 — Dashboards Grafana

## Estado da implementação

**Estado: dashboards importados e validação visual concluída.**

Foram criados e importados três dashboards novos e independentes para a PoC, preservando os três dashboards originais existentes no Grafana.

Datasource Prometheus confirmado no ambiente:

- Nome: `prometheus`
- UID: `cg3adtrifq7lse`
- Tipo: `prometheus`
- URL: `http://prometheus:9090`
- Padrão: sim

## Dashboards novos

| Arquivo de origem | UID | Objetivo | Painéis |
|---|---|---|---:|
| `poc-selenium-operacional.json` | `poc-selenium-operacional` | Saúde dos endpoints de scrape e visão operacional de host/containers | 6 |
| `poc-taurus-investigacao.json` | `poc-taurus-investigacao` | Investigação de CPU, I/O wait e memória | 7 |
| `qaops-capacidade-correlacao.json` | `qaops-capacidade-correlacao` | Contexto de infraestrutura para QAOps; integração de resultados pendente | 6 |

Os três dashboards usam UIDs próprios e o datasource Prometheus existente. Os três dashboards originais foram preservados.

## Métricas e limites

Consultas utilizadas nos dashboards:

- `up{job="prometheus"}`, `up{job="node-exporter"}`, `up{job="cadvisor"}`
- `(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[2m]))) * 100`
- `avg(rate(node_cpu_seconds_total{mode="iowait"}[2m])) * 100`
- `node_memory_MemAvailable_bytes / 1024 / 1024`
- `sum by (container_label_com_docker_compose_service) (rate(container_cpu_usage_seconds_total{container_label_com_docker_compose_project="selenium-grid"}[2m]))`
- `container_memory_working_set_bytes{container_label_com_docker_compose_project="selenium-grid",container_label_com_docker_compose_service=~"chrome-node-[12]"} / 1024 / 1024`

`up` representa o sucesso da coleta do endpoint, não a prontidão funcional do Selenium Grid. CPU de container é expressa em cores. A memória apresentada pelo cAdvisor é o working set do cgroup, não RSS.

O Prometheus ainda não coleta métricas do Selenium Hub nem do Taurus. Portanto, sessões ativas, VUs, throughput, latência, percentis e taxa de erro não estão disponíveis como métricas em tempo real.

O dashboard QAOps permanece parcial até que os resultados Taurus sejam integrados de forma rastreável. A visualização de infraestrutura não constitui homologação de capacidade.

## Validação dos arquivos e importação

A validação estrutural local dos três JSONs confirmou:

- JSONs sintaticamente válidos;
- UIDs dos dashboards esperados;
- datasource Prometheus com UID `cg3adtrifq7lse`;
- expressões PromQL preenchidas nos targets.

Os três dashboards foram importados no Grafana como dashboards independentes. A listagem da interface confirmou a presença dos três dashboards novos e dos três originais.

### Validação visual

A inspeção visual após a importação confirmou:

| Dashboard | Painéis exibidos |
|---|---:|
| PoC - Selenium Grid & Infraestrutura — Fase 03 | 6 |
| Investigação de Recursos - Selenium Grid & Host | 7 |
| QAOps - Resultados e Capacidade | 6 |
| **Total** | **19** |

Os 19 painéis apresentaram dados na inspeção visual, sem erros visíveis de renderização ou datasource. Essa validação representa o estado observado durante a inspeção, não uma garantia de disponibilidade contínua.

### Contagem de consultas

A inspeção dos JSONs exportados identificou:

- 19 painéis;
- 20 targets/expressões PromQL;
- nenhum target sem expressão;
- datasource UID consistente nos três dashboards.

A quantidade de expressões não deve ser confundida com a quantidade de painéis.

## Exportação pós-importação — 17/11/2026

Os três dashboards foram exportados pela interface do Grafana após a importação e armazenados em:

`dashboards/exports/grafana-2026-11-17/`

Arquivos e SHA-256 registrados:

| Arquivo exportado | SHA-256 |
|---|---|
| `Investigação de Recursos - Selenium Grid & Host-1794935421454.json` | `5315e2a952e16d334927758aa05c72524681e8016022f63b8edb89b9b9c18b23` |
| `PoC - Selenium Grid & Infraestrutura — Fase 03-1794935550388.json` | `5e195355041475d8591fb231e044bb9611df94ae78753fa7a0a38b95cc99d223` |
| `QAOps - Resultados e Capacidade-1794935201972.json` | `890ad4ecfb03b261a75e88bad46a47a16279a2ce78f81a912d0990252a19c61e` |

Os checksums identificam os arquivos exportados e permitem verificar sua integridade em cópias posteriores. Eles não comprovam, isoladamente, equivalência byte a byte entre os arquivos exportados e os JSONs usados na importação.

## Limitações e critérios de conclusão

A Fase 03 concluiu a criação, importação, inspeção visual e exportação dos três dashboards.

Permanecem fora do escopo concluído:

1. Integração de métricas do Selenium Hub ao Prometheus.
2. Integração de métricas Taurus para VUs, throughput, latência, percentis e falhas.
3. Correlação temporal automatizada entre resultados de carga e métricas de infraestrutura.
4. Homologação de capacidade máxima do Selenium Grid ou do host.

A conclusão desta fase não significa que a PoC esteja homologada para capacidade ou concorrência além dos cenários já executados e documentados.

## Próximas etapas

1. Manter os JSONs de origem e as exportações pós-importação versionados.
2. Integrar, em etapa própria, os resultados Taurus e as métricas ainda ausentes.
3. Atualizar os dashboards somente mediante revisão das consultas e evidências.
4. Reavaliar a correlação e a capacidade após a integração das fontes de dados.
5. Atualizar o README e manter os artefatos e a documentação coerentes.
6. Realizar commit conjunto dos artefatos e da documentação após revisão. Push somente mediante autorização.
