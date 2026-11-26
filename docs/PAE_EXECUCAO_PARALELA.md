# PAE — execução funcional paralela com dois processos Taurus

## 1. Objetivo e escopo

Executar duas sessões WebDriver independentes em paralelo. Cada sessão percorre o fluxo funcional validado no Ciclo 01: Login Único, portal de serviços, cartão PAE e página /Solicitacao/Local.

O alvo atual é o PAE Ambulante em ambiente de desenvolvimento. A arquitetura de execução não deve ficar acoplada ao PAE nem a um ambiente específico: o servidor de destino representa o local onde a aplicação sob teste está hospedada e poderá corresponder a desenvolvimento, treinamento ou produção.

O teste original tests/functional/test_acesso_pae.py permanece intacto. Esta execução é complementar.

## 2. Estratégia de paralelismo

A configuração inicial taurus-pae-parallel.yml, com concurrency: 2 e pytest-xdist, fez os dois testes pytest concluírem, mas o plugin de gravação do runner pytest do Taurus lançou:

    AttributeError: 'NoneType' object has no attribute 'status'

O relatório LDJSON dessa execução ficou incompleto (uma amostra para dois testes). Portanto, não se deve considerar essa configuração aprovada para geração de resultados Taurus.

A estratégia alternativa é iniciar dois processos Taurus independentes:

| Processo | Manifesto | Teste | Concorrência |
|---|---|---|---:|
| A | taurus-pae-a.yml | test_sessao_pae_a | 1 |
| B | taurus-pae-b.yml | test_sessao_pae_b | 1 |

Os dois processos são iniciados em sequência imediata pelo shell, sem aguardar a conclusão do primeiro para iniciar o segundo. Cada processo possui diretório de artefatos e log próprios.

O Selenium Grid decide qual Chrome Node atenderá cada sessão. A execução não fixa artificialmente a sessão A no Node 1 ou a B no Node 2. Em execução diagnóstica anterior, duas sessões independentes foram observadas em Nodes distintos; isso não substitui a verificação da alocação em cada nova campanha.

## 3. Autenticação e segurança

- O operador realiza manualmente o Login Único em cada navegador pelo noVNC.
- CPF e senha não são lidos, preenchidos, persistidos ou registrados pelo teste.
- Não há compartilhamento de cookies ou sessão entre os processos.
- O fluxo não envia cadastro, não anexa documentos e não solicita vaga.
- O teste termina ao confirmar a chegada à página inicial de seleção de local.
- O tempo máximo padrão para autenticação manual é de 300 segundos por teste, configurável por PAE_AUTH_TIMEOUT.

## 4. Pré-requisitos

- VM geradora loadtester-lab com Taurus, pytest e dependências Python disponíveis.
- Selenium Grid acessível pelo host em http://127.0.0.1:4444.
- Pelo menos dois Chrome Nodes com disponibilidade UP e dois slots livres.
- Acesso noVNC aos navegadores remotos.
- A VM geradora deve alcançar o ambiente da aplicação PAE.
- O operador deve estar autorizado a autenticar no ambiente de destino.

O caminho das dependências Python instaladas no ambiente Taurus pode ser informado por BZT_PYTHONPATH. No host utilizado durante a POC:

    export BZT_PYTHONPATH="/home/edsonc/.bzt/python-packages/3.13.5"

O executável Taurus deve estar no PATH ou ser indicado por BZT_BIN.

## 5. Execução

Na raiz do repositório:

    chmod +x run_pae_parallel.sh
    ./run_pae_parallel.sh

Antes de iniciar, abra os dois navegadores remotos pelo noVNC. Quando ambos exibirem o Login Único, realize a autenticação separadamente em cada um.

O orquestrador:

1. Confere se o Grid está pronto, com dois Nodes UP e pelo menos dois slots livres.
2. Cria diretórios exclusivos para A e B em artifacts/pae-parallel-*/.
3. Inicia os dois processos Taurus independentes.
4. Aguarda ambos e registra seus códigos de saída.
5. Valida que cada execução produziu exatamente um LDJSON com uma amostra principal PASSED e o nome de teste esperado.
6. Verifica que não restaram sessões ativas no Grid.
7. Preserva logs e relatórios, inclusive em caso de reprovação.

É possível substituir o executável Taurus e o diretório de dependências:

    BZT_BIN="/caminho/para/bzt" \
    BZT_PYTHONPATH="/caminho/das/dependencias" \
    ./run_pae_parallel.sh

## 6. Critérios de aprovação

1. Grid pronto antes da execução.
2. Dois processos Taurus iniciados independentemente.
3. Processo A termina com código zero e relatório válido.
4. Processo B termina com código zero e relatório válido.
5. Cada relatório contém exatamente uma amostra principal, com status PASSED e o caso de teste correspondente.
6. Nenhuma sessão permanece ativa no Grid após a execução.
7. Nenhum cadastro, documento ou solicitação real é enviado.

O script retorna código diferente de zero se qualquer condição automatizada falhar. A autenticação manual é uma ação do operador e deve ser concluída nos dois navegadores.

## 7. Evidência e limites de interpretação

Em 26/11/2026, os dois processos Taurus independentes foram executados simultaneamente e concluíram com uma amostra PASSED cada:

| Caso | Amostras | Falhas | Duração Taurus registrada |
|---|---:|---:|---:|
| test_sessao_pae_a | 1 | 0 | 312,058 s |
| test_sessao_pae_b | 1 | 0 | 327,526 s |

Os registros de início das amostras diferiram em aproximadamente 0,153 segundo. Os arquivos LDJSON individuais apresentaram status PASSED.

**Limite importante:** os tempos Taurus representam a duração da amostra funcional e incluem a espera pela autenticação manual. Não são latências HTTP nem tempos isolados de resposta do PAE. A execução também não comprova throughput, capacidade máxima, escalabilidade ou carga sustentada.

A aprovação demonstra somente a execução funcional paralela de duas sessões independentes no escopo descrito. Uma campanha de desempenho repetível exige autenticação não interativa de teste, formalmente autorizada pela equipe responsável, ou uma estratégia de sessão suportada pela aplicação.

## 8. Configuração experimental anterior

O manifesto taurus-pae-parallel.yml permanece preservado como registro da tentativa com pytest-xdist. Não deve ser usado como caminho de execução aprovado enquanto a falha do plugin Taurus não for corrigida e validada.

## 9. Relação com a arquitetura de referência

A VM geradora (Taurus, pytest e Selenium Client) é independente do servidor/ambiente que hospeda a aplicação. O Hub distribui as sessões pelos Chrome Nodes, que acessam a aplicação sob teste. O destino poderá ser desenvolvimento, treinamento ou produção, conforme configuração, autorização e homologação específicas.

A POC atual utiliza o PAE em desenvolvimento como alvo. A aprovação desta execução não autoriza automaticamente a implantação em produção em escala; esta depende de dimensionamento, segurança, disponibilidade e observabilidade próprias do ambiente produtivo.
