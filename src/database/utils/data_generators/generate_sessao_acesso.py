"""
Gerador de dados sintéticos para a tabela sessao_acesso (log de login, base do DAU).

sessao_acesso depende de usuario já estar migrado (id_usuario é FK). Por isso, igual
a comodo/estante/etc., o CSV deste gerador tem que ser produzido em runtime dentro do
setup_data.py, DEPOIS do pipeline de usuario rodar — nunca como arquivo estático salvo
previamente.

Diferente dos outros geradores, aqui a quantidade de linhas NÃO é um parâmetro direto:
ela sai de uma simulação dia a dia, em que cada usuário tem um perfil de frequência
(intenso / regular / ocasional), a base de usuários "cresce" ao longo do período e o
fim de semana tem um pouco mais de uso. Assim vw_dau mostra uma curva realista no
print pra banca, em vez de uma linha reta. Quer mais ou menos linhas? Ajuste `dias`
ou os pesos/probabilidades de PERFIS.
"""
import csv
import os
import random
import uuid
from datetime import datetime, timedelta, timezone


FUSO_BR = timezone(timedelta(hours=-3))


PERFIS = {
    "intenso": (10, 0.55),
    "regular": (30, 0.20),
    "ocasional": (60, 0.05),
}


PESO_HORA = {
    6: 2, 7: 5, 8: 6, 9: 4, 10: 3, 11: 3, 12: 5, 13: 4, 14: 3,
    15: 3, 16: 3, 17: 4, 18: 6, 19: 8, 20: 8, 21: 6, 22: 3, 23: 1,
}


def buscar_ids(conn):
    """Busca os IDs de usuario já migrados, pra usar como FK em id_usuario."""
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM usuario")
        return [str(row[0]) for row in cur.fetchall()]


def _momento_aleatorio(dia):
    hora = random.choices(list(PESO_HORA), weights=list(PESO_HORA.values()))[0]
    return datetime(
        dia.year, dia.month, dia.day, hora,
        random.randint(0, 59), random.randint(0, 59),
        tzinfo=FUSO_BR,
    )


def gerar_sessoes_validas(ids_usuario, dias=60):
    """
    Simula `dias` dias de uso, terminando hoje. Cada usuário recebe um perfil fixo
    (probabilidade base de logar por dia); essa probabilidade é multiplicada por:
      - tendência: sobe de 0.6 a 1.0 ao longo do período (base de usuários crescendo);
      - fim de semana: x1.25 (faxina é coisa de sábado/domingo).
    Em ~20% dos dias ativos o usuário loga duas vezes. Nunca gera horário no futuro.
    """
    agora = datetime.now(FUSO_BR)
    hoje = agora.date()

    perfis = list(PERFIS)
    pesos = [PERFIS[p][0] for p in perfis]
    prob_base = {
        uid: PERFIS[random.choices(perfis, weights=pesos)[0]][1] for uid in ids_usuario
    }

    linhas, vistos = [], set()
    for i in range(dias):
        dia = hoje - timedelta(days=dias - 1 - i)
        tendencia = 0.6 + 0.4 * (i / max(dias - 1, 1))
        fator_dia = 1.25 if dia.weekday() >= 5 else 1.0

        for uid, base in prob_base.items():
            if random.random() >= min(0.95, base * tendencia * fator_dia):
                continue
            for _ in range(2 if random.random() < 0.2 else 1):
                momento = _momento_aleatorio(dia)
                if momento > agora or (uid, momento) in vistos:
                    continue
                vistos.add((uid, momento))
                linhas.append({
                    "id_usuario": uid,
                    "ocorreu_em": momento.isoformat(timespec="seconds"),
                })

    linhas.sort(key=lambda l: l["ocorreu_em"])
    return linhas



TIPOS_DE_RUIDO = {
    "id_usuario_invalido": 15,
    "id_usuario_inexistente": 15,
    "id_usuario_vazio": 15,
    "ocorreu_em_vazia": 10,
    "ocorreu_em_invalida": 20,
    "ocorreu_em_futura": 15,
    "duplicada": 10,
}


