/*
Propósito:
  Validar si hay lotes con Estado=0 por cultivo en la campaña actual y, tras validar, actualizarlos a Estado=1.
  en BD_Local y en 3 instancias Azure (principalmente Azure Piura por conexión a Geotest).

Alcance:
  Tablas: Lote, AreaCultivable, Variedad, Cultivo
  Campaña: Actual (YEAR(GETDATE()))
  Instancias: BD_Local, Azure Piura, Azure Arandano, Azure Palta (Total 4)

Salida esperada:
  - Resumen de conteos por (Cultivo, Estado).
  - Detalle TOP N de candidatos.

Riesgos y performance:
  - Ejecutar primero en entorno de prueba.

Procedimiento:
  1) Ejecutar SELECT de resumen.
  2) Revisar detalle de candidatos.
  3) Si todo ok: ejecutar UPDATE seguro (plantilla abajo).

Acción posterior:
  Actualizar Estado a 1 según resultado de validación para cada cultivo.

Autor: enrique_mosqueira
Fecha: 2025-08-10
Notas:
  - Revisión previa con SELECT conteos y casos. Si todo ok, ejecutar UPDATE.
  - Replicar en instancias Azure de forma coordinada.
*/

-- Paso 1: Validación
DECLARE @Campania   INT        = YEAR(GETDATE());          -- Seleccionar Campaña actual
DECLARE @idCultivo   TINYINT   = 9;             -- Seleccionar id del Cultivo
DECLARE @Estado_inicial TINYINT   = 0;             -- estado actual
DECLARE @Estado_final   TINYINT   = 1;             -- estado a actualizar

-- ======= (3) Validación de conteos (panorama general) ====
PRINT '>> Resumen por cultivo y estado (Campaña = ' + CAST(@Campania AS NVARCHAR(10)) + ')';
SELECT
    c.Nombre      AS Cultivo,
    l.Estado,
    COUNT(*)      AS Cantidad
FROM Lote l
JOIN AreaCultivable ac ON l.idLote     = ac.idLote
JOIN Variedad       v  ON v.idVariedad = ac.idVariedad
JOIN Cultivo        c  ON c.idCultivo  = v.idCultivo
WHERE ac.Campaña = @Campania
GROUP BY c.Nombre, l.Estado
ORDER BY c.Nombre, l.Estado;

-- ======= (4) Detalle a revisar (casos candidatos) ========
--       -> qué filas exactamente quedarían afectadas
PRINT '>> Detalle de candidatos (Cultivo = ' + CAST(@idCultivo AS NVARCHAR(10)) + ', Estado = ' 
    + CAST(@Estado_inicial AS NVARCHAR(10)) + ')';
SELECT TOP (200)           -- ajusta si necesitas más
    l.idLote,
    c.Nombre   AS Cultivo,
    l.Estado,
    ac.Campaña,
    v.idVariedad,
    ac.idArea
FROM Lote l
JOIN AreaCultivable ac ON l.idLote     = ac.idLote
JOIN Variedad       v  ON v.idVariedad = ac.idVariedad 
JOIN Cultivo        c  ON c.idCultivo  = v.idCultivo
WHERE ac.Campaña = @Campania
    AND c.idCultivo   = @idCultivo
    AND l.Estado   = @Estado_inicial
ORDER BY l.idLote;

-- Paso 2: (Sólo si validaste)
-- UPDATE l
-- SET Estado = 1
-- FROM Lote l
-- INNER JOIN AreaCultivable ac ON l.idLote = ac.idLote
-- INNER JOIN Variedad v ON v.idVariedad = ac.idVariedad 
-- INNER JOIN Cultivo c ON c.idCultivo = v.idCultivo
-- WHERE ac.Campaña = 2025
--   AND c.Nombre = 'arandano'
--   AND l.Estado = 0;
