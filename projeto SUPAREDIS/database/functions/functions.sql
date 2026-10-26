--FUNCTIONS
CREATE OR REPLACE FUNCTION fn_autenticar_funcionario(
	p_cpf VARCHAR,
	p_senha VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN EXISTS (
		SELECT 1
		FROM funcionario f
		WHERE f.cpf = p_cpf
		AND f.senha = p_senha
		AND f.status = 'ATIVO'
	);
END;
$$;

CREATE OR REPLACE FUNCTION fn_autenticar_empresa(
	p_cnpj VARCHAR,
	p_senha VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN EXISTS (
		SELECT 1
		FROM empresa e
		WHERE e.cnpj_empresa = p_cnpj
		AND e.senha = p_senha
	);
END;
$$;

CREATE OR REPLACE FUNCTION fn_status_produto(
	p_produto_id INTEGER
)
RETURNS VARCHAR
AS $$
DECLARE
	v_total_estoque INTEGER;
BEGIN
	SELECT COALESCE(SUM(quantidade_estoque), 0)
	INTO v_total_estoque
	FROM produto_variacao pv
	WHERE pv.produto_id = p_produto_id AND pv.status = 'ATIVO';

	IF v_total_estoque > 0 THEN
		RETURN 'DISPONIVEL';
	ELSE
		RETURN 'SEM ESTOQUE';
	END IF;
END;
$$ 
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_calcular_pontos_compra(
	p_valor_compra NUMERIC
)
RETURNS INTEGER
AS $$
DECLARE
	v_fator_conversao NUMERIC := 10;
BEGIN
	IF p_valor_compra IS NULL OR p_valor_compra <= 0 THEN
		RETURN 0;
	END IF;
	
	RETURN FLOOR(p_valor_compra / v_fator_conversao);
END;
$$
LANGUAGE plpgsql;

--Function nova:
CREATE OR REPLACE FUNCTION fn_total_compras_cliente(
  p_cliente_id INTEGER
)
RETURNS NUMERIC(10, 2)
AS $$
DECLARE
  v_total NUMERIC(10, 2);
BEGIN
  SELECT COALESCE(SUM(v.total), 0)
  INTO v_total
  FROM venda v
  WHERE v.cliente_id = p_cliente_id AND v.status = 'CONCLUÍDA';
  RETURN v_total;
END;
$$ 
LANGUAGE plpgsql;

--Teste:
SELECT fn_autenticar_funcionario('11122233344', '1234');
SELECT fn_autenticar_empresa('12345678000199', '1234');
SELECT fn_calcular_pontos_compra(59.90);
SELECT fn_status_produto(2);
SELECT fn_total_compras_cliente(1);
