# PAE — Ciclo 01: acesso e autenticação

## Objetivo

Validar o caminho de entrada no PAE Ambulante:
Login Único, portal de serviços, cartão `card_pae_ambulante`,
abertura do serviço e chegada à página `/Solicitacao/Local`.

## Casos de teste e resultados

| ID | Etapa | Resultado esperado | Estado |
|---|---|---|---|
| CT-PAE-001 | Abrir Login Único | Campos `username`, `password` e botão `kcLogin` identificados | Aprovado |
| CT-PAE-002 | Autenticar manualmente | Portal de serviços acessível após autenticação | Aprovado |
| CT-PAE-003 | Localizar cartão PAE | Elemento `card_pae_ambulante` visível | Aprovado |
| CT-PAE-004 | Abrir serviço | Destino pertence ao ambiente de desenvolvimento PAE e abre corretamente | Aprovado |
| CT-PAE-005 | Concluir OIDC e navegar | URL contém `/Solicitacao/Local` e título contém PAE | Aprovado |

## Evidência da execução

- Data: 13/11/2026.
- Teste: `tests/functional/test_acesso_pae.py`.
- Resultado: `1 passed`.
- Duração registrada: 96,22 segundos.
- Navegador: Chrome remoto no Selenium Grid.
- Autenticação: manual pelo noVNC.
- Ambiente: desenvolvimento do PAE Ambulante.

O teste verificou a identificação da tela de Login Único, a
disponibilidade do portal autenticado, a localização do cartão PAE,
a abertura do serviço e a chegada à página de seleção de local.

A autenticação é realizada manualmente pelo operador. O teste não
automatiza o preenchimento de CPF ou senha.

## Correção realizada durante a homologação

A primeira execução falhou porque `PAEPage` procurava um elemento
HTML `h1` que não existia na página.

A inspeção do navegador confirmou:
- URL: `/Solicitacao/Local`;
- título: `Local da atividade - PAE - Programa de Autorização Especial`;
- estado do documento: `complete`;
- elemento de seção encontrado: `h3` com texto `Informações`.

O seletor foi corrigido para localizar o `h3` pelo texto
`Informações`. A execução posterior foi aprovada.

## Execução

Na VM `loadtester-lab`, com Selenium Grid ativo:

```bash
PYTHONPATH="/home/edsonc/.bzt/python-packages/3.13.5" \
python3 -m pytest -m pae_manual_auth -s -v \
tests/functional/test_acesso_pae.py
```

Abra o noVNC do Chrome remoto e conclua o Login Único manualmente.

Configurações:
- `SELENIUM_GRID_URL`: endereço do Selenium Grid.
  Padrão: `http://127.0.0.1:4444`.
- `PAE_LOGIN_URL`: endereço inicial do Login Único.
- `PAE_AUTH_TIMEOUT`: tempo máximo para autenticação manual.
  Padrão: 300 segundos.

## Limites e segurança

- Nenhuma credencial é armazenada, registrada ou preenchida pelo teste.
- O teste não envia cadastro, não anexa documentos e não solicita vaga.
- A autenticação é manual.
- O teste é funcional, não é campanha de carga.
- A aprovação deste ciclo não representa homologação das demais
  funcionalidades do PAE.
- O teste legado `test_esxi.py` e a configuração Taurus permanecem
  preservados como trilha histórica.
- Nenhuma campanha Taurus foi executada neste ciclo.

## Próximas etapas

1. Implementar testes de seleção de local e atividade.
2. Implementar testes de consulta de bairros e vagas.
3. Implementar testes de validação do formulário de cadastro.
4. Avaliar documentos obrigatórios e regras condicionais.
5. Validar o fluxo completo sem efetuar solicitação real.
6. Planejar campanhas controladas de desempenho somente após
   homologação funcional e alinhamento das regras de negócio.
