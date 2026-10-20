/* ============================================================================
   TechCare - VERIFICACION DE REQUISITOS OBLIGATORIOS (seccion 4 del enunciado)
   Ejecutar sobre TechCareDB. Devuelve el conteo real de cada componente
   contra el minimo exigido, y la lista de objetos para inspeccion.
   Solo cuenta objetos del proyecto (excluye objetos internos de SQL Server).
   ============================================================================ */
USE TechCareDB;
GO

SELECT componente, actual, minimo,
       CASE WHEN actual >= minimo THEN 'CUMPLE' ELSE 'FALTA' END AS resultado
FROM (
    SELECT 'Tablas' AS componente,
           (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) AS actual, 18 AS minimo
    UNION ALL SELECT 'Llaves primarias compuestas',
           (SELECT COUNT(*) FROM (SELECT ic.object_id
                                  FROM sys.indexes i
                                  INNER JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
                                  INNER JOIN sys.tables t ON t.object_id = i.object_id AND t.is_ms_shipped = 0
                                  WHERE i.is_primary_key = 1
                                  GROUP BY ic.object_id HAVING COUNT(*) >= 2) pk), 2
    UNION ALL SELECT 'Foreign keys',        (SELECT COUNT(*) FROM sys.foreign_keys WHERE is_ms_shipped = 0), 1
    UNION ALL SELECT 'UNIQUE',              (SELECT COUNT(*) FROM sys.key_constraints WHERE type = 'UQ' AND is_ms_shipped = 0), 5
    UNION ALL SELECT 'DEFAULT',             (SELECT COUNT(*) FROM sys.default_constraints WHERE is_ms_shipped = 0), 5
    UNION ALL SELECT 'CHECK',               (SELECT COUNT(*) FROM sys.check_constraints WHERE is_ms_shipped = 0), 4
    UNION ALL SELECT 'Vistas',              (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped = 0), 4
    UNION ALL SELECT 'Procedimientos',      (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0), 6
    UNION ALL SELECT 'Funciones',           (SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN','IF','TF') AND is_ms_shipped = 0), 2
    UNION ALL SELECT 'Triggers',            (SELECT COUNT(*) FROM sys.triggers WHERE parent_class = 1 AND is_ms_shipped = 0), 2
    UNION ALL SELECT 'Indices no agrupados',
           (SELECT COUNT(*) FROM sys.indexes i
            INNER JOIN sys.tables t ON t.object_id = i.object_id AND t.is_ms_shipped = 0
            WHERE i.type_desc = 'NONCLUSTERED' AND i.is_primary_key = 0 AND i.is_unique_constraint = 0), 6
) resumen;
GO

/* Detalle de los objetos de logica */
SELECT 'PROCEDIMIENTO' AS tipo, name AS nombre FROM sys.procedures WHERE is_ms_shipped = 0
UNION ALL SELECT 'FUNCION', name FROM sys.objects WHERE type IN ('FN','IF','TF') AND is_ms_shipped = 0
UNION ALL SELECT 'VISTA', name FROM sys.views WHERE is_ms_shipped = 0
UNION ALL SELECT 'TRIGGER', name FROM sys.triggers WHERE parent_class = 1 AND is_ms_shipped = 0
UNION ALL SELECT 'INDICE', OBJECT_NAME(i.object_id) + '.' + i.name
          FROM sys.indexes i INNER JOIN sys.tables t ON t.object_id = i.object_id AND t.is_ms_shipped = 0
          WHERE i.type_desc = 'NONCLUSTERED' AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
ORDER BY tipo, nombre;
GO
