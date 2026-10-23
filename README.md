# Trabalho-Pratico-Integracao-com-Supabase-e-Redis
Trabalho Prático — Integração com Supabase e Redis, sendo implantado no aplicativo do trabalho anterior "LojaCore"

## TRABALHO PRÁTICO	PROJETO DE BANCO DE DADOS
INTEGRAÇÃO COM SUPABASE E REDIS
UNIFSA // ENGENHARIA DE SOFTWARE **28M4A**


#### Identificação:

* -Guilherme Mendes Ribeiro
* -Projeto de Banco de Dados
* -Anderson Soares da Costa


#### Sobre o projeto:

LojaCore é um aplicativo em PyQt6 CRUD simples. Com uma comunicação Python<->SQL Supabase realizada por meio da SQLAlchemy.


#### Tecnologias utilizadas:

* Supabase PostgreSQL;
* Python:
    * PyQt6(Interface Grafica),
    * SQLAlchemy,
    * psycopg



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
    
##### *SQLAlchemy:*
Biblioteca que faz a comunicação Python<->SQL (pgAdmin4/ postgreSQL)

