-- 00_Backup_Schema_Complete.sql
-- Sauvegarde complète de la structure de toutes les tables
-- Date de création: 2024-07-02

SELECT 
  'CREATE TABLE ' || table_name || ' (' ||
  string_agg(
    column_name || ' ' || 
    CASE 
      WHEN data_type = 'character varying' THEN 'VARCHAR(' || COALESCE(character_maximum_length::text, '') || ')'
      WHEN data_type = 'numeric' THEN 'NUMERIC(' || COALESCE(numeric_precision::text, '') || ',' || COALESCE(numeric_scale::text, '') || ')'
      WHEN data_type = 'timestamp with time zone' THEN 'TIMESTAMPTZ'
      WHEN data_type = 'timestamp without time zone' THEN 'TIMESTAMP'
      ELSE UPPER(data_type)
    END ||
    CASE 
      WHEN is_nullable = 'NO' THEN ' NOT NULL'
      ELSE ''
    END,
    ', ' ORDER BY ordinal_position
  ) || ');' as create_statement
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name NOT LIKE 'pg_%'
  AND table_name NOT LIKE 'information_schema%'
GROUP BY table_name
ORDER BY table_name;
