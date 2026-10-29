## TRABALHO PRÁTICO	PROJETO DE BANCO DE DADOS
INTEGRAÇÃO COM SUPABASE E REDIS
UNIFSA // ENGENHARIA DE SOFTWARE **28M4A**


#### Identificação:

* Aluno - Guilherme Mendes Ribeiro
* Professor - Anderson Soares da Costa
* Disciplina - Projeto de Banco de Dados


#### Sobre o projeto:

LojaCore é um aplicativo em PyQt6 CRUD simples de gestão
comercial de pequenas e médias lojas: controle de vendas (PDV), estoque, clientes,
fidelidade e permissões de acesso tudo integrado a um banco de dados relacional
no **Supabase (PostgreSQL)** com **cache distribuído via Redis**.


#### Tecnologias utilizadas:

* Supabase PostgreSQL;
* Redis
* Python:
    * PyQt6(Interface Grafica),
    * SQLAlchemy,
    * psycopg,
    * redis



#### Integração com Supabase
O Supabase atua como banco de dados relacional (PostgreSQL) do projeto.
A comunicação é feita via SQLAlchemy (engine + session) com driver psycopg2.


##### Como funciona

PyQt6 (UI)
    │
    ▼
conexao.py  ──SQLAlchemy──▶  Supabase PostgreSQL
    │
    ├── Views (vw_*)          → consultas consolidadas
    ├── Functions (fn_*)      → lógica de negócio (auth, status, pontos)
    ├── Procedures (CALL)     → transações complexas (venda, estoque, cadastro)
    └── Queries diretas       → busca de dados do app (funcionário, empresa, permissões)



#### Elementos do banco utilizados
Tipo	Exemplos	Uso na aplicação
Views	vw_vendas_recentes, vw_estoque_critico, vw_resumo_caixa_diario, vw_geral_estoque_produtos, vw_clientes_registrados, vw_funcionarios_registrados	Tabelas de dados nas telas de Vendas, Estoque, Caixa, Clientes, Funcionários e Estatísticas.
Functions	fn_autenticar_funcionario, fn_autenticar_empresa, fn_status_produto, fn_calcular_pontos_compra	Login, consulta de produto e cálculo de fidelidade.
Procedures	registrar_venda, adicionar_item_venda, registrar_cliente, registra_funcionarios, registrar_empresa	Operações de escrita transacionais (PDV, cadastros).

Exemplo de chamada (Python → Supabase)
def fn_autenticar_funcionario(cpf, senha):
    with SessionLocal() as sessao:
        query = text("SELECT fn_autenticar_funcionario(:p_cpf, :p_senha)")
        resultado = sessao.execute(query, {"p_cpf": cpf, "p_senha": senha})
        return resultado.scalar_one_or_none()

#### Integração com Redis
Onde foi utilizado
O Redis é utilizado exclusivamente como cache de leitura para as views
consultadas com frequência pela interface.

Chaves e TTLs
View	Chave Redis	TTL
vw_vendas_recentes	lojacore:vw_vendas_recentes:empresa:{id}:v3	30 s
vw_estoque_critico	lojacore:vw_estoque_critico:empresa:{id}:v3	30 s
vw_resumo_caixa_diario	lojacore:vw_resumo_caixa_diario:empresa:{id}:v3	30 s
vw_geral_estoque_produtos	lojacore:vw_geral_estoque_produtos:empresa:{id}:v3	60 s
vw_clientes_registrados	lojacore:vw_clientes_registrados:empresa:{id}:v3	120 s
vw_funcionarios_registrados	lojacore:vw_funcionarios_registrados:empresa:{id}:v3	120 s

Invalidação (Write-Through)
Sempre que uma procedura de escrita é executada, as chaves afetadas são
removidas do Redis para garantir consistência:

def registrar_venda(...):
    # ... CALL registrar_venda(...) ...
    sessao.commit()
    invalidar_cache_empresa(
        empresa_id,
        "vw_vendas_recentes",
        "vw_geral_estoque_produtos",
        "vw_estoque_critico",
        "vw_resumo_caixa_diario"
    )


### Por que Redis?

Toda navegação entre telas reconsultava o banco (views com JOINs pesados).	Cache com TTL reduz chamadas ao PostgreSQL em ~90% durante uso normal.
Múltiplos usuários poderiam sobrecarregar o banco com as mesmas queries.	O cache é compartilhado (Upstash cloud) — um MISS popula para todos.
Dados de leitura (vendas, estoque) mudam pouco em relação à frequência de consulta.	TTL curto (30–120 s) equilibra frescor e performance.
Necessidade de invalidação após escritas.	DEL das chaves após cada CALL de procedure garante consistência.

Benefícios observados
Latência reduzida: consultas cacheadas respondem em < 5 ms (vs. 50–200 ms no banco).
Menor carga no Supabase: menos conexões simultâneas e menos queries de JOIN.
Escalabilidade: o cache fica fora do processo Python (Upstash), permitindo múltiplas instâncias.


### O Banco de dados:

#### *Tabelas:*
Script DDL para criação de todas as tabelas, chaves primárias/estrangeiras e constraints.
Define o esquema relacional completo do banco de dados. As tabelas estão organizadas nos seguintes módulos:

* Controle de Acesso e Usuários

   * **perfil**: Perfis de usuário (ex: Administrador, Vendedor).
   
   * **permissao**: Lista de permissões do sistema (ex: CADASTRAR_PRODUTO, FINALIZAR_VENDA).
   
   * **perfil_permissao**: Tabela associativa entre perfis e permissões.
   
   * **funcionario**: Cadastro dos colaboradores, com senhas e vinculação aos perfis de acesso.

