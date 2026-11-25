# PAE — execução funcional paralela com duas sessões

## Objetivo

Executar duas sessões WebDriver independentes em paralelo, utilizando os
dois Chrome Nodes registrados no Selenium Grid. Cada sessão percorre o fluxo
já homologado no Ciclo 01: Login Único, portal de serviços, cartão PAE e
página `/Solicitacao/Local`.

O teste original `tests/functional/test_acesso_pae.py` permanece intacto.
Esta execução é complementar e isolada.

## Distribuição dos workers

Os dois casos estão em módulos Python distintos:

- `tests/functional/parallel/test_sessao_pae_a.py`
- `tests/functional/parallel/test_sessao_pae_b.py`

Com dois workers e distribuição `loadscope` do pytest-xdist, cada módulo
é um grupo de escopo distinto e pode ser atribuído a um worker diferente.
Cada worker solicita seu próprio WebDriver remoto por meio da fixture
`pae_driver`. O Selenium Grid decide qual Chrome Node atenderá cada sessão;
não se fixa artificialmente uma sessão a um Node específico.

## Autenticação e segurança

- O operador realiza manualmente o Login Único em cada navegador pelo noVNC.
- CPF e senha não são lidos, preenchidos, persistidos ou registrados pelo teste.
- Não há compartilhamento de cookies ou sessão entre os workers.
- O fluxo não envia cadastro, não anexa documentos e não solicita vaga.
- O teste termina ao confirmar a chegada à página inicial de seleção de local.

O tempo máximo padrão para a autenticação manual é de 300 segundos por teste,
configurável por `PAE_AUTH_TIMEOUT`.

## Execução direta com pytest

Na raiz do repositório, com o Grid ativo:

```bash
PYTHONPATH="/home/edsonc/.bzt/python-packages/3.13.5" \
python3 -m pytest -n 2 --dist=loadscope \
  -m pae_parallel_auth -s -v tests/functional/parallel
```

Abra os dois endereços noVNC da VM antes de iniciar o comando:

- Node 1: `http://172.21.0.6:7900`
- Node 2: `http://172.21.0.5:7900`

Quando os dois navegadores exibirem o Login Único, autentique manualmente
cada um. A ordem pode variar; observe os dois navegadores.

## Execução via Taurus

Manifesto: `taurus-pae-parallel.yml`.

```bash
PYTHONPATH="/home/edsonc/.bzt/python-packages/3.13.5" \
bzt taurus-pae-parallel.yml
```

O manifesto define concorrência 2 e uma única iteração da suíte. Não define
`ramp-up` nem `hold-for`: o runner pytest selecionado não aplica o ramp-up
como um escalonamento gradual, e uma duração fixa é inadequada para uma
etapa bloqueada por autenticação humana. O tempo efetivo depende da ação
do operador e dos tempos de resposta da aplicação.

## Critérios de aprovação

1. Dois workers pytest iniciados.
2. Duas sessões WebDriver remotas distintas criadas.
3. Dois navegadores independentes visíveis no noVNC.
4. Autenticação manual concluída separadamente em cada navegador.
5. Ambos os testes chegam a `/Solicitacao/Local` no host PAE esperado.
6. Nenhum cadastro, documento ou solicitação real é enviado.

## Limites da evidência

A aprovação demonstra execução funcional paralela com duas sessões
autenticadas manualmente. Não demonstra carga sustentada, capacidade máxima,
throughput, escalabilidade ou comportamento sob múltiplos usuários por
minutos. Uma campanha de desempenho repetível exigirá mecanismo de
autenticação de teste não interativo, formalmente autorizado pela equipe
responsável pela aplicação, ou uma estratégia de sessão de teste suportada.

## Estado

Esta implementação precisa ser executada e ter seus resultados/logs
analisados no host `loadtester-lab` antes de ser considerada homologada.
A aprovação do Ciclo 01 permanece independente.
