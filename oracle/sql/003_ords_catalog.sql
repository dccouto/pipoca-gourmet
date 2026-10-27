-- PipocaGourmet — API catálogo (público + admin com Bearer token)
-- Schema: PIPOCAG | Base: /ords/pipocag/api/
-- Endpoints públicos:
--   GET  /api/sabores?ativos=1
--   GET  /api/kits?ativos=1
--   GET  /api/config
-- Endpoints admin (header Authorization: Bearer <token>):
--   GET/POST /api/sabores | PUT/DELETE /api/sabores/:id
--   GET/POST /api/kits    | PUT/DELETE /api/kits/:id
--   PUT /api/config
--
-- Execute como PIPOCAG (REST SQL ou SQL Developer Web).

CREATE OR REPLACE PACKAGE catalog_api AS
  FUNCTION usuario_do_token(p_auth VARCHAR2) RETURN NUMBER;
  FUNCTION lista_sabores_json(p_so_ativos VARCHAR2 DEFAULT NULL) RETURN CLOB;
  FUNCTION lista_kits_json(p_so_ativos VARCHAR2 DEFAULT NULL) RETURN CLOB;
  FUNCTION config_json RETURN CLOB;
  FUNCTION upsert_sabor_json(
    p_auth VARCHAR2, p_id NUMBER, p_nome VARCHAR2, p_emoji VARCHAR2,
    p_descricao VARCHAR2, p_preco NUMBER, p_cor VARCHAR2,
    p_ativo VARCHAR2, p_ordem NUMBER
  ) RETURN CLOB;
  FUNCTION delete_sabor_json(p_auth VARCHAR2, p_id NUMBER) RETURN CLOB;
  FUNCTION upsert_kit_json(
    p_auth VARCHAR2, p_id NUMBER, p_nome VARCHAR2, p_descricao VARCHAR2,
    p_preco NUMBER, p_destaque VARCHAR2, p_selo VARCHAR2,
    p_ativo VARCHAR2, p_ordem NUMBER
  ) RETURN CLOB;
  FUNCTION delete_kit_json(p_auth VARCHAR2, p_id NUMBER) RETURN CLOB;
  FUNCTION save_config_json(
    p_auth VARCHAR2, p_whatsapp VARCHAR2, p_nome VARCHAR2, p_slogan VARCHAR2
  ) RETURN CLOB;
END catalog_api;
/