DATAS_INVALIDAS = [
    "ontem de manhã",
    "31/02/2026 10:00",
    "2026-13-45T99:99:99-03:00",
    "2026-02-31T10:00:00-03:00",
]


def gerar_linha_ruido(ids_usuario, linhas_validas):
    """Gera uma linha com algum problema, pra exercitar a validação da staging."""
    tipo = random.choices(
        list(TIPOS_DE_RUIDO.keys()),
        weights=list(TIPOS_DE_RUIDO.values()),
    )[0]

    if linhas_validas:
        linha = dict(random.choice(linhas_validas))
    else:
        linha = {
            "id_usuario": random.choice(ids_usuario),
            "ocorreu_em": datetime.now(FUSO_BR).isoformat(timespec="seconds"),
        }

    if tipo == "id_usuario_invalido":
        linha["id_usuario"] = "usuario-123-invalido"
    elif tipo == "id_usuario_inexistente":
        linha["id_usuario"] = str(uuid.uuid4())
    elif tipo == "id_usuario_vazio":
        linha["id_usuario"] = ""
    elif tipo == "ocorreu_em_vazia":
        linha["ocorreu_em"] = ""
    elif tipo == "ocorreu_em_invalida":
        linha["ocorreu_em"] = random.choice(DATAS_INVALIDAS)
    elif tipo == "ocorreu_em_futura":
        futuro = datetime.now(FUSO_BR) + timedelta(days=random.randint(1, 30))
        linha["ocorreu_em"] = futuro.isoformat(timespec="seconds")
    # "duplicada": devolve a cópia exata de uma linha válida (mesmo usuário + instante)

    return linha


def gerar_sessoes(ids_usuario, dias=60, proporcao_ruido=0.0, seed=None):
    """
    Gera as sessões válidas (simulação de `dias` dias) e acrescenta, no fim,
    `proporcao_ruido` x (qtd. de válidas) linhas propositalmente inválidas.
    proporcao_ruido=0 -> tudo válido, sem ruído proposital.
    """
    if not ids_usuario:
        raise RuntimeError(
            "Nenhum usuário encontrado em `usuario`. Rode a pipeline de usuario "
            "primeiro (sessao_acesso depende dela via FK) antes de gerar as sessões."
        )
    if seed is not None:
        random.seed(seed)

    validas = gerar_sessoes_validas(ids_usuario, dias=dias)
    n_ruido = round(len(validas) * proporcao_ruido)
    ruido = [gerar_linha_ruido(ids_usuario, validas) for _ in range(n_ruido)]
    return validas + ruido


def salvar_csv(linhas, caminho="src/database/sql/data_load/mocks/sessao_acesso.csv"):
    pasta = os.path.dirname(caminho)
    if pasta:
        os.makedirs(pasta, exist_ok=True)
    with open(caminho, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["id_usuario", "ocorreu_em"])
        writer.writeheader()
        writer.writerows(linhas)
    return caminho


if __name__ == "__main__":
    import argparse

    from src.database.connection import get_connection

    parser = argparse.ArgumentParser()
    parser.add_argument("--saida", default="src/database/sql/data_load/mocks/sessao_acesso.csv",
                        help="caminho do CSV de saída")
    parser.add_argument("--dias", type=int, default=60, help="janela de dias simulada")
    parser.add_argument("--ruido", type=float, default=0.0,
                        help="proporção de linhas propositalmente inválidas (0 a 1)")
    parser.add_argument("--seed", type=int, default=None, help="semente, pra repetir o mesmo CSV")
    args = parser.parse_args()

    conn = get_connection()
    try:
        ids_usuario = buscar_ids(conn)
    finally:
        conn.close()

    linhas = gerar_sessoes(ids_usuario, dias=args.dias, proporcao_ruido=args.ruido, seed=args.seed)
    caminho = salvar_csv(linhas, caminho=args.saida)
    print(f"{len(linhas)} linha(s) de sessao_acesso geradas em {caminho}")