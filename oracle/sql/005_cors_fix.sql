-- Tenta abrir CORS nos módulos api + auth.
-- Nota: no ADB Always Free, requests COM header Origin ainda retornam
-- ORDS-13002 mesmo com origins '*'. Prefira 007_cors_origins.sql + proxy Vite.
-- Ver oracle/README-ORACLE.md.
BEGIN
  ORDS.SET_MODULE_ORIGINS_ALLOWED(
    p_module_name     => 'auth',
    p_origins_allowed => '*'
  );
  ORDS.SET_MODULE_ORIGINS_ALLOWED(
    p_module_name     => 'api',
    p_origins_allowed => '*'
  );
  COMMIT;
END;
/
