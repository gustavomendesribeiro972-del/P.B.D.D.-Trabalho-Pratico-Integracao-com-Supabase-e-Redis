CREATE TABLE empresa (
	id_empresa SERIAL PRIMARY KEY,
	nomefantasia_empresa VARCHAR(55) NOT NULL,
	cnpj_empresa VARCHAR(14) NOT NULL UNIQUE,
	descricao_empresa VARCHAR(400) DEFAULT 'Uma empresa LojaCore',
	senha VARCHAR(20) NOT NULL
);

CREATE TABLE empresa_links (
  id_link SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  rede_nome VARCHAR(40) NOT NULL,
  link VARCHAR(2048) NOT NULL,

  CONSTRAINT fk_empresa_links
    FOREIGN KEY (empresa_id)
    REFERENCES empresa(id_empresa),

  CONSTRAINT uq_empresa_rede
    UNIQUE (empresa_id, rede_nome)
);

CREATE TABLE perfil (
  id_perfil SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  nome_perfil VARCHAR(60) NOT NULL,

  CONSTRAINT fk_perfil_empresa
    FOREIGN KEY (empresa_id)
    REFERENCES empresa(id_empresa),

  CONSTRAINT uq_perfil_empresa
    UNIQUE (empresa_id, nome_perfil),

  CONSTRAINT uq_perfil_id_empresa
    UNIQUE (id_perfil, empresa_id)
);

CREATE TABLE permissao (
  id_permissao SERIAL PRIMARY KEY,
  nome_permissao VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE perfil_permissao (
  perfil_id INTEGER NOT NULL,
  permissao_id INTEGER NOT NULL,

  PRIMARY KEY (perfil_id, permissao_id),

  CONSTRAINT fk_perfil_permissao_perfil
    FOREIGN KEY (perfil_id)
    REFERENCES perfil(id_perfil),

  CONSTRAINT fk_perfil_permissao_permissao
    FOREIGN KEY (permissao_id)
    REFERENCES permissao(id_permissao)
);

CREATE TABLE funcionario (
  id_funcionario SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  perfil_id INTEGER NOT NULL,
  nome_usuario VARCHAR(100) NOT NULL,
  nome_apelido VARCHAR(40) NOT NULL,
  cpf VARCHAR(11),
  telefone VARCHAR(25),
  email VARCHAR(254) NOT NULL,
  senha VARCHAR(20) NOT NULL,

  status VARCHAR(20) NOT NULL DEFAULT 'ATIVO' CHECK (status IN ('ATIVO', 'INATIVO', 'SUSPENSO')),

  criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT fk_funcionario_empresa
    FOREIGN KEY (empresa_id)
    REFERENCES empresa(id_empresa),

  CONSTRAINT fk_funcionario_perfil_empresa
    FOREIGN KEY (perfil_id, empresa_id)
    REFERENCES perfil(id_perfil, empresa_id),

  CONSTRAINT uq_funcionario_usuario
    UNIQUE (empresa_id, nome_usuario),

  CONSTRAINT uq_funcionario_cpf
    UNIQUE (empresa_id, cpf),

  CONSTRAINT uq_funcionario_email
    UNIQUE (empresa_id, email),

  CONSTRAINT uq_funcionario_id_empresa
    UNIQUE (id_funcionario, empresa_id)
);

CREATE TABLE cliente (
  id_cliente SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  nome_cliente VARCHAR(100) NOT NULL,
  cpf VARCHAR(11),
  telefone VARCHAR(25),
  email VARCHAR(254),
  endereco VARCHAR(250),
  data_nascimento DATE,

  status VARCHAR(20) NOT NULL DEFAULT 'ATIVO' CHECK (status IN ('ATIVO', 'INATIVO')),

  data_cadastro TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT fk_cliente_empresa
    FOREIGN KEY (empresa_id)
    REFERENCES empresa(id_empresa),

  CONSTRAINT uq_cliente_cpf
    UNIQUE (empresa_id, cpf),

  CONSTRAINT uq_cliente_id_empresa
    UNIQUE (id_cliente, empresa_id)
);

CREATE TABLE movimentacao_pontos (
  id_mov_pontos SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  cliente_id INTEGER NOT NULL,

  tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('ENTRADA', 'SAIDA')),
  quantidade INTEGER NOT NULL CHECK (quantidade > 0),

  origem VARCHAR(60) NOT NULL,
  data_hora TIMESTAMPTZ NOT NULL DEFAULT now(),
  observacao VARCHAR(120),

  CONSTRAINT fk_pontos_cliente_empresa
    FOREIGN KEY (cliente_id, empresa_id)
    REFERENCES cliente(id_cliente, empresa_id),

  CONSTRAINT fk_pontos_empresa
    FOREIGN KEY (empresa_id)
    REFERENCES empresa(id_empresa)
);

