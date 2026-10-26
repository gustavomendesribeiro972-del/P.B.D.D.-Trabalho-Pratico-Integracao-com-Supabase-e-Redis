--PROCEDURES
CREATE OR REPLACE PROCEDURE registrar_venda(
	p_empresa_id INTEGER,
	p_numero_cupom VARCHAR,
	p_cliente_id INTEGER,
	p_funcionario_id INTEGER,
	p_subtotal NUMERIC,
	p_desconto NUMERIC,
	p_total NUMERIC,
	p_observacao VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_cliente_existe BOOLEAN;
	v_funcionario_existe BOOLEAN;
BEGIN
	SELECT EXISTS (
		SELECT 1
		FROM funcionario f
		WHERE f.id_funcionario = p_funcionario_id AND f.perfil_id IN (
			SELECT p.id_perfil
			FROM perfil p
			WHERE p.empresa_id = p_empresa_id
		)
	)
	INTO v_funcionario_existe;

	IF NOT v_funcionario_existe THEN
			RAISE EXCEPTION
					'Funcionário não encontrado nesta empresa.';
	END IF;

	IF p_cliente_id IS NOT NULL THEN
		SELECT EXISTS (
			SELECT 1
			FROM cliente c
			WHERE c.id_cliente = p_cliente_id AND c.empresa_id = p_empresa_id
		)
		INTO v_cliente_existe;

		IF NOT v_cliente_existe THEN
				RAISE EXCEPTION
						'Cliente não encontrado nesta empresa.';
		END IF;
	END IF;

	IF p_subtotal < 0 OR p_desconto < 0 OR p_desconto > p_subtotal THEN
			RAISE EXCEPTION 'Valores da venda inválidos.';
	END IF;

	INSERT INTO venda (
			empresa_id,
			numero_cupom,
			cliente_id,
			funcionario_id,
			subtotal,
			desconto,
			total,
			status,
			observacao
	)
	VALUES (
			p_empresa_id,
			p_numero_cupom,
			p_cliente_id,
			p_funcionario_id,
			p_subtotal,
			p_desconto,
			p_total,
			'EM ANDAMENTO',
			p_observacao
	);
END;
$$;

CREATE OR REPLACE PROCEDURE adicionar_item_venda(
	p_venda_id INTEGER,
	p_variacao_id INTEGER,
	p_quantidade INTEGER,
	p_preco_unitario NUMERIC,
	p_desconto_item NUMERIC
)
LANGUAGE plpgsql 
AS $$
DECLARE
	v_empresa_id INTEGER;
	v_subtotal NUMERIC(10, 2);
	v_funcionario_id INTEGER;
	v_status_venda VARCHAR(30);
BEGIN
	IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
		RAISE EXCEPTION 'Quantidade deve ser maior que zero.';
	END IF;

	IF p_preco_unitario IS NULL OR p_preco_unitario < 0 THEN
		RAISE EXCEPTION 'Preço unitário inválido.';
	END IF;

	IF p_desconto_item IS NULL OR p_desconto_item < 0 OR p_desconto_item > p_quantidade * p_preco_unitario THEN
		RAISE EXCEPTION 'Desconto do item inválido.';
	END IF;

	SELECT empresa_id, funcionario_id, status
	INTO v_empresa_id, v_funcionario_id, v_status_venda
	FROM venda
	WHERE id_venda = p_venda_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Venda de ID % não encontrada.', p_venda_id;
	END IF;

	IF v_status_venda <> 'EM ANDAMENTO' THEN
		RAISE EXCEPTION 'A venda não está em andamento.';
	END IF;

	v_subtotal := (p_quantidade * p_preco_unitario) - p_desconto_item;

	UPDATE produto_variacao
	SET quantidade_estoque = quantidade_estoque - p_quantidade
	WHERE id_variacao = p_variacao_id
		AND quantidade_estoque >= p_quantidade
		AND status = 'ATIVO';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Estoque insuficiente ou variação % inexistente/inativa.', p_variacao_id;
	END IF;

	INSERT INTO item_venda (
		venda_id,
		variacao_id,
		quantidade,
		preco_unitario,
		desconto_item,
		subtotal
	)
	VALUES (
		p_venda_id,
		p_variacao_id,
		p_quantidade,
		p_preco_unitario,
		p_desconto_item,
		v_subtotal
	);

	INSERT INTO movimentacao_estoque (
		variacao_id,
		funcionario_id,
		venda_id,
		tipo,
		quantidade,
		motivo_obs,
		origem_ref
	)
	VALUES (
		p_variacao_id,
		v_funcionario_id,
		p_venda_id,
		'SAIDA',
		p_quantidade,
		'Baixa de estoque via PDV',
		p_venda_id::VARCHAR
	);
END;
$$;

CREATE OR REPLACE PROCEDURE registrar_cliente(
	p_empresa_id INTEGER,
	p_nome VARCHAR,
	p_cpf VARCHAR,
	p_email VARCHAR,
	p_data_nascimento DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
	IF NOT EXISTS (
		SELECT 1
		FROM empresa
		WHERE id_empresa = p_empresa_id
	) THEN
		RAISE EXCEPTION 'Empresa não encontrada.';
	END IF;

	IF NULLIF(TRIM(p_nome), '') IS NULL THEN
			RAISE EXCEPTION 'O nome do cliente é obrigatório.';
	END IF;

	INSERT INTO cliente (
		empresa_id,
		nome_cliente,
		cpf,
		email
	)
	VALUES (
		p_empresa_id,
		TRIM(p_nome),
		NULLIF(p_cpf, 'desconhecido'),
		NULLIF(TRIM(p_email), 'desconhecido'),
		NULLIF(p_data_nascimento, 'desconhecido')
	);
END;
$$;

CREATE OR REPLACE PROCEDURE registra_funcionarios(
	p_empresa_id INTEGER,
	p_perfil_id INTEGER,
	p_nomeUsuario VARCHAR,
	p_nomeApelido VARCHAR,
	p_cpf VARCHAR,
	p_telefone VARCHAR,
	p_email VARCHAR,
	p_senha VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_cpf VARCHAR(11);
BEGIN
	IF NOT EXISTS (
		SELECT 1
		FROM empresa
		WHERE empresa_id = p_empresa_id
	) THEN
		RAISE EXCEPTION 'Empresa não encontrada.';
	END IF;

	IF NOT EXISTS (
		SELECT 1
		FROM perfil
		WHERE id_perfil = p_perfil_id AND empresa_id = p_empresa_id
	) THEN
		RAISE EXCEPTION 'Perfil não encontrado nesta empresa.';
	END IF;	

	IF NULLIF(TRIM(p_nomeUsuario), '') IS NULL
		OR NULLIF(TRIM(p_nomeApelido), '') IS NULL
		OR NULLIF(TRIM(p_email), '') IS NULL
		OR NULLIF(p_senha, '') IS NULL THEN
		RAISE EXCEPTION 'Preencha todos os campos obrigatórios.';
	END IF;

	IF LENGTH(p_senha) > 20 THEN
		RAISE EXCEPTION 'A senha deve ter no máximo 20 caracteres.';
	END IF;

	v_cpf := REGEXP_REPLACE(COALESCE(p_cpf, ''), '[^0-9]', '', 'g');

	IF LENGTH(v_cpf) <> 11 then
		RAISE EXCEPTION 'O CPF deve conter 11 dígitos.';
	END IF;

	IF EXISTS (
		SELECT 1
		FROM funcionario
		WHERE empresa_id = p_empresa_id AND (
			LOWER(TRIM(nome_usuario)) = LOWER(TRIM(p_nome_usuario))
			OR cpf = REGEXP_REPLACE(p_cpf, '[^0-9]', '', 'g')
		)
	) THEN
		RAISE EXCEPTION
			'Nome de usuário ou CPF já cadastrado nesta empresa.';
	END IF;

	INSERT INTO funcionario (
		empresa_id,
		perfil_id,
		nome_usuario,
		nome_apelido,
		cpf,
		telefone,
		email,
		senha
	)
	VALUES (
		p_empresa_id,
		p_perfil_id,
		TRIM(p_nome_usuario),
		p_nome_apelido,
		REGEXP_REPLACE(p_cpf, '[^0-9]', '', 'g'),
		p_telefone,
		p_email,
		p_senha
	);
END;
$$;

--Procedure nova:
CREATE OR REPLACE PROCEDURE finalizar_venda(
	p_venda_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_cliente_id INTEGER;
	v_empresa_id INTEGER;
	v_numero_cupom VARCHAR(20);
	v_total NUMERIC(10, 2);
	v_subtotal NUMERIC(10, 2);
	v_desconto NUMERIC(10, 2);
	v_quantidade_itens INTEGER;
	v_pontos INTEGER;
BEGIN
	SELECT empresa_id, cliente_id, numero_cupom
	INTO v_empresa_id, v_cliente_id, v_numero_cupom
	FROM venda
	WHERE id_venda = p_venda_id AND status = 'EM ANDAMENTO';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Venda não encontrada ou não está em andamento.';
	END IF;

	SELECT COUNT(*)
	INTO v_quantidade_itens
	FROM item_venda
	WHERE venda_id = p_venda_id AND empresa_id = v_empresa_id;

	IF v_quantidade_itens = 0 THEN
		RAISE EXCEPTION 'Não é possível finalizar uma venda sem itens.';
	END IF;

	SELECT
		SUM(quantidade * preco_unitario),
		SUM(desconto_item),
		SUM(subtotal)
	INTO
		v_subtotal,
		v_desconto,
		v_total
	FROM item_venda
	WHERE venda_id = p_venda_id AND empresa_id = v_empresa_id;

	UPDATE venda
	SET
		subtotal = v_subtotal,
		desconto = v_desconto,
		total = v_total,
		status = 'CONCLUÍDA'
	WHERE id_venda = p_venda_id AND empresa_id = v_empresa_id;

	IF v_cliente_id IS NOT NULL THEN
		v_pontos := fn_calcular_pontos_compra(v_total);

		IF v_pontos > 0 THEN
			INSERT INTO movimentacao_pontos (
				empresa_id,
				cliente_id,
				tipo,
				quantidade,
				origem,
				observacao
			)
			VALUES (
				v_empresa_id,
				v_cliente_id,
				'ENTRADA',
				v_pontos,
				'COMPRA',
				'Pontos da venda ' || v_numero_cupom
			);
		END IF;
	END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE registrar_empresa(
	p_nome VARCHAR,
	p_cnpj VARCHAR,
	p_descricao VARCHAR,
	p_senha VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_cnpj VARCHAR;
BEGIN
	IF NULLIF(TRIM(p_nome), '') IS NULL THEN
		RAISE EXCEPTION 'O nome da empresa é obrigatório.';
	END IF;

	v_cnpj := REGEXP_REPLACE(p_cnpj, '[^0-9]', '', 'g');

	IF v_cnpj IS NULL OR LENGTH(v_cnpj) <> 14 THEN
		RAISE EXCEPTION 'O CNPJ deve conter 14 dígitos.';
	END IF;

	IF NULLIF(p_senha, '') IS NULL THEN
		RAISE EXCEPTION 'A senha é obrigatória.';
	END IF;

	IF LENGTH(p_senha) > 20 THEN
		RAISE EXCEPTION 'A senha deve ter no máximo 20 caracteres.';
	END IF;

	INSERT INTO empresa(
		nomefantasia_empresa,
		cnpj_empresa,
		descricao_empresa,
		senha
	)
	VALUES(
		p_nome,
		v_cnpj,
		p_descricao,
		p_senha
	);
END;
$$;

CREATE OR REPLACE PROCEDURE registrar_administrador_inicial(
	p_empresa_id INTEGER,
	p_nome_usuario VARCHAR,
	p_nome_apelido VARCHAR,
	p_cpf VARCHAR,
	p_telefone VARCHAR,
	p_email VARCHAR,
	p_senha VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_perfil_id INTEGER;
	v_cpf VARCHAR(11);
BEGIN

	PERFORM 1
	FROM empresa
	WHERE id_empresa = p_empresa_id
	FOR UPDATE;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Empresa não encontrada.';
	END IF;

	IF EXISTS (
		SELECT 1
		FROM funcionario
		WHERE empresa_id = p_empresa_id
	) THEN
		RAISE EXCEPTION
			'A empresa já possui funcionários. '
			'O cadastro inicial não está disponível.';
	END IF;

	IF NULLIF(TRIM(p_nome_usuario), '') IS NULL
		OR NULLIF(TRIM(p_nome_apelido), '') IS NULL
		OR NULLIF(TRIM(p_email), '') IS NULL
		OR NULLIF(p_senha, '') IS NULL THEN
		RAISE EXCEPTION 'Preencha todos os campos obrigatórios.';
	END IF;

	IF LENGTH(p_senha) > 20 THEN
		RAISE EXCEPTION 'A senha deve ter no máximo 20 caracteres.';
	END IF;

	v_cpf := REGEXP_REPLACE(
		COALESCE(p_cpf, ''), '[^0-9]', '', 'g'
	);

	IF LENGTH(v_cpf) <> 11 THEN
		RAISE EXCEPTION 'O CPF deve conter 11 dígitos.';
	END IF;

	-- Procura o perfil de administrador da empresa.
	SELECT id_perfil
	INTO v_perfil_id
	FROM perfil
	WHERE empresa_id = p_empresa_id
		AND nome_perfil = 'ADMINISTRADOR';

	-- Cria o perfil se ele ainda não existir.
	IF v_perfil_id IS NULL THEN
		INSERT INTO perfil (
			empresa_id,
			nome_perfil
		)
		VALUES (
			p_empresa_id,
			'ADMINISTRADOR'
		)
		RETURNING id_perfil INTO v_perfil_id;
	END IF;

	-- Associa ao administrador todas as permissões existentes.
	INSERT INTO perfil_permissao (
			perfil_id,
			permissao_id
	)
	SELECT
			v_perfil_id,
			p.id_permissao
	FROM permissao p
	ON CONFLICT (perfil_id, permissao_id) DO NOTHING;

	-- Cadastra o primeiro funcionário.
	INSERT INTO funcionario (
			empresa_id,
			perfil_id,
			nome_usuario,
			nome_apelido,
			cpf,
			telefone,
			email,
			senha,
			status
	)
	VALUES (
			p_empresa_id,
			v_perfil_id,
			TRIM(p_nome_usuario),
			TRIM(p_nome_apelido),
			v_cpf,
			NULLIF(TRIM(p_telefone), ''),
			LOWER(TRIM(p_email)),
			p_senha,
			'ATIVO'
	);
END;
$$;

--Testes:
CALL registrar_cliente('YGONA MOURA', '12345678911', 'ygona@empresa.com');
CALL registra_funcionarios('gerente_vendas', 'Marcos Oliveira', '55544433322', '(11) 96666-5555', 'marcos@empresa.com', 'hash_senha_999');
CALL registrar_venda('teste23233577', 1, 2, 50.00, 5.00, 45.00, 'teste');
CALL registrar_empresa('Disconexo Lanches', '1232345345666', 'Lanches sem contatinhos', '1234')
CALL adicionar_item_venda(1, 2, 1, 120.00, 23.00);
CALL finalizar_venda(2);
