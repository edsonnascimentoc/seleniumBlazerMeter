# seleniumBlazerMeter

Projeto de experimentação e validação de uma **arquitetura de carga baseada em Docker + Selenium Grid + Taurus**, com observabilidade e foco adicional na caracterização de capacidade, saturação, ciclo de vida dos processos e correlação entre carga, consumo de recursos e comportamento do ambiente.

## Arquitetura do PoC

A arquitetura do PoC deve ser entendida como uma cadeia integrada de geração, distribuição e execução de carga:

- **Taurus**: camada de definição/orquestração das execuções de carga e dos cenários de teste;
- **Selenium Grid**: camada de distribuição das sessões WebDriver entre os nós;
- **Chrome Nodes**: camada de execução dos navegadores;
- **Docker**: isolamento e gerenciamento dos componentes da infraestrutura;
- **Prometheus/Grafana**: observabilidade e correlação de métricas da infraestrutura e da execução.

Portanto, a caracterização de carga deste PoC não é apenas "Docker + Selenium Grid": **Taurus faz parte da arquitetura de carga e deve ser considerado nas campanhas, nos gates temporais e na análise causal dos resultados**.

## Estado do projeto — 22/09/2026

### Objetivo da etapa atual

Validar objetivamente a correção de um problema de processos **zombie** observado anteriormente nos nós Selenium, sem voltar à investigação exploratória.

O problema histórico apresentava processos como:

- `[sh] <defunct>` associados ao Fluxbox;
- processos `xmessage` persistentes relacionados ao `fbsetbg`;
- o ambiente anterior utilizava uma rede Docker `selenium-grid` existente, sem as labels esperadas pelo Docker Compose.

### Correção de infraestrutura aplicada

O Grid foi reconstruído com uma configuração limpa e isolada:

- Selenium Hub: `selenium/hub:4.48.0-20260905`
- Selenium Nodes: `selenium/node-chrome:4.48.0-20260905`
- 2 nós Chrome;
- `init: true` nos dois nós;
- `shm_size: 2gb`;
- Xvfb habilitado;
- VNC e noVNC desabilitados;
- limpeza automática de browsers habilitada na configuração reconstruída;
- nova rede exclusiva: `e03_selenium-grid`;
- rede antiga `selenium-grid` preservada para referência;
- Hub e nós executando na mesma rede Compose;
- Grid respondendo como `ready=true`.

A configuração atual está registrada no arquivo `compose.yml`.

### Validação inicial após a reconstrução

Foi confirmado:

- PID 1 dos nós: `/sbin/docker-init -- /opt/bin/entry_point.sh`;
- Xvfb ativo nos dois nós;
- Fluxbox ativo nos dois nós;
- VNC/noVNC ausentes;
- Grid com 2 nós registrados e `availability=UP`;
- zero processos zombie detectados no baseline.

### Campanha controlada de sessões

Em 22/09/2026 foi iniciada uma campanha controlada para validar o ciclo de vida das sessões Selenium.

O baseline registrou:

- Node 1: 0 zombies;
- Node 2: 0 zombies.

Uma sessão Selenium foi criada com sucesso, navegou para `https://example.com`, apresentou título `Example Domain` e foi encerrada explicitamente.

Após o encerramento, os processos residuais observados nos nós continham apenas o processo Selenium Server/Java; não foram encontrados processos `chrome`, `chromedriver`, `xmessage` ou `defunct`.

Também foi executado um ciclo de 10 sessões. Ao final:

- Grid: `ready=true`;
- nós registrados: 2;
- disponibilidade: `UP/UP`;
- sessões ativas: nenhuma;
- zombies detectados: nenhum nos dois nós.

> **Status da validação:** a campanha forneceu evidência positiva de estabilidade do ciclo de vida das sessões, mas o conjunto de logs da campanha de 10 sessões não registra individualmente, de forma completa, criação/navegação/encerramento de cada sessão. Portanto, a evidência atual deve ser tratada como **validação parcial**, não como prova definitiva de ausência do problema sob carga sustentada.

### Relação com Taurus

As campanhas de carga devem considerar explicitamente o Taurus como parte do caminho causal:

`Taurus → Selenium/WebDriver → Selenium Grid → Chrome Node → navegador`

e, em paralelo, a observabilidade deve acompanhar a infraestrutura Docker e os componentes do Grid.

Isso é importante porque uma execução manual de uma sessão Selenium valida apenas uma parte do caminho. A validação do PoC sob carga precisa demonstrar o comportamento do conjunto **Taurus + Selenium Grid + Chrome Nodes + Docker**, preservando a correlação temporal entre início da carga, ocupação de slots, execução das sessões, encerramento e estado dos processos.

## Evidências locais

As evidências da execução permanecem no ambiente de teste em:

`evidence/rebuild-final/`

`evidence/session-campaign/`

Entre os artefatos estão snapshots de processos, estado do Grid, registros de zombies e logs da campanha.

## Próximo marco

A próxima etapa é uma campanha de validação mais rigorosa, com instrumentação completa do ciclo:

1. estado dos nós antes da sessão;
2. início controlado da execução Taurus;
3. criação da sessão;
4. navegação/atividade;
5. encerramento explícito;
6. estado dos processos imediatamente após;
7. estado dos processos após intervalo de estabilização;
8. estado final do Grid;
9. correlação com métricas de infraestrutura e ocupação de slots.

O critério objetivo de sucesso é a ausência de processos zombie e de processos de browser/driver residuais após o encerramento das sessões, mantendo o Grid operacional e os dois nós disponíveis.

## Fontes técnicas — Context7

As referências utilizadas para orientar a configuração e as práticas do projeto estão em [Matriz_de_fontes](./Matriz_de_fontes), incluindo Selenium, Docker Selenium, Docker, Compose, Taurus e Grafana.
