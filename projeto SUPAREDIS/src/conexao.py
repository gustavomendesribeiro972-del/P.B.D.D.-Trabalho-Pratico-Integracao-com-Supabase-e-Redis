import json
from decimal import Decimal
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Certifique-se de que o arquivo redis_client.py existe no mesmo diretório
try:
    from redis_client import redis_client
except ImportError:
    redis_client = None

# Substitua pela sua URL de conexão real com o banco de dados
DATABASE_URL = "postgresql://postgres:22MeuBem4A7bV13@db.zjbnogzcelpzljvcvkkx.supabase.co:5432/postgres"

engine = create_engine(
    DATABASE_URL, echo=False, pool_pre_ping=True
)
SessionLocal = sessionmaker(bind=engine)
print("Sessão local iniciada...")

def testar_conexao():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True, "Conexão com banco de dados efetuada com sucesso!"
    except Exception as e:
        return False, f"Falha na conexão: {e}"


# ==========================================
# FUNÇÕES AUXILIARES DE CACHE (REDIS)
# ==========================================

def consultar_com_cache(chave, consulta, ttl=60):
    """Tenta buscar do Redis; se falhar ou não existir, busca no banco e atualiza o cache."""
    if redis_client is not None:
        try:
            dados_cache = redis_client.get(chave)
            if dados_cache is not None:
                return json.loads(dados_cache)
        except Exception as erro:
            print(f"Redis indisponível na leitura do cache: {erro}")

    dados = consulta()
    dados_serializaveis = []

    for registro in dados or []:
        if hasattr(registro, "_mapping"):
            registro = dict(registro._mapping)
        elif isinstance(registro, dict):
            registro = dict(registro)
        elif isinstance(registro, (tuple, list)):
            registro = list(registro)
        else:
            registro = [registro]

        dados_serializaveis.append(registro)

    if redis_client is not None:
        try:
            redis_client.set(
                chave,
                json.dumps(
                    dados_serializaveis,
                    default=str,
                    ensure_ascii=False
                ),
                ex=ttl
            )
        except Exception as erro:
            print(f"Redis indisponível na gravação do cache: {erro}")

    return dados_serializaveis


def invalidar_cache(*chaves):
    """Remove chaves específicas do Redis para forçar atualização dos dados."""
    if redis_client is not None:
        try:
            if chaves:
                redis_client.delete(*chaves)
        except Exception as erro:
            print(f"Não foi possível invalidar o cache: {erro}")

def invalidar_cache_empresa(empresa_id, *views):
    if empresa_id is None:
        return
    
    empresa_id = int(empresa_id)

    nomes_permitidos = {
        "vw_vendas_recentes",
        "vw_geral_estoque_produtos",
        "vw_estoque_critico",
        "vw_resumo_caixa_diario",
        "vw_clientes_registrados",
        "vw_funcionarios_registrados",        
    }

    chaves = [
        f"lojacore:{nome}:empresa:{empresa_id}:v3"
        for nome in views
        if nome in nomes_permitidos
    ]

    invalidar_cache(*chaves)


# ==========================================
# VIEWS (Com Cache Integrado)
# ==========================================
def _consultar_view_empresa(nome_view, empresa_id, ttl=60):
    if empresa_id is None:
        raise ValueError("empresa_id é obrigatório.")

    empresa_id = int(empresa_id)

    if empresa_id <= 0:
        raise ValueError("empresa_id deve ser positivo.")

    views_permitidas = {
        "vw_vendas_recentes",
        "vw_geral_estoque_produtos",
        "vw_estoque_critico",
        "vw_resumo_caixa_diario",
        "vw_clientes_registrados",
        "vw_funcionarios_registrados",
    }

    if nome_view not in views_permitidas:
        raise ValueError("View não permitida.")

    chave = f"lojacore:{nome_view}:empresa:{empresa_id}:v3"

    def consultar_banco():
        with SessionLocal() as sessao:
            query = text(
                f"SELECT * FROM {nome_view} "
                "WHERE id_empresa = :empresa_id"
            )
            return sessao.execute(
                query,
                {"empresa_id": int(empresa_id)}
            ).fetchall()

    return consultar_com_cache(
        chave=chave,
        consulta=consultar_banco,
        ttl=ttl
    )

def vw_vendas_recentes(empresa_id):
    return _consultar_view_empresa(
        "vw_vendas_recentes", empresa_id, ttl=30
    )


