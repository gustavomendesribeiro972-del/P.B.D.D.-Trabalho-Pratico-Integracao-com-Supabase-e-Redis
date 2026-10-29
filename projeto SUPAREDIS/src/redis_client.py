import os
import redis

REDIS_URL = os.getenv(
    "REDIS_URL",
    "redis://default:bTwyiIdbWzPeJomacyoJnWhG0y0Vp3R8@wrist-neosnug-ensuring-25972.db.redis.io:19869"
)

redis_client = redis.Redis.from_url(
    REDIS_URL,
    decode_responses=True,
    socket_connect_timeout=2,
    socket_timeout=2,
    health_check_interval=30,
)

try:
    if redis_client.ping():
        print("Conexão Python <-> Redis estabelecida!")

    redis_client.set("teste_integracao", "funcionando")
    valor = redis_client.get("teste_integracao")

    assert valor == "funcionando"
    print("Leitura e escrita no Redis confirmadas.")

    redis_client.delete("teste_integracao")

except redis.RedisError as e:
    print(f"Erro na integração com Redis: {e}")
    raise

