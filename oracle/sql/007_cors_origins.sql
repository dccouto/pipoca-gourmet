-- CORS: lista explícita (ADB/ORDS costuma rejeitar Origin mesmo com '*')
-- Inclui GitHub Pages (user/org) e dev local. Ajuste se o nome do repo mudar.
BEGIN
  ORDS.SET_MODULE_ORIGINS_ALLOWED(
    p_module_name     => 'auth',
    p_origins_allowed => 'http://localhost:5173 http://127.0.0.1:5173 https://dccouto.github.io'
  );
  ORDS.SET_MODULE_ORIGINS_ALLOWED(
    p_module_name     => 'api',
    p_origins_allowed => 'http://localhost:5173 http://127.0.0.1:5173 https://dccouto.github.io'
  );
  COMMIT;
END;
/