def vw_geral_estoque_produtos(empresa_id):
    return _consultar_view_empresa(
        "vw_geral_estoque_produtos", empresa_id, ttl=60
    )


def vw_estoque_critico(empresa_id):
    return _consultar_view_empresa(
        "vw_estoque_critico", empresa_id, ttl=30
    )


def vw_resumo_caixa_diario(empresa_id):
    return _consultar_view_empresa(
        "vw_resumo_caixa_diario", empresa_id, ttl=30
    )


def vw_clientes_registrados(empresa_id):
    return _consultar_view_empresa(
        "vw_clientes_registrados", empresa_id, ttl=120
    )


def vw_funcionarios_registrados(empresa_id):
    return _consultar_view_empresa(
        "vw_funcionarios_registrados", empresa_id, ttl=120
    )


# ==========================================
# FUNCTIONS (Autenticação e Consultas Diretas)
# ==========================================

def fn_autenticar_empresa(cnpj, senha):
    with SessionLocal() as sessao:
        query = text("SELECT fn_autenticar_empresa(:p_cnpj, :p_senha)")
        resultado = sessao.execute(query, {"p_cnpj": cnpj, "p_senha": senha})
        return resultado.scalar_one_or_none()


def fn_autenticar_funcionario(cpf, senha):
    with SessionLocal() as sessao:
        query = text("SELECT fn_autenticar_funcionario(:p_cpf, :p_senha)")
        resultado = sessao.execute(query, {"p_cpf": cpf, "p_senha": senha})
        return resultado.scalar_one_or_none()


def fn_status_produto(produto_id):
    sessao = SessionLocal()
    try:
        query = text("SELECT fn_status_produto(:p_produto_id)")
        resultado = sessao.execute(query, {"p_produto_id": produto_id})
        linha = resultado.fetchone()
        return linha[0] if linha else None
    except Exception as e:
        print(f"Ocorreu um erro ao consultar o produto: {e}")
        raise
    finally:
        sessao.close()


def fn_calcular_pontos_compra(pontos_total):
    with SessionLocal() as sessao:
        try:
            query = text("SELECT fn_calcular_pontos_compra(:p_valor)")
            resultado = sessao.execute(query, {"p_valor": Decimal(str(pontos_total))})
            return resultado.scalar_one_or_none()
        except Exception as e:
            print(f"Não foi possível calcular os pontos: {e}")
        finally:
            sessao.close()


def fn_total_compras_cliente(p_cliente_id):
    with SessionLocal() as sessao:
        try:
            query = text("SELECT fn_total_compras_cliente(:p_cliente_id)")
            resultado = sessao.execute(query, {"p_cliente_id": Decimal(str(p_cliente_id))})
            return resultado.scalar_one_or_none()
        except Exception as e:
            print(f"Não foi possível consultar as compras do cliente: {e}")


# ==========================================
# PROCEDURES & ESCRITAS (Com Invalidação de Cache)
# ==========================================

def cadastrar_cliente(empresa_id: int, nome: str, cpf: str, email: str, data_nascimento=None):
    sessao = SessionLocal()
    try:
        query = text("""
            CALL registrar_cliente(
                CAST(:empresa_id AS INTEGER),
                CAST(:nome AS VARCHAR),
                CAST(:cpf AS VARCHAR),
                CAST(:email AS VARCHAR),
                CAST(:data_nascimento AS DATE)
            )
        """)
        sessao.execute(query, {
            "empresa_id": int(empresa_id),
            "nome": nome, 
            "cpf": cpf, 
            "email": email,
            "data_nascimento": data_nascimento
        })
        sessao.commit()
        
        invalidar_cache_empresa(empresa_id, "vw_clientes_registrados")
        
        return True, "Cliente cadastrado com sucesso!"
    except Exception as e:
        sessao.rollback()
        return False, f"Erro ao cadastrar cliente: {e}"
    finally:
        sessao.close()


