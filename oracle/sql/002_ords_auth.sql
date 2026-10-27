-- PipocaGourmet — ORDS auth (já aplicado via REST SQL no provisionamento)
-- Schema: PIPOCAG | Base path: /ords/pipocag/
-- Endpoints:
--   GET  /ords/pipocag/auth/ping
--   POST /ords/pipocag/auth/login   (headers: email, senha)
--
-- Pré-requisitos (como ADMIN):
--   GRANT EXECUTE ON SYS.DBMS_CRYPTO TO PIPOCAG;
--   GRANT EXECUTE ON SYS.UTL_RAW TO PIPOCAG;
--   ORDS_ADMIN.ENABLE_SCHEMA(... pattern => 'pipocag');

-- Pacote de login (hash sha256$salt$hex — ponte até bcrypt/argon2 no app)
CREATE OR REPLACE PACKAGE auth_util AS
  FUNCTION sha256_hex(p_text VARCHAR2) RETURN VARCHAR2;
  FUNCTION login_json(p_email VARCHAR2, p_senha VARCHAR2) RETURN VARCHAR2;
END auth_util;
/

CREATE OR REPLACE PACKAGE BODY auth_util AS
  FUNCTION sha256_hex(p_text VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW(p_text), DBMS_CRYPTO.HASH_SH256)));
  END;

  FUNCTION login_json(p_email VARCHAR2, p_senha VARCHAR2) RETURN VARCHAR2 IS
    l_email  VARCHAR2(320) := LOWER(TRIM(p_email));
    l_senha  VARCHAR2(255) := p_senha;
    l_id     NUMBER;
    l_hash   VARCHAR2(255);
    l_algo   VARCHAR2(32);
    l_salt   VARCHAR2(64);
    l_expect VARCHAR2(128);
    l_calc   VARCHAR2(128);
    l_token  VARCHAR2(64);
    l_thash  VARCHAR2(128);
    l_pos1   PLS_INTEGER;
    l_pos2   PLS_INTEGER;
  BEGIN
    IF l_email IS NULL OR l_senha IS NULL THEN
      RETURN '{"erro":"email e senha obrigatorios"}';
    END IF;

    BEGIN
      SELECT id, senha_hash INTO l_id, l_hash
        FROM usuarios_admin
       WHERE LOWER(email) = l_email AND ativo = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN '{"erro":"credenciais invalidas"}';
    END;

    l_pos1 := INSTR(l_hash, CHR(36));
    l_pos2 := INSTR(l_hash, CHR(36), l_pos1 + 1);
    IF l_pos1 = 0 OR l_pos2 = 0 THEN
      RETURN '{"erro":"hash invalido"}';
    END IF;

    l_algo   := SUBSTR(l_hash, 1, l_pos1 - 1);
    l_salt   := SUBSTR(l_hash, l_pos1 + 1, l_pos2 - l_pos1 - 1);
    l_expect := SUBSTR(l_hash, l_pos2 + 1);

    IF l_algo <> 'sha256' THEN
      RETURN '{"erro":"algoritmo nao suportado"}';
    END IF;

    l_calc := sha256_hex(l_salt || l_senha);
    IF l_calc <> LOWER(l_expect) THEN
      RETURN '{"erro":"credenciais invalidas"}';
    END IF;

    l_token := LOWER(RAWTOHEX(SYS_GUID())) || LOWER(RAWTOHEX(SYS_GUID()));
    l_thash := sha256_hex(l_token);
    INSERT INTO sessao_token (usuario_id, token_hash, expira_em)
    VALUES (l_id, l_thash, SYSTIMESTAMP + NUMTODSINTERVAL(12, 'HOUR'));
    COMMIT;

    RETURN '{"token":"' || l_token || '","expira_horas":12,"usuario_id":' || TO_CHAR(l_id) || '}';
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '{"erro":"falha interna","detalhe":"' || REPLACE(SQLERRM,'"','') || '"}';
  END;
END auth_util;
/

BEGIN
  ORDS.DEFINE_MODULE(
    p_module_name    => 'auth',
    p_base_path      => 'auth/',
    p_items_per_page => 0,
    p_status         => 'PUBLISHED',
    p_comments       => 'Login admin PipocaGourmet'
  );

  ORDS.DEFINE_TEMPLATE(
    p_module_name => 'auth',
    p_pattern     => 'login',
    p_priority    => 0,
    p_etag_type   => 'HASH',
    p_comments    => 'POST login'
  );

  ORDS.DEFINE_HANDLER(
    p_module_name    => 'auth',
    p_pattern        => 'login',
    p_method         => 'POST',
    p_source_type    => 'plsql/block',
    p_source         => q'[BEGIN htp.p(auth_util.login_json(:email, :senha)); END;]'
  );

  ORDS.DEFINE_PARAMETER(
    p_module_name => 'auth', p_pattern => 'login', p_method => 'POST',
    p_name => 'email', p_bind_variable_name => 'email',
    p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN'
  );

  ORDS.DEFINE_PARAMETER(
    p_module_name => 'auth', p_pattern => 'login', p_method => 'POST',
    p_name => 'senha', p_bind_variable_name => 'senha',
    p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN'
  );

  ORDS.DEFINE_TEMPLATE(
    p_module_name => 'auth',
    p_pattern     => 'ping',
    p_priority    => 0,
    p_etag_type   => 'HASH',
    p_comments    => 'health'
  );

  ORDS.DEFINE_HANDLER(
    p_module_name => 'auth',
    p_pattern     => 'ping',
    p_method      => 'GET',
    p_source_type => 'plsql/block',
    p_source      => 'BEGIN htp.p(''{"ok":true}''); END;'
  );

  ORDS.SET_MODULE_ORIGINS_ALLOWED(
    p_module_name     => 'auth',
    p_origins_allowed => '*'
  );

  COMMIT;
END;
/
