/*
Propósito:
  Consultar las últimas N semanas (por defecto 5) de Proyección/Re-Proyección Semanal
  para verificación previa a migrar una nueva proyección. Además, validar una semana
  puntual y (opcional) actualizar su Descripción.

Ámbito:
  Tablas: dbo.PBI_TablaMaestraProyeccion, dbo.PBI_CabeceraProyeccion, dbo.Variedad
  Parámetros:
    - @IdCultivo (INT)
    - @AnioProyeccion (INT)
    - @NumSemanas (INT)              -> cuántas semanas recientes traer
    - @DescripcionPrefijo (NVARCHAR) -> N'Proyeccion%' o N'Re-Proyeccion%'
    - @SemanaObjetivo (INT)          -> semana puntual para validar/actualizar
    - @DescripcionActual (NVARCHAR) / @DescripcionNueva (NVARCHAR) -> para UPDATE opcional
  Entornos: BD_Local / Azure

Salida esperada:
  - Listado agregado por semana de las últimas N semanas según filtros.
  - Suma de toneladas de una semana puntual.
  - (Opcional) UPDATE para ajustar Descripción de la semana puntual.

Riesgos y performance:
  - Prefijo sargable en Descripcion (LIKE N'Proyeccion%' o N'Re-Proyeccion%') favorece el uso de índices.
  - MAX() + BETWEEN asume continuidad; si hay huecos de semana, usar variante con DENSE_RANK() (ver bloque comentado).
  - Índices recomendados: (AnioProyeccion, SemanaProyeccion, idVariedad, Descripcion).

Procedimiento:
  1) Ajustar parámetros.
  2) Obtener semana máxima y consultar últimas N semanas.
  3) Validar una semana puntual.
  4) (Opcional) Actualizar la Descripción de la semana puntual.

Autor: enrique_mosqueira
Fecha: 2025-08-10
Notas:
  - SET NOCOUNT ON para suprimir “X rows affected”.
  - UPDATE comentado por seguridad; validar antes de ejecutar.
*/

-- =========================
-- Parámetros
-- =========================
DECLARE @IdCultivo          INT          = 5;                   -- cultivo objetivo
DECLARE @AnioProyeccion     INT          = 2025;                -- año de proyección
DECLARE @NumSemanas         INT          = 5;                   -- últimas N semanas
DECLARE @DescripcionPrefijo NVARCHAR(50) = N'Proyeccion%';      -- o N'Re-Proyeccion%'

-- Validación puntual y posible UPDATE
DECLARE @SemanaObjetivo     INT          = 33;                  -- semana puntual
DECLARE @DescripcionActual  NVARCHAR(50) = N'Proyeccion';       -- etiqueta exacta actual
DECLARE @DescripcionNueva   NVARCHAR(50) = N'Proyeccion-V1';    -- nueva etiqueta

SET NOCOUNT ON;

-- =========================
-- 1) Últimas N semanas por número (MAX ... BETWEEN)
-- =========================
;WITH maxsem AS (
    SELECT MAX(t.SemanaProyeccion) AS SemMax
    FROM dbo.PBI_TablaMaestraProyeccion AS t
    INNER JOIN dbo.Variedad AS v ON v.idVariedad = t.idVariedad
    WHERE v.idCultivo        = @IdCultivo
      AND t.AnioProyeccion   = @AnioProyeccion
      AND t.Descripcion LIKE @DescripcionPrefijo
)
SELECT
    c.idCultivo,
    c.Campania,
    t.AnioProyeccion,
    t.SemanaProyeccion,
    t.FechaOrigen,
    t.Descripcion,
    CAST(SUM(t.Toneladas) AS NUMERIC(16,2)) AS Toneladas,
    CAST(AVG(t.Ha)       AS NUMERIC(16,2)) AS Ha
FROM dbo.PBI_TablaMaestraProyeccion AS t
INNER JOIN dbo.PBI_CabeceraProyeccion AS c ON c.idCabeceraProyeccion = t.idCabeceraProyeccion
INNER JOIN dbo.Variedad AS v ON v.idVariedad = t.idVariedad
CROSS JOIN maxsem AS m
WHERE v.idCultivo        = @IdCultivo
  AND t.AnioProyeccion   = @AnioProyeccion
  AND t.Descripcion LIKE @DescripcionPrefijo
  AND t.SemanaProyeccion BETWEEN (m.SemMax - (@NumSemanas - 1)) AND m.SemMax
GROUP BY
    c.idCultivo, c.Campania, t.AnioProyeccion, t.SemanaProyeccion, t.FechaOrigen, t.Descripcion
ORDER BY
    t.AnioProyeccion, t.SemanaProyeccion, t.FechaOrigen;

-- =========================
-- 2) Validación puntual de una semana (suma de toneladas)
-- =========================
SELECT
    CAST(SUM(t.Toneladas) AS NUMERIC(16,2)) AS Toneladas
FROM dbo.PBI_TablaMaestraProyeccion AS t
INNER JOIN dbo.Variedad AS v ON v.idVariedad = t.idVariedad
WHERE v.idCultivo        = @IdCultivo
  AND t.AnioProyeccion   = @AnioProyeccion
  AND t.SemanaProyeccion = @SemanaObjetivo
  AND t.Descripcion      = @DescripcionActual;  -- igualdad exacta

-- =========================
-- 3) UPDATE opcional: cambiar Descripción de la semana puntual (comentado)
-- =========================
-- -- BEGIN TRAN;
--     -- Previsualización
--     -- SELECT t.*
--     -- FROM dbo.PBI_TablaMaestraProyeccion AS t
--     -- INNER JOIN dbo.Variedad AS v ON v.idVariedad = t.idVariedad
--     -- WHERE v.idCultivo        = @IdCultivo
--     --   AND t.AnioProyeccion   = @AnioProyeccion
--     --   AND t.SemanaProyeccion = @SemanaObjetivo
--     --   AND t.Descripcion      = @DescripcionActual;
--
--     -- Actualización
--     -- UPDATE t
--     -- SET t.Descripcion = @DescripcionNueva
--     -- FROM dbo.PBI_TablaMaestraProyeccion AS t
--     -- INNER JOIN dbo.Variedad AS v ON v.idVariedad = t.idVariedad
--     -- WHERE v.idCultivo        = @IdCultivo
--     --   AND t.AnioProyeccion   = @AnioProyeccion
--     --   AND t.SemanaProyeccion = @SemanaObjetivo
--     --   AND t.Descripcion      = @DescripcionActual;
--     -- SELECT @@ROWCOUNT AS FilasActualizadas;
-- -- COMMIT TRAN;
