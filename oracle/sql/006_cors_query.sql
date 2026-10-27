-- Diagnóstico: origins dos módulos ORDS
SELECT name AS module_name, uri_prefix, origins_allowed
  FROM user_ords_modules
 ORDER BY name;
/