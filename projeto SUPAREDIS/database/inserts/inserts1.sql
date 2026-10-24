--INSERTS 01
--**Dados ficticios:

INSERT INTO empresa (id_empresa, nomefantasia_empresa, cnpj_empresa, descricao_empresa, senha) 
VALUES (1, 'LojaCore Modas', '12345678000199', 'Loja de roupas e acessórios do sistema LojaCore', '1234');

INSERT INTO empresa_links (empresa_id, rede_nome, link) VALUES
(1, 'Instagram', 'https://instagram.com/lojacoremodas'),
(1, 'WhatsApp', 'https://wa.me/0500756056807');


INSERT INTO permissao (id_permissao, nome_permissao) VALUES
(1, 'GERENCIAR_FUNCIONARIOS'),
(2, 'GERENCIAR_PRODUTOS'),
(3, 'REALIZAR_VENDAS'),
(4, 'GERENCIAR_CLIENTES');

INSERT INTO perfil (id_perfil, empresa_id, nome_perfil) VALUES
(1, 1, 'admin'),
(2, 1, 'operador.de.caixa');

INSERT INTO perfil_permissao (perfil_id, permissao_id) VALUES
(1, 1), (1, 2), (1, 3), (1, 4),
(2, 3), (2, 4);


INSERT INTO funcionario (id_funcionario, empresa_id, perfil_id, nome_usuario, nome_apelido, cpf, telefone, email, senha, status) VALUES
(1, 1, 1, 'admin.core', 'Admin', '11122233344', '86988887777', 'admin@lojacore.com', '1234', 'ATIVO'),
(2, 1, 2, 'caixa.joao', 'João Caixa', '22233344455', '86977776666', 'joao@lojacore.com', '1234', 'ATIVO');

INSERT INTO cliente (id_cliente, empresa_id, nome_cliente, cpf, telefone, email, endereco, data_nascimento, status) VALUES
(1, 1, 'Maria Silva', '33344455566', '86966665555', 'maria.silva@email.com', 'Rua Principal, 100 - Teresina/PI', '1990-05-15', 'ATIVO'),
(2, 1, 'Carlos Souza', '44455566677', '86955554444', 'carlos.souza@email.com', 'Av. Central, 200 - Teresina/PI', '1985-10-20', 'ATIVO');


INSERT INTO categoria (id_categoria, empresa_id, nome, descricao) VALUES
(1, 1, 'Vestuário', 'Roupas em geral'),
(2, 1, 'Calçados', 'Sapatos e tênis');

INSERT INTO produto (id_produto, empresa_id, categoria_id, codigo_interno, nome_produto, descricao_produto, marca) VALUES
(1, 1, 1, 'CAM-01', 'Camiseta Básica Algodão', 'Camiseta 100% algodão gola careca', 'LojaCore Basic'),
(2, 1, 2, 'TEN-01', 'Tênis Esportivo Casual', 'Tênis confortável para o dia a dia', 'RunFast');

INSERT INTO produto_variacao (id_variacao, empresa_id, produto_id, codigo_barras, sku_variacao, tamanho, cor, preco_custo, preco_venda, quantidade_estoque, estoque_minimo, status) VALUES
(1, 1, 1, '7891000000011', 'CAM-01-P-AZU', 'P', 'Azul', 25.00, 59.90, 15, 5, 'ATIVO'),
(2, 1, 1, '7891000000028', 'CAM-01-M-AZU', 'M', 'Azul', 25.00, 59.90, 20, 5, 'ATIVO'),
(3, 1, 2, '7892000000012', 'TEN-01-40-PRE', '40', 'Preto', 80.00, 199.90, 8, 3, 'ATIVO');


INSERT INTO venda (id_venda, empresa_id, numero_cupom, cliente_id, funcionario_id, subtotal, desconto, total, status, observacao) VALUES
(1, 1, 'CUP-00001', 1, 2, 259.80, 10.00, 249.80, 'CONCLUÍDA', 'Venda realizada à vista com desconto promocional');

INSERT INTO item_venda (id_item_venda, empresa_id, venda_id, variacao_id, quantidade, preco_unitario, desconto_item, subtotal) VALUES
(1, 1, 1, 2, 1, 59.90, 0.00, 59.90),
(2, 1, 1, 3, 1, 199.90, 10.00, 189.90);

INSERT INTO pagamento_venda (id_pagamento, empresa_id, venda_id, forma_pagamento, valor) VALUES
(1, 1, 1, 'PIX', 249.80);


INSERT INTO movimentacao_estoque (id_movimentacao, empresa_id, variacao_id, funcionario_id, venda_id, tipo, quantidade, motivo_obs, origem_ref) VALUES
(1, 1, 2, 2, 1, 'SAIDA', 1, 'Venda de produto - Cupom CUP-00001', 'VENDA'),
(2, 1, 3, 2, 1, 'SAIDA', 1, 'Venda de produto - Cupom CUP-00001', 'VENDA');