* Clientes e Fidelidade

   * **cliente**: Dados cadastrais dos clientes.
   
   * **movimentacao_pontos**: Histórico de acúmulo e resgate do programa de fidelidade.

* Produtos e Estoque

   * **categoria**: Categorização dos produtos.
   
   * **produto**: Informações gerais do produto (marca, preços base, código interno).
   
   * **produto_variacao**: Variações específicas do produto (tamanho, cor, SKU, código de barras e saldo em estoque).
   
   * **historico_preco**: Auditoria para alterações nos preços de custo e venda.
   
   * **movimentacao_estoque**: Registro de entradas, saídas, ajustes e devoluções de produtos.

* Vendas e Trocas (PDV)

   * **venda**: Cabeçalho das vendas realizadas (cupom, cliente, operador, descontos, totais).
   
   * **item_venda**: Itens vinculados a uma venda específica.
   
   * **pagamento_venda**: Formas de pagamento utilizadas na transação (PIX, Crédito, Débito, Pontos).
   
   * **troca**: Registro de operações de troca efetuadas.
   
   * **item_troca**: Registro dos itens devolvidos (ENTRADA) e retirados (SAIDA) em uma troca.

#### *Inserts:*
Dois scripts DML com dados iniciais para testes (perfis, usuários, produtos, vendas, etc.).
Responsáveis por popular o banco de dados com dados de teste simulando aoperação real do sistema:

* Perfis e Permissões: Criação dos perfis "Agatha Málevola" e "Samuels Seniors" com suas respectivas permissões.

* Funcionários e Clientes: Registros iniciais com CPFs e dados de contato.

* Catálogo de Produtos: Categorias (Roupas Masculinas, Calçados), produtos e suas variações de tamanho/cor com estoque inicial.

* Fluxo de Venda e Estorno/Troca: Exemplo completo de venda registrada, movimentação de pontos no programa de fidelidade e fluxo de troca de produto (troca de tamanho de camiseta).

#### *Views:*
Views para relatórios, monitoramento de estoque e consultas consolidadas.
* **vw_geral_estoque_produtos**: Visão completa conectando produtos às suas variações e exibe saldos e preços.

* **vw_estoque_critico**: Filtra variações de produtos cujo estoque atual está igual ou abaixo do estoque_minimo, calculando a quantidade necessária para reposição.

* **vw_resumo_caixa_diario**: Consolida o faturamento total, quantidade de vendas, descontos e ticket médio por funcionário/operador por data.

* **vw_vendas_recentes**: Traz as 10 últimas vendas realizadas ordenadas do lançamento mais recente para o mais antigo.
  
#### *Functions:*
Funções reutilizáveis para lógica de negócios e consultas.
* **fn_autenticar_funcionario(p_cpf, p_senha)**

   * Retorno: BOOLEAN
   
   * Objetivo: Valida se a combinação de CPF e senha corresponde a um funcionário cadastrado.

* **fn_status_produto(p_produto_id)**

   * Retorno: VARCHAR ('DISPONIVEL' ou 'SEM ESTOQUE')
   
   * Objetivo: Soma o estoque de todas as variações ativas de um produto e indica a disponibilidade geral.

* **fn_calcular_pontos_compra(p_pontos_total)**

   * Retorno: INTEGER
   
   * Objetivo: Calcula a pontuação acumulada com base no valor da compra (Fator de conversão: R$ 10,00 = 1 ponto, arredondado para baixo via FLOOR).
    
#### *Procedures:*
Procedimentos armazenados que encapsulam regras de negócio complexas:
* **registrar_venda(...)**
   * Valida a existência do cliente (caso informado).
   * Insere o cabeçalho da venda na tabela venda.
   * Gera automaticamente os pontos de fidelidade para o cliente através do cálculo da fn_calcular_pontos_compra.

* **adicionar_item_venda(...)**
   * Valida quantidade, venda e funcionário responsável.
   * Dá baixa automática no saldo do estoque em produto_variacao.
   * Insere o item na tabela item_venda.
   * Registra a movimentação física no histórico de movimentacao_estoque com o motivo "Baixa automática via PDV".

* **registrar_cliente(...)**
   * Cadastra um novo cliente simplificado no sistema.

* **registra_funcionarios(...)**
   * Sanitiza o CPF (remove caracteres não numéricos).
   * Impede a duplicidade de nome de usuário ou CPF.
   * Cria automaticamente um perfil para o usuário caso ele ainda não exista antes de inserir o funcionário.


### Python:

##### *PyQt6:*
Interface Grafica Nativa do Windows com, utilizo da conexão:

    vw_vendas_recentes,              # Presente na página vendas
    vw_geral_estoque_produtos,       # Presente na página vendas
    vw_estoque_critico,              # Presente na página vendas
    vw_resumo_caixa_diario,          # Presente na página vendas

    fn_autenticar_funcionario,       # Presente na página de cadastro / login
    fn_status_produto,               # Presente na página produto
    fn_calcular_pontos_compra,       # Presente na página cliente

    cadastrar_cliente,               # Presente na página de cadastro / login
    registrar_funcionarios,          # Presente na página de cadastro / login
    registrar_venda,                 # Presente na página vendas
    testar_conexao,                  # Presente na página main, venda e cadastro / login

    app_buscar_funcionario_por_cpf,  #Presente na página de Login / Perfil
    
##### *SQLAlchemy e pyscopg:*
Bibliotecas que fazem a comunicação Python<->SUPABASE SQL (pgAdmin4/ postgreSQL)



### Redis:
Consultas com chaves, baseados nas Views, Functions, Procedures e outros elementos da SUPABASE.

