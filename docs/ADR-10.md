# ADR-10 — E-03 — separar efeito de capacidade do Grid de saturação do loadtester

## CLASSIFICAÇÃO

5

## STATUS

Aprovado

## DATA

22/09/2026

## RAs REL.

RA-03, RA-07, RA-08, RA-12, RA-15, RA-21, RA-22

## VAs REL.

VA-07, VA-09, VA-26, VA-27, VA-28

## TÍTULO

E-03 — separar efeito de capacidade do Grid de saturação do loadtester

## CONTEXTO

O PoC utiliza Docker + Selenium Grid + Taurus. Taurus é parte da arquitetura de carga.

O E-03 exige separar a capacidade do Selenium Grid da capacidade e eventual saturação do
loadtester, evitando atribuir uma degradação ao Grid sem evidência causal.

## ESTUDO

Fonte primária da validação:

`docs/baseline/2026-09-22.md`

A baseline registra:

- Selenium Grid 4.48.0-20260905;
- 2 Chrome Nodes;
- Grid `ready=true`;
- Nodes 2/2 UP;
- Docker init habilitado;
- Xvfb habilitado;
- VNC e noVNC desabilitados;
- rede Compose `e03_selenium-grid`;
- zero zombies no baseline;
- uma sessão Selenium funcional;
- 10 sessões/ciclos;
- ausência observada de zombies, `defunct`, `xmessage`, Chrome residual e chromedriver residual.

A evidência demonstra que a reconstrução eliminou o estado zombie no baseline e que sessões
Selenium podem ser criadas e encerradas sem produzir zombies observáveis no teste realizado.

Entretanto, a campanha de 10 sessões não possui instrumentação individual completa por sessão.
O registro não comprova, para cada uma das 10 sessões, o ciclo completo de criação, navegação,
encerramento e coleta de processos antes/durante/depois.

A campanha também não estabelece correlação temporal completa entre o início da carga Taurus,
a evolução da ocupação do Grid, o ciclo de vida das sessões e o estado dos processos/recursos
na mesma janela temporal.

Assim, a evidência é positiva para rebuild/lifecycle, mas ainda não é uma homologação de
capacidade nem uma validação causal completa da arquitetura Taurus + Selenium Grid + Docker.

## DECISÃO

1. Separar a análise de capacidade do Selenium Grid da capacidade/saturação do loadtester.
2. Não atribuir degradação exclusivamente ao Grid sem correlação temporal.
3. Não homologar 30 VUs ou 120 VUs com a evidência atual.
4. Registrar a baseline de 22/09/2026 como validação positiva de rebuild/lifecycle,
   e não como homologação de capacidade.
5. Na próxima campanha, correlacionar temporalmente:
   - início e evolução da carga Taurus;
   - ocupação e queue time do Grid;
   - criação e encerramento das sessões;
   - estado dos Nodes;
   - CPU, RAM, PSI e I/O;
   - erros;
   - p95.
6. Manter RAs, VAs, Concerns e ADR-07 sem alteração por esta evidência.

## CRITÉRIOS PARA A PRÓXIMA VALIDAÇÃO

A próxima campanha deverá permitir verificar:

`sessões criadas = sessões encerradas = sessões verificadas`

`zombies após cada encerramento = 0`

`Grid ready = true`

`Nodes UP = 2`

Além disso, deverá existir correlação temporal com o Taurus e instrumentação suficiente para
separar comportamento do Grid de saturação do loadtester.

## RELAÇÃO COM ArcH-Smart

Esta atualização registra a decisão do E-03 sem reclassificar RAs, VAs ou Concerns.

A homologação de capacidade permanece condicionada a nova evidência. Os valores de 30 VUs
e 120 VUs não são tratados como capacidade comprovada por esta baseline.