CREATE OR REPLACE PACKAGE BODY catalog_api AS
  FUNCTION esc(p VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN REPLACE(REPLACE(REPLACE(NVL(p,''), '\', '\\'), '"', '\"'), CHR(10), '\n');
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
      || ',"descricao":"' || esc(r.descricao) || '"'
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
      || ',"descricao":"' || esc(r.descricao) || '"'
      || ',"preco_centavos":' || r.preco_centavos
      || ',"destaque":' || bool_js(r.destaque)
      || ',"selo":"' || esc(r.selo) || '"'
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
      RETURN '{"id":1,"numero_whatsapp":"","nome_exibido":"POPÊ","slogan":""}';
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
    r     sabores%ROWTYPE;
  BEGIN
    IF l_uid IS NULL THEN RETURN '{"erro":"nao autorizado"}'; END IF;
    IF TRIM(NVL(p_nome,'')) IS NULL THEN RETURN '{"erro":"nome obrigatorio"}'; END IF;

    l_ativo := to_bool(p_ativo);
    l_emoji := NVL(NULLIF(TRIM(p_emoji), ''), UNISTR('\D83C\DF7F'));
    l_desc := NVL(p_descricao, ' ');
    IF TRIM(l_desc) IS NULL THEN l_desc := ' '; END IF;
    l_cor := NVL(NULLIF(TRIM(p_cor), ''), '#E8A838');

    IF l_id IS NULL OR l_id = 0 THEN
      INSERT INTO sabores (nome, emoji, descricao, preco_centavos, cor, ativo, ordem)
      VALUES (
        TRIM(p_nome),
        l_emoji,
        l_desc,
        NVL(p_preco, 0),
        l_cor,
        l_ativo,
        NVL(p_ordem, 0)
      ) RETURNING id INTO l_id;
    ELSE
      UPDATE sabores SET
        nome = TRIM(p_nome),
        emoji = l_emoji,
        descricao = l_desc,
        preco_centavos = NVL(p_preco, 0),
        cor = l_cor,
        ativo = l_ativo,
        ordem = NVL(p_ordem, 0),
        atualizado_em = SYSTIMESTAMP
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
    r     kits%ROWTYPE;
  BEGIN
    IF l_uid IS NULL THEN RETURN '{"erro":"nao autorizado"}'; END IF;
    IF TRIM(NVL(p_nome,'')) IS NULL THEN RETURN '{"erro":"nome obrigatorio"}'; END IF;

    l_ativo := to_bool(p_ativo);
    l_destaque := to_bool(p_destaque);
    l_desc := NVL(p_descricao, ' ');
    IF TRIM(l_desc) IS NULL THEN l_desc := ' '; END IF;
    l_selo := NVL(p_selo, ' ');
    IF TRIM(l_selo) IS NULL THEN l_selo := ' '; END IF;

    IF l_id IS NULL OR l_id = 0 THEN
      INSERT INTO kits (nome, descricao, preco_centavos, destaque, selo, ativo, ordem)
      VALUES (
        TRIM(p_nome),
        l_desc,
        NVL(p_preco, 0),
        l_destaque,
        l_selo,
        l_ativo,
        NVL(p_ordem, 0)
      ) RETURNING id INTO l_id;
    ELSE
      UPDATE kits SET
        nome = TRIM(p_nome),
        descricao = l_desc,
        preco_centavos = NVL(p_preco, 0),
        destaque = l_destaque,
        selo = l_selo,
        ativo = l_ativo,
        ordem = NVL(p_ordem, 0),
        atualizado_em = SYSTIMESTAMP
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
  BEGIN
    IF l_uid IS NULL THEN RETURN '{"erro":"nao autorizado"}'; END IF;
    UPDATE configuracoes SET
      numero_whatsapp = NVL(TRIM(p_whatsapp), ''),
      nome_exibido = NVL(TRIM(p_nome), 'POPÊ'),
      slogan = NVL(p_slogan, '')
    WHERE id = 1;
    IF SQL%ROWCOUNT = 0 THEN
      INSERT INTO configuracoes (id, numero_whatsapp, nome_exibido, slogan)
      VALUES (1, NVL(TRIM(p_whatsapp), ''), NVL(TRIM(p_nome), 'POPÊ'), NVL(p_slogan, ''));
    END IF;
    COMMIT;
    RETURN config_json();
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '{"erro":"falha","detalhe":"' || esc(SQLERRM) || '"}';
  END;
END catalog_api;
/

-- Seed (só se vazio)
DECLARE
  l_sab NUMBER;
  l_kit NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_sab FROM sabores;
  IF l_sab = 0 THEN
    INSERT INTO sabores (nome, emoji, descricao, preco_centavos, cor, ordem) VALUES
      ('Caramelo Salgado', UNISTR('\D83C\DF6F'), 'Doce que abraca o salzinho. Vicio garantido.', 2800, '#E8A838', 1);
    INSERT INTO sabores (nome, emoji, descricao, preco_centavos, cor, ordem) VALUES
      ('Chocolate Belga', UNISTR('\D83C\DF6B'), 'Cacau intenso cobrindo cada grao crocante.', 3200, '#6B3A2A', 2);
    INSERT INTO sabores (nome, emoji, descricao, preco_centavos, cor, ordem) VALUES
      ('Cheddar Extra', UNISTR('\D83E\DDC0'), 'Queijo em po artesanal. O cinema ficou com inveja.', 2600, '#F4B942', 3);
    INSERT INTO sabores (nome, emoji, descricao, preco_centavos, cor, ordem) VALUES
      ('Doce de Leite', UNISTR('\D83E\DD5B'), 'Cremoso, brasileiro e impossivel de parar.', 2800, '#C97B4A', 4);
    INSERT INTO sabores (nome, emoji, descricao, preco_centavos, cor, ordem) VALUES
      ('Churros', UNISTR('\D83C\DF00'), 'Canela + acucar + nostalgia de parque.', 2700, '#D4A574', 5);
    INSERT INTO sabores (nome, emoji, descricao, preco_centavos, cor, ordem) VALUES
      ('Pistache Pop', UNISTR('\D83D\DC9A'), 'Verde, gourmet e surpreendentemente viciante.', 3600, '#7CB342', 6);
  END IF;

  SELECT COUNT(*) INTO l_kit FROM kits;
  IF l_kit = 0 THEN
    INSERT INTO kits (nome, descricao, preco_centavos, destaque, selo, ordem) VALUES
      ('Kit Solo Feliz', '1 saquinho grande do sabor que voce quiser. Sessao solo merecida.', 2600, 0, ' ', 1);
    INSERT INTO kits (nome, descricao, preco_centavos, destaque, selo, ordem) VALUES
      ('Kit Dupla Explosiva', '2 sabores diferentes pra dividir (ou nao). Combinacao campea.', 5200, 1, 'Mais pedido', 2);
    INSERT INTO kits (nome, descricao, preco_centavos, destaque, selo, ordem) VALUES
      ('Kit Festa POPE', '4 saquinhos sortidos. Ideal pra reuniao, aniversario ou so porque sim.', 9800, 0, ' ', 3);
  END IF;
  COMMIT;
END;
/

BEGIN
  BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'api');
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  ORDS.DEFINE_MODULE(
    p_module_name    => 'api',
    p_base_path      => 'api/',
    p_items_per_page => 0,
    p_status         => 'PUBLISHED',
    p_comments       => 'Catálogo público e admin PipocaGourmet'
  );

  -- sabores collection
  ORDS.DEFINE_TEMPLATE(p_module_name => 'api', p_pattern => 'sabores', p_priority => 0, p_etag_type => 'HASH');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'sabores', p_method => 'GET',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.lista_sabores_json(:ativos)); END;]'
  );
  ORDS.DEFINE_PARAMETER(
    p_module_name => 'api', p_pattern => 'sabores', p_method => 'GET',
    p_name => 'ativos', p_bind_variable_name => 'ativos',
    p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN'
  );
  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'sabores', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.upsert_sabor_json(:authorization, NULL, :nome, :emoji, :descricao, :preco_centavos, :cor, :ativo, :ordem)); END;]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores', p_method => 'POST',
    p_name => 'Authorization', p_bind_variable_name => 'authorization',
    p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores', p_method => 'POST',
    p_name => 'nome', p_bind_variable_name => 'nome', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores', p_method => 'POST',
    p_name => 'emoji', p_bind_variable_name => 'emoji', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores', p_method => 'POST',
    p_name => 'descricao', p_bind_variable_name => 'descricao', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores', p_method => 'POST',
    p_name => 'preco_centavos', p_bind_variable_name => 'preco_centavos', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores', p_method => 'POST',
    p_name => 'cor', p_bind_variable_name => 'cor', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores', p_method => 'POST',
    p_name => 'ativo', p_bind_variable_name => 'ativo', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores', p_method => 'POST',
    p_name => 'ordem', p_bind_variable_name => 'ordem', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

  -- sabores/:id
  ORDS.DEFINE_TEMPLATE(p_module_name => 'api', p_pattern => 'sabores/:id', p_priority => 0, p_etag_type => 'HASH');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.upsert_sabor_json(:authorization, :id, :nome, :emoji, :descricao, :preco_centavos, :cor, :ativo, :ordem)); END;]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_name => 'id', p_bind_variable_name => 'id', p_source_type => 'URI', p_param_type => 'INT', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_name => 'Authorization', p_bind_variable_name => 'authorization', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_name => 'nome', p_bind_variable_name => 'nome', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_name => 'emoji', p_bind_variable_name => 'emoji', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_name => 'descricao', p_bind_variable_name => 'descricao', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_name => 'preco_centavos', p_bind_variable_name => 'preco_centavos', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_name => 'cor', p_bind_variable_name => 'cor', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_name => 'ativo', p_bind_variable_name => 'ativo', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'PUT',
    p_name => 'ordem', p_bind_variable_name => 'ordem', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'DELETE',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.delete_sabor_json(:authorization, :id)); END;]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'DELETE',
    p_name => 'id', p_bind_variable_name => 'id', p_source_type => 'URI', p_param_type => 'INT', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'sabores/:id', p_method => 'DELETE',
    p_name => 'Authorization', p_bind_variable_name => 'authorization', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

  -- kits
  ORDS.DEFINE_TEMPLATE(p_module_name => 'api', p_pattern => 'kits', p_priority => 0, p_etag_type => 'HASH');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'kits', p_method => 'GET',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.lista_kits_json(:ativos)); END;]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits', p_method => 'GET',
    p_name => 'ativos', p_bind_variable_name => 'ativos', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'kits', p_method => 'POST',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.upsert_kit_json(:authorization, NULL, :nome, :descricao, :preco_centavos, :destaque, :selo, :ativo, :ordem)); END;]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits', p_method => 'POST',
    p_name => 'Authorization', p_bind_variable_name => 'authorization', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits', p_method => 'POST',
    p_name => 'nome', p_bind_variable_name => 'nome', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits', p_method => 'POST',
    p_name => 'descricao', p_bind_variable_name => 'descricao', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits', p_method => 'POST',
    p_name => 'preco_centavos', p_bind_variable_name => 'preco_centavos', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits', p_method => 'POST',
    p_name => 'destaque', p_bind_variable_name => 'destaque', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits', p_method => 'POST',
    p_name => 'selo', p_bind_variable_name => 'selo', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits', p_method => 'POST',
    p_name => 'ativo', p_bind_variable_name => 'ativo', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits', p_method => 'POST',
    p_name => 'ordem', p_bind_variable_name => 'ordem', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

  ORDS.DEFINE_TEMPLATE(p_module_name => 'api', p_pattern => 'kits/:id', p_priority => 0, p_etag_type => 'HASH');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.upsert_kit_json(:authorization, :id, :nome, :descricao, :preco_centavos, :destaque, :selo, :ativo, :ordem)); END;]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_name => 'id', p_bind_variable_name => 'id', p_source_type => 'URI', p_param_type => 'INT', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_name => 'Authorization', p_bind_variable_name => 'authorization', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_name => 'nome', p_bind_variable_name => 'nome', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_name => 'descricao', p_bind_variable_name => 'descricao', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_name => 'preco_centavos', p_bind_variable_name => 'preco_centavos', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_name => 'destaque', p_bind_variable_name => 'destaque', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_name => 'selo', p_bind_variable_name => 'selo', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_name => 'ativo', p_bind_variable_name => 'ativo', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'PUT',
    p_name => 'ordem', p_bind_variable_name => 'ordem', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'DELETE',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.delete_kit_json(:authorization, :id)); END;]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'DELETE',
    p_name => 'id', p_bind_variable_name => 'id', p_source_type => 'URI', p_param_type => 'INT', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'kits/:id', p_method => 'DELETE',
    p_name => 'Authorization', p_bind_variable_name => 'authorization', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

  -- config
  ORDS.DEFINE_TEMPLATE(p_module_name => 'api', p_pattern => 'config', p_priority => 0, p_etag_type => 'HASH');
  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'config', p_method => 'GET',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.config_json()); END;]'
  );
  ORDS.DEFINE_HANDLER(
    p_module_name => 'api', p_pattern => 'config', p_method => 'PUT',
    p_source_type => 'plsql/block',
    p_source => q'[BEGIN owa_util.mime_header('application/json', FALSE); owa_util.http_header_close; htp.p(catalog_api.save_config_json(:authorization, :numero_whatsapp, :nome_exibido, :slogan)); END;]'
  );
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'config', p_method => 'PUT',
    p_name => 'Authorization', p_bind_variable_name => 'authorization', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'config', p_method => 'PUT',
    p_name => 'numero_whatsapp', p_bind_variable_name => 'numero_whatsapp', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'config', p_method => 'PUT',
    p_name => 'nome_exibido', p_bind_variable_name => 'nome_exibido', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
  ORDS.DEFINE_PARAMETER(p_module_name => 'api', p_pattern => 'config', p_method => 'PUT',
    p_name => 'slogan', p_bind_variable_name => 'slogan', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

  ORDS.SET_MODULE_ORIGINS_ALLOWED(p_module_name => 'api', p_origins_allowed => '*');
  COMMIT;
END;
/