CREATE TABLE categoria (
	id_categoria SERIAL PRIMARY KEY,
	empresa_id INTEGER NOT NULL,
	nome VARCHAR(60) NOT NULL,
	descricao VARCHAR(255),

	CONSTRAINT fk_categoria_empresa
		FOREIGN KEY (empresa_id)
		REFERENCES empresa(id_empresa),

	CONSTRAINT uq_categoria_nome_empresa
		UNIQUE (empresa_id, nome),

	CONSTRAINT uq_categoria_id_empresa
		UNIQUE (id_categoria, empresa_id)
);

CREATE TABLE produto (
	id_produto SERIAL PRIMARY KEY,
	empresa_id INTEGER NOT NULL,
	categoria_id INTEGER NOT NULL,
	codigo_interno VARCHAR(100) NOT NULL,
	nome_produto VARCHAR(120) NOT NULL,
	descricao_produto TEXT,
	marca VARCHAR(100) NOT NULL,

	data_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
	data_alteracao TIMESTAMPTZ NOT NULL DEFAULT now(),

	CONSTRAINT fk_produto_empresa
		FOREIGN KEY (empresa_id)
		REFERENCES empresa(id_empresa),

	CONSTRAINT fk_produto_categoria_empresa
		FOREIGN KEY (categoria_id, empresa_id)
		REFERENCES categoria(id_categoria, empresa_id),

	CONSTRAINT uq_produto_codigo_empresa
		UNIQUE (empresa_id, codigo_interno),

	CONSTRAINT uq_produto_id_empresa
		UNIQUE (id_produto, empresa_id)
);

CREATE TABLE produto_variacao (
	id_variacao SERIAL PRIMARY KEY,
	empresa_id INTEGER NOT NULL,
	produto_id INTEGER NOT NULL,

	codigo_barras VARCHAR(50),
	sku_variacao VARCHAR(100) NOT NULL,
	tamanho VARCHAR(20) NOT NULL,
	cor VARCHAR(40) NOT NULL,

	preco_custo NUMERIC(10, 2) NOT NULL CHECK (preco_custo >= 0),
	preco_venda NUMERIC(10, 2) NOT NULL CHECK (preco_venda >= 0),
	quantidade_estoque INTEGER NOT NULL DEFAULT 0 CHECK (quantidade_estoque >= 0),
	estoque_minimo INTEGER NOT NULL DEFAULT 5 CHECK (estoque_minimo >= 0),
	status VARCHAR(20) NOT NULL DEFAULT 'ATIVO' CHECK (status IN ('ATIVO', 'INATIVO')),

	CONSTRAINT fk_variacao_produto_empresa
		FOREIGN KEY (produto_id, empresa_id)
		REFERENCES produto(id_produto, empresa_id),

	CONSTRAINT uq_variacao_sku_empresa
		UNIQUE (empresa_id, sku_variacao),

	CONSTRAINT uq_variacao_codigo_barras
		UNIQUE (empresa_id, codigo_barras),

	CONSTRAINT uq_variacao_produto_tamanho_cor
		UNIQUE (produto_id, tamanho, cor),

	CONSTRAINT uq_variacao_id_empresa
		UNIQUE (id_variacao, empresa_id)
);

