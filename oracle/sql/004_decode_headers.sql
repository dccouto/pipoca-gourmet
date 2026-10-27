-- Decodifica campos percent-encoded enviados pelo front (UTF-8).
CREATE OR REPLACE PACKAGE BODY catalog_api AS
  FUNCTION esc(p VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN REPLACE(REPLACE(REPLACE(NVL(p,''), '\', '\\'), '"', '\"'), CHR(10), '\n');
  END;

  FUNCTION dec(p VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p IS NULL THEN RETURN NULL; END IF;
    BEGIN
      RETURN UTL_URL.UNESCAPE(p, 'UTF-8');
    EXCEPTION
      WHEN OTHERS THEN RETURN p;
    END;
  END;

  FUNCTION bool_js(p NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN NVL(p,0) = 1 THEN 'true' ELSE 'false' END;
  END;

  FUNCTION to_bool(p VARCHAR2) RETURN NUMBER IS
  BEGIN
    IF LOWER(TRIM(NVL(p,'0'))) IN ('1','true','t','yes','y','on') THEN RETURN 1; END IF;
    RETURN 0;
  END;

  FUNCTION usuario_do_token(p_auth VARCHAR2) RETURN NUMBER IS
    l_raw   VARCHAR2(4000) := TRIM(NVL(p_auth,''));
    l_token VARCHAR2(256);
    l_hash  VARCHAR2(128);
    l_uid   NUMBER;
  BEGIN
    IF UPPER(SUBSTR(l_raw, 1, 7)) = 'BEARER ' THEN
      l_token := TRIM(SUBSTR(l_raw, 8));
    ELSE
      l_token := l_raw;
    END IF;
    IF l_token IS NULL THEN RETURN NULL; END IF;
    l_hash := auth_util.sha256_hex(l_token);
    SELECT s.usuario_id INTO l_uid
      FROM sessao_token s
      JOIN usuarios_admin u ON u.id = s.usuario_id
     WHERE s.token_hash = l_hash
       AND s.expira_em > SYSTIMESTAMP
       AND u.ativo = 1
       AND ROWNUM = 1;
    RETURN l_uid;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
    WHEN OTHERS THEN RETURN NULL;
  END;

  FUNCTION sabor_obj(r sabores%ROWTYPE) RETURN VARCHAR2 IS
  BEGIN
    RETURN '{'
      || '"id":' || r.id
      || ',"nome":"' || esc(r.nome) || '"'
      || ',"emoji":"' || esc(r.emoji) || '"'
      || ',"descricao":"' || esc(TRIM(r.descricao)) || '"'
      || ',"preco_centavos":' || r.preco_centavos
      || ',"cor":"' || esc(r.cor) || '"'
      || ',"ativo":' || bool_js(r.ativo)
      || ',"ordem":' || r.ordem
      || '}';
  END;

  FUNCTION kit_obj(r kits%ROWTYPE) RETURN VARCHAR2 IS
  BEGIN
    RETURN '{'
      || '"id":' || r.id
      || ',"nome":"' || esc(r.nome) || '"'
      || ',"descricao":"' || esc(TRIM(r.descricao)) || '"'
      || ',"preco_centavos":' || r.preco_centavos
      || ',"destaque":' || bool_js(r.destaque)
      || ',"selo":"' || esc(TRIM(r.selo)) || '"'
      || ',"ativo":' || bool_js(r.ativo)
      || ',"ordem":' || r.ordem
      || '}';
  END;

  FUNCTION lista_sabores_json(p_so_ativos VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out CLOB := '[';
    l_first BOOLEAN := TRUE;
    l_filtra NUMBER := to_bool(p_so_ativos);
  BEGIN
    FOR r IN (
      SELECT * FROM sabores
       WHERE l_filtra = 0 OR ativo = 1
       ORDER BY ordem, nome
    ) LOOP
      IF NOT l_first THEN l_out := l_out || ','; END IF;
      l_out := l_out || sabor_obj(r);
      l_first := FALSE;
    END LOOP;
    RETURN l_out || ']';
  END;

  FUNCTION lista_kits_json(p_so_ativos VARCHAR2 DEFAULT NULL) RETURN CLOB IS
    l_out CLOB := '[';
    l_first BOOLEAN := TRUE;
    l_filtra NUMBER := to_bool(p_so_ativos);
  BEGIN
    FOR r IN (
      SELECT * FROM kits
       WHERE l_filtra = 0 OR ativo = 1
       ORDER BY ordem, nome
    ) LOOP
      IF NOT l_first THEN l_out := l_out || ','; END IF;
      l_out := l_out || kit_obj(r);
      l_first := FALSE;
    END LOOP;
    RETURN l_out || ']';
  END;

  FUNCTION config_json RETURN CLOB IS
    r configuracoes%ROWTYPE;
  BEGIN
    SELECT * INTO r FROM configuracoes WHERE id = 1;
    RETURN '{'
      || '"id":1'
      || ',"numero_whatsapp":"' || esc(r.numero_whatsapp) || '"'
      || ',"nome_exibido":"' || esc(r.nome_exibido) || '"'
      || ',"slogan":"' || esc(r.slogan) || '"'
      || '}';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN '{"id":1,"numero_whatsapp":"","nome_exibido":"POPE","slogan":""}';
  END;

  FUNCTION upsert_sabor_json(
    p_auth VARCHAR2, p_id NUMBER, p_nome VARCHAR2, p_emoji VARCHAR2,
    p_descricao VARCHAR2, p_preco NUMBER, p_cor VARCHAR2,
    p_ativo VARCHAR2, p_ordem NUMBER
  ) RETURN CLOB IS
    l_uid NUMBER := usuario_do_token(p_auth);
    l_id  NUMBER := p_id;
    l_ativo NUMBER;
    l_emoji VARCHAR2(16);
    l_desc VARCHAR2(1000);
    l_cor VARCHAR2(16);
    l_nome VARCHAR2(120);
    r     sabores%ROWTYPE;
  BEGIN
    IF l_uid IS NULL THEN RETURN '{"erro":"nao autorizado"}'; END IF;
    l_nome := TRIM(dec(p_nome));
    IF l_nome IS NULL THEN RETURN '{"erro":"nome obrigatorio"}'; END IF;

    l_ativo := to_bool(p_ativo);
    l_emoji := NVL(NULLIF(TRIM(dec(p_emoji)), ''), UNISTR('\D83C\DF7F'));
    l_desc := NVL(dec(p_descricao), ' ');
    IF TRIM(l_desc) IS NULL THEN l_desc := ' '; END IF;
    l_cor := NVL(NULLIF(TRIM(dec(p_cor)), ''), '#E8A838');

    IF l_id IS NULL OR l_id = 0 THEN
      INSERT INTO sabores (nome, emoji, descricao, preco_centavos, cor, ativo, ordem)
      VALUES (l_nome, l_emoji, l_desc, NVL(p_preco, 0), l_cor, l_ativo, NVL(p_ordem, 0))
      RETURNING id INTO l_id;
    ELSE
      UPDATE sabores SET
        nome = l_nome, emoji = l_emoji, descricao = l_desc,
        preco_centavos = NVL(p_preco, 0), cor = l_cor, ativo = l_ativo,
        ordem = NVL(p_ordem, 0), atualizado_em = SYSTIMESTAMP
      WHERE id = l_id;
      IF SQL%ROWCOUNT = 0 THEN RETURN '{"erro":"sabor nao encontrado"}'; END IF;
    END IF;
    COMMIT;
    SELECT * INTO r FROM sabores WHERE id = l_id;
    RETURN sabor_obj(r);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '{"erro":"falha","detalhe":"' || esc(SQLERRM) || '"}';
  END;

  FUNCTION delete_sabor_json(p_auth VARCHAR2, p_id NUMBER) RETURN CLOB IS
    l_uid NUMBER := usuario_do_token(p_auth);
  BEGIN
    IF l_uid IS NULL THEN RETURN '{"erro":"nao autorizado"}'; END IF;
    DELETE FROM sabores WHERE id = p_id;
    IF SQL%ROWCOUNT = 0 THEN RETURN '{"erro":"sabor nao encontrado"}'; END IF;
    COMMIT;
    RETURN '{"ok":true}';
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '{"erro":"falha","detalhe":"' || esc(SQLERRM) || '"}';
  END;

  FUNCTION upsert_kit_json(
    p_auth VARCHAR2, p_id NUMBER, p_nome VARCHAR2, p_descricao VARCHAR2,
    p_preco NUMBER, p_destaque VARCHAR2, p_selo VARCHAR2,
    p_ativo VARCHAR2, p_ordem NUMBER
  ) RETURN CLOB IS
    l_uid NUMBER := usuario_do_token(p_auth);
    l_id  NUMBER := p_id;
    l_ativo NUMBER;
    l_destaque NUMBER;
    l_desc VARCHAR2(1000);
    l_selo VARCHAR2(80);
    l_nome VARCHAR2(120);
    r     kits%ROWTYPE;
  BEGIN
    IF l_uid IS NULL THEN RETURN '{"erro":"nao autorizado"}'; END IF;
    l_nome := TRIM(dec(p_nome));
    IF l_nome IS NULL THEN RETURN '{"erro":"nome obrigatorio"}'; END IF;

    l_ativo := to_bool(p_ativo);
    l_destaque := to_bool(p_destaque);
    l_desc := NVL(dec(p_descricao), ' ');
    IF TRIM(l_desc) IS NULL THEN l_desc := ' '; END IF;
    l_selo := NVL(dec(p_selo), ' ');
    IF TRIM(l_selo) IS NULL THEN l_selo := ' '; END IF;

    IF l_id IS NULL OR l_id = 0 THEN
      INSERT INTO kits (nome, descricao, preco_centavos, destaque, selo, ativo, ordem)
      VALUES (l_nome, l_desc, NVL(p_preco, 0), l_destaque, l_selo, l_ativo, NVL(p_ordem, 0))
      RETURNING id INTO l_id;
    ELSE
      UPDATE kits SET
        nome = l_nome, descricao = l_desc, preco_centavos = NVL(p_preco, 0),
        destaque = l_destaque, selo = l_selo, ativo = l_ativo,
        ordem = NVL(p_ordem, 0), atualizado_em = SYSTIMESTAMP
      WHERE id = l_id;
      IF SQL%ROWCOUNT = 0 THEN RETURN '{"erro":"kit nao encontrado"}'; END IF;
    END IF;
    COMMIT;
    SELECT * INTO r FROM kits WHERE id = l_id;
    RETURN kit_obj(r);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '{"erro":"falha","detalhe":"' || esc(SQLERRM) || '"}';
  END;

  FUNCTION delete_kit_json(p_auth VARCHAR2, p_id NUMBER) RETURN CLOB IS
    l_uid NUMBER := usuario_do_token(p_auth);
  BEGIN
    IF l_uid IS NULL THEN RETURN '{"erro":"nao autorizado"}'; END IF;
    DELETE FROM kits WHERE id = p_id;
    IF SQL%ROWCOUNT = 0 THEN RETURN '{"erro":"kit nao encontrado"}'; END IF;
    COMMIT;
    RETURN '{"ok":true}';
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '{"erro":"falha","detalhe":"' || esc(SQLERRM) || '"}';
  END;

  FUNCTION save_config_json(
    p_auth VARCHAR2, p_whatsapp VARCHAR2, p_nome VARCHAR2, p_slogan VARCHAR2
  ) RETURN CLOB IS
    l_uid NUMBER := usuario_do_token(p_auth);
    l_nome VARCHAR2(80);
    l_slogan VARCHAR2(240);
    l_whats VARCHAR2(32);
  BEGIN
    IF l_uid IS NULL THEN RETURN '{"erro":"nao autorizado"}'; END IF;
    l_whats := NVL(TRIM(REGEXP_REPLACE(dec(p_whatsapp), '[^0-9]', '')), ' ');
    IF TRIM(l_whats) IS NULL THEN l_whats := ' '; END IF;
    l_nome := NVL(TRIM(dec(p_nome)), 'POPE');
    l_slogan := NVL(dec(p_slogan), ' ');
    IF TRIM(l_slogan) IS NULL THEN l_slogan := ' '; END IF;

    UPDATE configuracoes SET
      numero_whatsapp = l_whats,
      nome_exibido = l_nome,
      slogan = l_slogan
    WHERE id = 1;
    IF SQL%ROWCOUNT = 0 THEN
      INSERT INTO configuracoes (id, numero_whatsapp, nome_exibido, slogan)
      VALUES (1, l_whats, l_nome, l_slogan);
    END IF;
    COMMIT;
    RETURN config_json();
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '{"erro":"falha","detalhe":"' || esc(SQLERRM) || '"}';
  END;
END catalog_api;
/
