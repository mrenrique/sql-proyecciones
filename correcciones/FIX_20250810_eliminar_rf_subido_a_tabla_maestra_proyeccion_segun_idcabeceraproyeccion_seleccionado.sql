/*
Propósito:
  Validar (conteo y suma de toneladas) el/los RF (idCabeceraProyeccion)
  seleccionados para posterior eliminación, y ofrecer un bloque opcional
  y seguro para previsualizar y borrar en transacción.

Ámbito:
  Tablas: dbo.PBI_TablaMaestraProyeccion, dbo.PBI_CabeceraProyeccion
  Parámetros:
    - @IdCabeceraProyeccion (INT)                 -> un RF puntual (prioritario)
    - @AnioOrigen          (INT)                  -> año de origen a filtrar (p.ej. 2025)
    - @MostrarDetalleTopN  (INT)                  -> filas de ejemplo a mostrar
    - [Opcional] @IdsCabeceraExtra (TABLE)        -> lista alternativa para múltiples RF

Entornos: BD_Local

Salida esperada:
  - Resumen: cantidad de registros y suma de toneladas del RF/año objetivo.
  - (Opcional) Muestra de detalle (TOP N) para inspección rápida.
  - (Opcional) Bloque seguro de DELETE en TRAN con previsualización y @@ROWCOUNT.

Riesgos y performance:
  - Filtros sargables por (idCabeceraProyeccion, AnioOrigen).
  - Índices recomendados: (idCabeceraProyeccion, AnioOrigen) INCLUDE (Toneladas).
  - Si se usa lista de múltiples RF, considerar tabla temporal o TVP con índice.

Procedimiento:
  1) Ajustar parámetros.
  2) Validar resumen (COUNT / SUM) para el RF/año.
  3) (Opcional) Mostrar detalle de ejemplo.
  4) (Opcional) Borrado seguro en TRAN: previsualizar -> borrar -> verificar -> COMMIT/ROLLBACK.

Autor: enrique_mosqueira
Fecha: 2025-08-11
Notas:
  - SET NOCOUNT ON para suprimir “X rows affected”.
  - El DELETE viene comentado por seguridad; validar antes de ejecutar.
*/

SET NOCOUNT ON;

-- =========================
-- Parámetros
-- =========================
DECLARE @IdCabeceraProyeccion INT = 2675;   -- RF puntual a evaluar/borrar
DECLARE @AnioOrigen           INT = 2025;   -- año de origen
DECLARE @MostrarDetalleTopN   INT = 15;     -- filas de muestra para inspección

-- Alternativa: lista de múltiples RF (descomentar si se requiere IN (...))
-- DECLARE @IdsCabeceraExtra TABLE (idCabeceraProyeccion INT PRIMARY KEY);
-- INSERT INTO @IdsCabeceraExtra (idCabeceraProyeccion)
-- VALUES (494), (557); -- ejemplo

-- =========================
-- 1) Resumen de validación (COUNT / SUM)
-- =========================
SELECT
    COUNT(*)                                  AS Cantidad_Registros_Formato_RF_Subido,
    CAST(SUM(tp.Toneladas) AS NUMERIC(16,2))  AS Total_Toneladas_General
FROM dbo.PBI_TablaMaestraProyeccion AS tp
-- INNER JOIN dbo.PBI_CabeceraProyeccion AS cp ON cp.idCabeceraProyeccion = tp.idCabeceraProyeccion
WHERE 1 = 1
  AND tp.idCabeceraProyeccion = @IdCabeceraProyeccion         -- RF puntual
  -- OR tp.idCabeceraProyeccion IN (SELECT idCabeceraProyeccion FROM @IdsCabeceraExtra) -- múltiples RF
  AND tp.AnioOrigen = @AnioOrigen;

-- =========================
-- 2) (Opcional) Muestra de detalle para inspección rápida
-- =========================
SELECT TOP (@MostrarDetalleTopN)
    tp.idCabeceraProyeccion,
    tp.AnioOrigen,
    tp.AnioProyeccion,
    tp.SemanaProyeccion,
    tp.Descripcion,
    tp.Toneladas,
    tp.Ha,
    tp.FechaOrigen,
    tp.idVariedad
FROM dbo.PBI_TablaMaestraProyeccion AS tp
WHERE 1 = 1
  AND tp.idCabeceraProyeccion = @IdCabeceraProyeccion
  -- OR tp.idCabeceraProyeccion IN (SELECT idCabeceraProyeccion FROM @IdsCabeceraExtra)
  AND tp.AnioOrigen = @AnioOrigen
ORDER BY tp.AnioProyeccion, tp.SemanaProyeccion, tp.FechaOrigen;

-- =========================
-- 3) (Opcional) DELETE seguro en transacción (comentado)
-- =========================
-- BEGIN TRAN;
--     -- 3.1) Previsualización de filas a eliminar
--     SELECT TOP (@MostrarDetalleTopN) *
--     FROM dbo.PBI_TablaMaestraProyeccion AS tp
--     WHERE 1 = 1
--       AND tp.idCabeceraProyeccion = @IdCabeceraProyeccion
--       -- OR tp.idCabeceraProyeccion IN (SELECT idCabeceraProyeccion FROM @IdsCabeceraExtra)
--       AND tp.AnioOrigen = @AnioOrigen
--     ORDER BY tp.AnioProyeccion, tp.SemanaProyeccion, tp.FechaOrigen;
--
--     -- 3.2) Eliminación
--     DELETE tp
--     FROM dbo.PBI_TablaMaestraProyeccion AS tp
--     WHERE 1 = 1
--       AND tp.idCabeceraProyeccion = @IdCabeceraProyeccion
--       -- OR tp.idCabeceraProyeccion IN (SELECT idCabeceraProyeccion FROM @IdsCabeceraExtra)
--       AND tp.AnioOrigen = @AnioOrigen;
--
--     -- 3.3) Verificación de impacto
--     SELECT @@ROWCOUNT AS FilasEliminadas;
-- COMMIT TRAN;
-- -- ROLLBACK TRAN;