CREATE TABLE historico_preco (
	id_historico_preco SERIAL PRIMARY KEY,
	empresa_id INTEGER NOT NULL,
	variacao_id INTEGER NOT NULL,

	prc_custo_anterior NUMERIC(10, 2) NOT NULL CHECK (prc_custo_anterior >= 0),
	prc_custo_novo NUMERIC(10, 2) NOT NULL CHECK (prc_custo_novo >= 0),
	prc_venda_anterior NUMERIC(10, 2) NOT NULL CHECK (prc_venda_anterior >= 0),
	prc_venda_novo NUMERIC(10, 2) NOT NULL CHECK (prc_venda_novo >= 0),

	data_alteracao TIMESTAMPTZ NOT NULL DEFAULT now(),
	funcionario_id INTEGER NOT NULL,

	CONSTRAINT fk_historico_variacao_empresa
		FOREIGN KEY (variacao_id, empresa_id)
		REFERENCES produto_variacao(id_variacao, empresa_id),

	CONSTRAINT fk_historico_funcionario_empresa
		FOREIGN KEY (funcionario_id, empresa_id)
		REFERENCES funcionario(id_funcionario, empresa_id)
);

CREATE TABLE venda (
  id_venda SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  numero_cupom VARCHAR(20) NOT NULL,
  data_hora TIMESTAMPTZ NOT NULL DEFAULT now(),
  cliente_id INTEGER,
  funcionario_id INTEGER NOT NULL,

  subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
  desconto NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (desconto >= 0 AND desconto <= subtotal),
  total NUMERIC(10, 2) NOT NULL CHECK (total >= 0),
  status VARCHAR(30) NOT NULL DEFAULT 'CONCLUÍDA' CHECK (status IN ('EM ANDAMENTO', 'CONCLUÍDA', 'CANCELADA')),
  observacao VARCHAR(120),

  CONSTRAINT fk_venda_empresa
    FOREIGN KEY (empresa_id)
    REFERENCES empresa(id_empresa),

  CONSTRAINT fk_venda_cliente_empresa
    FOREIGN KEY (cliente_id, empresa_id)
    REFERENCES cliente(id_cliente, empresa_id),

  CONSTRAINT fk_venda_funcionario_empresa
    FOREIGN KEY (funcionario_id, empresa_id)
    REFERENCES funcionario(id_funcionario, empresa_id),

  CONSTRAINT uq_venda_cupom_empresa
    UNIQUE (empresa_id, numero_cupom),

  CONSTRAINT uq_venda_id_empresa
    UNIQUE (id_venda, empresa_id)
);

CREATE TABLE item_venda (
  id_item_venda SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  venda_id INTEGER NOT NULL,
  variacao_id INTEGER NOT NULL,

  quantidade INTEGER NOT NULL CHECK (quantidade > 0),
  preco_unitario NUMERIC(10, 2) NOT NULL CHECK (preco_unitario >= 0),
  desconto_item NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (desconto_item >= 0 AND desconto_item <= quantidade * preco_unitario),
  subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal = quantidade * preco_unitario - desconto_item),

  CONSTRAINT fk_item_venda_empresa
    FOREIGN KEY (venda_id, empresa_id)
    REFERENCES venda(id_venda, empresa_id),

  CONSTRAINT fk_item_variacao_empresa
    FOREIGN KEY (variacao_id, empresa_id)
    REFERENCES produto_variacao(id_variacao, empresa_id),

  CONSTRAINT uq_item_venda_id_empresa
    UNIQUE (id_item_venda, empresa_id)
);