def registrar_venda(empresa_id: int, cupom: str, cliente_id: int | None, funcionario_id: int, subtotal: float,
                    desconto: float, total: float, observacao: str):
    sessao = SessionLocal()
    try:
        query = text("""
            CALL registrar_venda(
                CAST(:empresa_id AS INTEGER),
                CAST(:cupom AS VARCHAR),
                CAST(:cliente AS INTEGER),
                CAST(:funcionario AS INTEGER), 
                CAST(:subtotal AS NUMERIC),
                CAST(:desconto AS NUMERIC),
                CAST(:total AS NUMERIC),
                CAST(:obs AS VARCHAR)
            );
        """)
        sessao.execute(query, {
            "empresa_id": int(empresa_id),
            "cupom": str(cupom),
            "cliente": (int(cliente_id) if cliente_id is not None else None),
            "funcionario": int(funcionario_id),
            "subtotal": Decimal(str(subtotal)),
            "desconto": Decimal(str(desconto)),
            "total": Decimal(str(total)),
            "obs": str(observacao)
        })
        sessao.commit()
        
        invalidar_cache_empresa(
            empresa_id,
            "vw_vendas_recentes",
            "vw_geral_estoque_produtos",
            "vw_estoque_critico",
            "vw_resumo_caixa_diario"            
        )
        return True, "Venda registrada com sucesso!"
    except Exception as e:
        sessao.rollback()
        msg_erro = str(e).split("\n")[0]
        return False, f"Erro: {msg_erro}"
    finally:
        sessao.close()


def adicionar_item_venda(empresa_id: int, venda_id: int, variacao_id: int, quantidade: int, preco_unitario: float, desconto_item: float):
    sessao = SessionLocal()
    try:
        query = text("""
            CALL adicionar_item_venda(
                CAST(:empresa_id AS INTEGER),
                CAST(:venda_id AS INTEGER),
                CAST(:variacao_id AS INTEGER),
                CAST(:quantidade AS INTEGER),
                CAST(:preco_unitario AS NUMERIC),
                CAST(:desconto_item AS NUMERIC)
            );
        """)
        sessao.execute(query, {
            "empresa_id": int(empresa_id),
            "venda_id": int(venda_id),
            "variacao_id": int(variacao_id),
            "quantidade": int(quantidade),
            "preco_unitario": float(preco_unitario),
            "desconto_item": float(desconto_item)
        })
        sessao.commit()
        
        invalidar_cache("lojacore:estoque:geral:v1", "lojacore:estoque:critico:v1")
        
        return True, "Item adicionado numa venda"
    except Exception as e:
        sessao.rollback()
        return False, f"Erro: {e}"
    finally:
        sessao.close()


def registrar_funcionarios(
        empresa_id: int,
        perfil_id: int,
        nome_usuario: str, 
        nome_apelido: str, 
        cpf: str, 
        telefone: str, 
        email: str, 
        senha: str
):
    sessao = SessionLocal()
    try:
        query = text("""
            CALL registra_funcionarios(
                CAST(:empresa_id AS INTEGER),
                CAST(:perfil_id AS INTEGER),
                CAST(:nome_usuario AS VARCHAR),
                CAST(:nome_apelido AS VARCHAR),
                CAST(:cpf AS VARCHAR),
                CAST(:telefone AS VARCHAR),
                CAST(:email AS VARCHAR),
                CAST(:senha AS VARCHAR)
            );
        """)
        sessao.execute(query, {
            "empresa_id": int(empresa_id),
            "perfil_id": int(perfil_id),
            "nome_usuario": nome_usuario,
            "nome_apelido": nome_apelido,
            "cpf": cpf,
            "telefone": telefone,
            "email": email,
            "senha": senha
        })
        sessao.commit()
        
        invalidar_cache_empresa(
            empresa_id,
            "vw_funcionarios_registrados"
        )
        
        return True, "Funcionário registrado com sucesso!"
    except Exception as e:
        sessao.rollback()
        msg_erro = str(e).split("\n")[0]
        return False, f"Erro: {msg_erro}"
    finally:
        sessao.close()


def registrar_empresa(
        nome: str, 
        cnpj: str, 
        descricao: str, 
        senha: str
):
    sessao = SessionLocal()
    try:
        query = text("""
            CALL registrar_empresa(
                CAST(:nome AS VARCHAR),
                CAST(:cnpj AS VARCHAR),
                CAST(:descricao AS VARCHAR),
                CAST(:senha AS VARCHAR)
            );
        """)
        sessao.execute(query, {
            "nome": nome,
            "cnpj": cnpj,
            "descricao": descricao,
            "senha": senha
        })
        sessao.commit()
        return True, "Empresa registrada com sucesso!"
    except Exception as e:
        sessao.rollback()
        msg_erro = str(e).split("\n")[0]
        return False, f"Erro: {msg_erro}"
    finally:
        sessao.close()


