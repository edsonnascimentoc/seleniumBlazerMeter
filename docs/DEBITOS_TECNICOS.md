# Registro de débitos técnicos — PoC Selenium / Taurus

Este documento mantém o registro de condições técnicas conhecidas que ainda não foram resolvidas. O objetivo é preservar transparência, rastreabilidade e critérios de tratamento sem mascarar falhas da auditoria.

**Regra principal da PoC:** tornar a arquitetura operacional e reproduzível em escala maior, com vistas à operação em produção. A aceitação temporária de um débito para uma campanha experimental não equivale à homologação para produção.

## DT-001 — Processo zombie associado ao Fluxbox nos Chrome Nodes

| Campo | Registro |
|---|---|
| Identificador | DT-001 |
| Categoria | Gerenciamento do ciclo de vida de processos |
| Identificado em | 24/11/2026 |
| Prioridade | Baixa no contexto observado; requer monitoramento |
| Situação | Aberto — causa raiz pendente |
| Tratamento | Aceitação temporária e controlada para caracterização experimental |

### 1. Descrição

Foi identificado um processo `sh` em estado zombie (`Zs`) em cada container Chrome Node:

| Evidência | `chrome-node-1` | `chrome-node-2` |
|---|---:|---:|
| PID do zombie | 154 | 154 |
| PPID | 105 | 105 |
| Processo pai | `fluxbox` | `fluxbox` |
| Estado do pai | `S` (sleeping) | `S` (sleeping) |
| Estado do filho | `Z` (zombie) | `Z` (zombie) |
| PID / PGID / SID do filho | 154 / 154 / 154 | 154 / 154 / 154 |
| Filho listado em `/proc/105/task/105/children` | Sim | Sim |

O PID 1 de ambos os containers é `/sbin/docker-init -- /opt/bin/entry_point.sh`.

### 2. Diagnóstico e limites da evidência

**Causa imediata caracterizada:** o processo filho `sh` terminou, mas seu estado de término permanece registrado sob o processo pai `fluxbox`. O pai continua ativo e lista o PID 154 como filho; portanto, o estado ainda não foi recolhido pelo pai por meio do mecanismo de espera de processos.

**Causa raiz não identificada:** as coletas não identificam qual rotina criou o shell, por que ele terminou ou por que o Fluxbox não recolheu seu estado. Não há evidência suficiente para atribuir a ocorrência à limitação de 2 vCPU / 4 GB de RAM, à imagem Selenium ou a uma configuração específica.

A repetição do mesmo padrão nos dois Nodes sugere comportamento reproduzível do ambiente gráfico/inicialização, mas não prova a origem do processo.

### 3. Impacto conhecido

Na auditoria pré-campanha de 24/11/2026:
- os dois Nodes estavam registrados e com disponibilidade `UP`;
- o Selenium Grid estava pronto;
- não havia sessões Selenium ativas;
- endpoints de observabilidade e os três targets Prometheus estavam operacionais;
- a auditoria de ambiente terminou com código 1 devido à presença de um zombie em cada Node.

Não foi demonstrada indisponibilidade funcional causada pelos zombies. O impacto operacional comprovado na coleta é baixo; isso não elimina a necessidade de investigação nem transforma a auditoria reprovada em aprovada.

### 4. Tratamento adotado

- Preservar a configuração homologada e as evidências originais.
- Não matar processos, reiniciar containers ou alterar a imagem para ocultar a ocorrência.
- Não remover nem flexibilizar a verificação de zombies em `check_poc_environment.sh`.
- Registrar a reprovação da auditoria original.
- Para uma eventual campanha experimental, documentar formalmente a aceitação temporária do apontamento, executar nova auditoria e manter supervisão ativa.
- Não transportar automaticamente esse comportamento para a arquitetura de produção.

### 5. Critérios de encerramento

O débito poderá ser encerrado quando:
1. a rotina/comando que origina o processo for identificada ou suficientemente caracterizada;
2. a causa do não recolhimento do estado pelo processo pai for compreendida;
3. o tratamento for validado sem comprometer a estabilidade do Selenium Grid;
4. a solução, se necessária, for reproduzível e documentada na arquitetura de referência;
5. a auditoria voltar a refletir o estado real sem exceções artificiais.

### 6. Relação com a campanha Taurus

DT-001 é uma condição conhecida a ser observada durante a preparação e, se formalmente aceita após revisão do preflight, durante a campanha controlada. Sua aceitação temporária:
- não altera o resultado da auditoria;
- não representa correção da causa raiz;
- não comprova capacidade ou prontidão para produção;
- não dispensa supervisão e critérios de interrupção.

A campanha não deve ser iniciada enquanto a auditoria pré-execução atual não tiver sido revisada, os critérios de parada não estiverem definidos e não houver supervisão ativa durante toda a execução.

---

## Histórico de atualização

| Data | Atualização |
|---|---|
| 24/11/2026 | Registro inicial de DT-001 com evidências de PID/PPID, estados dos processos e relação pai-filho nos dois Chrome Nodes. |