CREATE TABLE pagamento_venda (
  id_pagamento SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  venda_id INTEGER NOT NULL,

  forma_pagamento VARCHAR(30) NOT NULL CHECK (forma_pagamento IN ('DINHEIRO', 'PIX', 'CARTAO_CREDITO', 'CARTAO_DEBITO', 'PONTOS_FIDELIDADE', 'OUTRO')),
  valor NUMERIC(10, 2) NOT NULL CHECK (valor > 0),
  data_hora TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT fk_pagamento_venda_empresa
    FOREIGN KEY (venda_id, empresa_id)
    REFERENCES venda(id_venda, empresa_id)
);

CREATE TABLE movimentacao_estoque (
  id_movimentacao SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  variacao_id INTEGER NOT NULL,
  funcionario_id INTEGER NOT NULL,
  venda_id INTEGER,

  tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('ENTRADA', 'SAIDA', 'AJUSTE', 'DEVOLUCAO', 'TROCA')),

  quantidade INTEGER NOT NULL CHECK (quantidade > 0),

  data_hora TIMESTAMPTZ NOT NULL DEFAULT now(),
  motivo_obs VARCHAR(255),
  origem_ref VARCHAR(100),

  CONSTRAINT fk_mov_estoque_variacao_empresa
    FOREIGN KEY (variacao_id, empresa_id)
    REFERENCES produto_variacao(id_variacao, empresa_id),

  CONSTRAINT fk_mov_estoque_funcionario_empresa
    FOREIGN KEY (funcionario_id, empresa_id)
    REFERENCES funcionario(id_funcionario, empresa_id),

  CONSTRAINT fk_mov_estoque_venda_empresa
    FOREIGN KEY (venda_id, empresa_id)
    REFERENCES venda(id_venda, empresa_id)
);

CREATE TABLE troca (
  id_troca SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  venda_origem_id INTEGER NOT NULL,
  cliente_id INTEGER,
  funcionario_id INTEGER NOT NULL,

  data_hora TIMESTAMPTZ NOT NULL DEFAULT now(),
  valor_total_troca NUMERIC(10, 2) NOT NULL CHECK (valor_total_troca >= 0),
  observacao VARCHAR(255),

  CONSTRAINT fk_troca_venda_empresa
    FOREIGN KEY (venda_origem_id, empresa_id)
    REFERENCES venda(id_venda, empresa_id),

  CONSTRAINT fk_troca_cliente_empresa
    FOREIGN KEY (cliente_id, empresa_id)
    REFERENCES cliente(id_cliente, empresa_id),

  CONSTRAINT fk_troca_funcionario_empresa
    FOREIGN KEY (funcionario_id, empresa_id)
    REFERENCES funcionario(id_funcionario, empresa_id),

  CONSTRAINT uq_troca_id_empresa
    UNIQUE (id_troca, empresa_id)
);

CREATE TABLE item_troca (
  id_item_troca SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL,
  troca_id INTEGER NOT NULL,
  variacao_id INTEGER NOT NULL,
  item_venda_origem_id INTEGER,

  tipo_movimento VARCHAR(10) NOT NULL CHECK (tipo_movimento IN ('ENTRADA', 'SAIDA')),
  quantidade INTEGER NOT NULL CHECK (quantidade > 0),
  preco_unitario NUMERIC(10, 2) NOT NULL CHECK (preco_unitario >= 0),
  subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),

  CONSTRAINT fk_item_troca_empresa
    FOREIGN KEY (troca_id, empresa_id)
    REFERENCES troca(id_troca, empresa_id),

  CONSTRAINT fk_item_troca_variacao_empresa
    FOREIGN KEY (variacao_id, empresa_id)
    REFERENCES produto_variacao(id_variacao, empresa_id),

  CONSTRAINT fk_item_troca_venda_origem
    FOREIGN KEY (item_venda_origem_id, empresa_id)
    REFERENCES item_venda(id_item_venda, empresa_id)
);
