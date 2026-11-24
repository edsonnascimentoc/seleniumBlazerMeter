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


### 7. Campanha de investigação adicional — Fluxbox / shell zombie (24/11/2026)

Esta campanha documental complementa a investigação inicial. Não houve instalação de pacotes, alteração de arquivos, reinício de containers, encerramento de processos ou execução de Taurus.

#### 7.1 Evidências novas confirmadas

| Item | Resultado observado | Interpretação permitida |
|---|---|---|
| Processo pai | PID 105: `/usr/bin/fluxbox -display :99.0` nos dois Nodes | Fluxbox é o pai atual do zombie |
| Processo filho | PID 154: `[sh] <defunct>`, PPID 105, estado `Zs` nos dois Nodes | O shell terminou e ainda não foi recolhido |
| Horário de início | Fluxbox às 11:40:37; zombie às 11:40:44 em ambos | A ocorrência aparece cerca de sete segundos após o início do Fluxbox |
| Inicialização observada | `start-xvfb.sh` executa diretamente `/usr/bin/fluxbox` via `xvfb-run` | Não há evidência de passagem pelo wrapper `startfluxbox` nesse fluxo |
| Script `startfluxbox` | Usa `~/.fluxbox/startup` ou cria script padrão com `fbautostart` | Seu conteúdo não prova execução neste ambiente |
| Configuração Fluxbox examinada | `/etc/X11/fluxbox/init`, `overlay` e `/home/seluser/.fluxbox/init` sem `rootCommand`; não foi encontrado `~/.fluxbox/startup` | Enfraquece a hipótese de comando de inicialização configurado nesses arquivos |
| `fbsetbg` | Chama o setter escolhido (`Esetroot`) e, em caso de falha, executa `message` em background | Relação entre falha do wallpaper e notificações está caracterizada |
| `xmessage` | Processos observados com PPID 1, iniciados antes do Fluxbox | Não são filhos diretos do PID 105 observados nesta coleta |
| `Esetroot` | Logs registram `Unable to open display :99.0` em algumas tentativas; posteriormente x11vnc utiliza o display | Falha transitória de abertura do display está documentada; vínculo com o zombie não foi demonstrado |
| Ferramentas | `strings` e `readelf` ausentes nos containers | Não foi possível inspecionar strings/símbolos do binário por esses utilitários |

#### 7.2 Hipóteses reavaliadas

- **`startfluxbox` / `~/.fluxbox/startup`: enfraquecida como origem.** O fluxo observado chama diretamente `/usr/bin/fluxbox`; o wrapper não aparece como ancestral do processo.
- **`fbautostart`: não sustentada para esta ocorrência.** Sua chamada está no script padrão gerado pelo wrapper `startfluxbox`, cujo uso não foi observado.
- **`fbsetbg` / `Esetroot`: hipótese não confirmada.** Há erros de wallpaper e chamadas assíncronas a `xmessage`, mas nenhum dado liga essas chamadas ao shell PID 154.
- **`xmessage` como pai do zombie: descartada para a topologia observada.** O PPID do zombie é 105 (Fluxbox), enquanto os processos xmessage examinados têm PPID 1.
- **Fluxbox como pai que ainda não recolheu o filho: confirmada.** A relação PPID e o estado Z foram observados nos dois Nodes. Isso não identifica qual rotina criou o shell.
- **`rootCommand` nos arquivos examinados: não encontrada.** A busca não cobre necessariamente todos os recursos de estilo ou mecanismos internos do binário; não é uma exclusão universal.
- **Defeito do Fluxbox, da imagem Selenium ou efeito de limitação de recursos: não demonstrado.**

#### 7.3 Limitações e próximo experimento

O estado zombie não preserva sua linha de comando em `/proc/<pid>/cmdline`; a observação posterior não permite reconstruir retrospectivamente o comando que o criou. Para avançar, será necessário capturar uma nova inicialização e rastrear criação/execução de processos (por exemplo, eventos de `fork`, `clone`, `vfork` e `execve`) com ferramenta disponível no host ou em ambiente de diagnóstico equivalente.

A próxima coleta deve ser planejada antes de qualquer reinício. **Não reiniciar os Nodes para este diagnóstico sem autorização específica**, pois isso destrói o estado atual e pode remover evidências. Não instalar ferramentas nos containers homologados nesta etapa.

**Resultado:** relação pai-filho confirmada; hipótese de uso de `startfluxbox` enfraquecida; vínculo de `fbsetbg`/Esetroot com o zombie não confirmado; causa raiz indeterminada; DT-001 permanece aberto.

## Histórico de atualização

| Data | Atualização |
|---|---|
| 24/11/2026 | Registro inicial de DT-001 com evidências de PID/PPID, estados dos processos e relação pai-filho nos dois Chrome Nodes. |
| 24/11/2026 | Campanha adicional: registrada a inicialização direta do Fluxbox, reavaliação do wrapper `startfluxbox`, erros de Esetroot e topologia de xmessage. Hipóteses classificadas sem atribuição indevida de causa raiz. |