# ==========================================
# CONSULTAS DE APOIO (App)
# ==========================================

def app_buscar_funcionario_por_cpf(cpf, empresa_id):
    try:
        with engine.connect() as conexao:
            resultado = conexao.execute(
                text("""
                    SELECT
                        id_funcionario AS funcionario_id,
                        empresa_id,
                        cpf,
                        nome_usuario AS "nome_Usuario",
                        telefone,
                        email
                    FROM funcionario
                    WHERE cpf = :cpf AND empresa_id = :empresa_id AND status = 'ATIVO'
                """),
                {"cpf": "".join(c for c in str(cpf) if c.isdigit()), "empresa_id": int(empresa_id)}
            )

            funcionario = resultado.mappings().first()
            return dict(funcionario) if funcionario else None
        
    except Exception as e:
        print(f"Erro ao buscar funcionário: {e}")
        return None


def app_buscar_empresa_por_cnpj(cnpj):
    try:
        with engine.connect() as conexao:
            resultado = conexao.execute(
                text("""
                    SELECT
                        id_empresa AS empresa_id,
                        cnpj_empresa,
                        nomefantasia_empresa AS "nome_Empresa"
                    FROM empresa
                    WHERE cnpj_empresa = :cnpj
                """),
                {"cnpj": cnpj}
            )
            empresa = resultado.mappings().first()
            return dict(empresa) if empresa else None
    except Exception as e:
        print(f"Erro ao buscar a empresa: {e}")
        return None


def app_buscar_perfil_administrador(empresa_id: int):
    try:
        with engine.connect() as conexao:
            resultado = conexao.execute(
                text("""
                    SELECT pf.id_perfil
                    FROM perfil AS pf
                    JOIN perfil_permissao AS pp
                        ON pp.perfil_id = pf.id_perfil
                    JOIN permissao AS p
                        ON p.id_permissao = pp.permissao_id
                    WHERE pf.empresa_id = :empresa_id
                    GROUP BY pf.id_perfil
                    HAVING COUNT(DISTINCT p.nome_permissao) FILTER (
                        WHERE UPPER(p.nome_permissao) IN (
                            'GERENCIAR_FUNCIONARIOS',
                            'GERENCIAR_PRODUTOS',
                            'REALIZAR_VENDAS',
                            'GERENCIAR_CLIENTES'
                        )
                    ) = 4
                    ORDER BY pf.id_perfil
                    LIMIT 1
                """),
                {"empresa_id": int(empresa_id)}
            )

            linha = resultado.fetchone()
            return linha[0] if linha else None
        
    except Exception as e:
        print(f"Erro ao buscar perfil administrativo: {e}")
        return None


def app_buscar_permissoes_funcionario(cpf, empresa_id=None):
    try:
        with engine.connect() as conexao:
            resultado = conexao.execute(
                text("""
                    SELECT DISTINCT p.nome_permissao
                    FROM funcionario AS f
                    INNER JOIN perfil AS pf
                        ON pf.id_perfil = f.perfil_id
                    AND pf.empresa_id = f.empresa_id
                    INNER JOIN perfil_permissao AS pp
                        ON pp.perfil_id = pf.id_perfil
                    INNER JOIN permissao AS p
                        ON p.id_permissao = pp.permissao_id
                    WHERE f.cpf = :cpf
                    AND f.status = 'ATIVO'
                    AND (
                        CAST(:empresa_id AS INTEGER) IS NULL
                        OR f.empresa_id = :empresa_id
                    )
                    ORDER BY p.nome_permissao
                """),
                {
                    "cpf": "".join(caractere for caractere in str(cpf) if caractere.isdigit()), 
                    "empresa_id": empresa_id
                }
            )
            return [linha[0] for linha in resultado.fetchall()]
    except Exception as erro:
        print("Erro ao buscar permissões do funcionário:", erro)
        return None


def app_empresa_tem_funcionarios(empresa_id: int) -> bool:
    with engine.connect() as conexao:
        resultado = conexao.execute(
            text("""
                SELECT EXISTS (
                    SELECT 1
                    FROM funcionario
                    WHERE empresa_id = :empresa_id
                )
            """),
            {"empresa_id": int(empresa_id)}
        )
        return bool(resultado.scalar_one())
