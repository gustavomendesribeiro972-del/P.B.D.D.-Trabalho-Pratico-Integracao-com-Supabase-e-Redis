
CREATE OR REPLACE VIEW vw_geral_estoque_produtos AS
SELECT
  e.id_empresa,
  e.nomefantasia_empresa AS nome_empresa,
	p.id_produto,
  p.nome_produto,
  p.marca,
	pv.id_variacao,
  p.codigo_interno,
	pv.sku_variacao,
  pv.codigo_barras,
	p.categoria_id,
	pv.quantidade_estoque AS estoque_disponivel,
	pv.estoque_minimo,
	pv.status,
	pv.preco_custo,
	pv.preco_venda AS custo_reajustado
FROM empresa e
INNER JOIN produto p ON  p.empresa_id = e.id_empresa
INNER JOIN produto_variacao pv ON p.id_produto = pv.produto_id AND pv.empresa_id = p.empresa_id;


CREATE OR REPLACE VIEW vw_estoque_critico AS
SELECT
  e.id_empresa,
  e.nomefantasia_empresa AS nome_empresa,
	p.id_produto,
	p.nome_produto,
	pv.id_variacao,
	pv.sku_variacao,
	pv.tamanho,
	pv.cor,
	pv.codigo_barras,
	pv.quantidade_estoque AS estoque_atual,
	pv.estoque_minimo,
	(pv.estoque_minimo - pv.quantidade_estoque) AS necessidade_reposicao
FROM produto_variacao pv
INNER JOIN produto p ON p.id_produto = pv.produto_id AND p.empresa_id = pv.empresa_id
INNER JOIN empresa e ON e.id_empresa = p.empresa_id 
WHERE pv.quantidade_estoque <= estoque_minimo AND pv.status = 'ATIVO';


CREATE OR REPLACE VIEW vw_resumo_caixa_diario AS
SELECT
    e.id_empresa,
    e.nomefantasia_empresa AS nome_empresa,
    f.id_funcionario,
    f.nome_Apelido AS nome_operador,
    DATE(ve.data_hora) AS data_venda,
    COUNT(ve.id_venda) AS quantidade_vendas,
    SUM(ve.subtotal) AS total_subtotal,
    SUM(ve.desconto) AS total_descontos,
    SUM(ve.total) AS total_faturado,
    ROUND(AVG(ve.total), 2) AS ticket_medio
FROM venda ve
INNER JOIN funcionario f ON f.id_funcionario = ve.funcionario_id AND f.empresa_id = ve.empresa_id
INNER JOIN empresa e ON e.id_empresa = ve.empresa_id
WHERE ve.status = 'CONCLUÍDA' 
GROUP BY e.id_empresa, e.nomefantasia_empresa, f.id_funcionario, f.nome_Apelido, DATE(ve.data_hora);


CREATE OR REPLACE VIEW vw_vendas_recentes AS
SELECT 
    e.id_empresa,
    e.nomefantasia_empresa AS nome_empresa,
    ve.id_venda, 
    ve.numero_cupom, 
    ve.cliente_id, 
    ve.funcionario_id,
    f.nome_Apelido AS nome_operador, 
    ve.total, 
    ve.status, 
    ve.data_hora
FROM venda ve 
INNER JOIN funcionario f ON f.id_funcionario = ve.funcionario_id
INNER JOIN empresa e ON e.id_empresa =ve.empresa_id
ORDER BY ve.data_hora DESC, ve.id_venda DESC;

--Views Novas:
CREATE OR REPLACE VIEW vw_clientes_registrados AS 
SELECT
  e.id_empresa,
  e.nomefantasia_empresa AS nome_empresa,
  c.id_cliente,
  c.nome_cliente,
  c.email,
  c.cpf,
  c.telefone,
  c.data_nascimento,
  c.data_cadastro
FROM cliente c
INNER JOIN empresa e ON e.id_empresa = c.empresa_id;


CREATE OR REPLACE VIEW vw_funcionarios_registrados AS 
SELECT
  e.id_empresa,
  e.nomefantasia_empresa AS nome_empresa,
  f.id_funcionario,
  f.nome_apelido AS nome_funcionario,
  f.perfil_id AS id_perfil,
  p.nome_perfil,
  f.cpf,
  f.email,
  f.telefone,
  f.status,
  f.criado_em AS data_de_cadastro,
  f.atualizado_em AS ultima_alteracao
FROM funcionario f
INNER JOIN empresa e ON e.id_empresa = f.empresa_id
INNER JOIN perfil p ON p.id_perfil = f.perfil_id AND p.empresa_id = f.empresa_id;


--Testes:
SELECT * FROM vw_vendas_recentes;
SELECT * FROM vw_geral_estoque_produtos;
SELECT * FROM vw_estoque_critico;
SELECT * FROM vw_resumo_caixa_diario;
SELECT * FROM vw_clientes_registrados WHERE id_empresa = 2;
SELECT * FROM vw_funcionarios_registrados WHERE id_empresa = 3;
