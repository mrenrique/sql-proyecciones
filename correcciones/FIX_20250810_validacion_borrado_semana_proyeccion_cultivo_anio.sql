/*
Propósito:
  Validar la cantidad de Toneladas proyectadas para una semana específica
  y (opcional) borrar esos registros, considerando que la Descripción es
  uno u otro tipo (Proyeccion o Re-Proyeccion), pero no ambos.

Ámbito:
  Tablas: dbo.PBI_TablaMaestraProyeccion, dbo.Variedad
  Parámetros: @IdCultivo (INT), @AnioProyeccion (INT), @SemanaOrigen (INT),
              @DescripcionTipo (NVARCHAR: 'Proyeccion' | 'Re-Proyeccion')
  Entornos: BD_Local

Salida esperada:
  Total de Toneladas (SUM) para la semana indicada y el tipo de descripción seleccionado.

Riesgos y performance:
  - Filtro sargable por prefijo en Descripcion (N'Proyeccion%' o N'Re-Proyeccion%').
  - Asegurar índices: (AnioProyeccion, SemanaOrigen, Descripcion, idVariedad).
  - En DELETE con JOIN, usar alias en FROM.

Procedimiento:
  1) Ajustar parámetros y validar @DescripcionTipo.
  2) (Opcional) Ejecutar DELETE seguro en transacción.

Autor: enrique_mosqueira
Fecha: 2025-08-10
Notas:
  - Se borra una sola semana por ejecución (usa @SemanaOrigen).
  - @DescripcionTipo restringe a un solo grupo de descripciones.
*/

-- =========================
-- Parámetros
-- =========================
DECLARE @IdCultivo       INT         = 9;               -- cultivo objetivo
DECLARE @AnioProyeccion  INT         = 2025;            -- año a validar/borrar
DECLARE @SemanaOrigen    INT         = 30;              -- semana única a validar/borrar
DECLARE @DescripcionTipo NVARCHAR(20)= N'Re-Proyeccion';-- 'Proyeccion' | 'Re-Proyeccion'

SET NOCOUNT ON;

-- Derivar prefijo sargable y validar entrada
IF @DescripcionTipo NOT IN (N'Proyeccion', N'Re-Proyeccion')
BEGIN
    THROW 50000, 'Parametro @DescripcionTipo invalido. Use: Proyeccion o Re-Proyeccion.', 1;
END;

DECLARE @DescripcionPrefijo NVARCHAR(50) =
    CASE WHEN @DescripcionTipo = N'Proyeccion'
         THEN N'Proyeccion%'
         ELSE N'Re-Proyeccion%' END;

-- =========================
-- Validación: Toneladas de la semana seleccionada (un solo tipo de descripcion)
-- =========================
-- -- Previsualización de filas a eliminar (conteo y suma)
SELECT
    COUNT(*)                                   AS NroFilasAEliminar,
    CAST(SUM(tmp.Toneladas) AS NUMERIC(16,2))  AS ToneladasAEliminar
FROM dbo.PBI_TablaMaestraProyeccion AS tmp
INNER JOIN dbo.Variedad AS v
        ON v.idVariedad = tmp.idVariedad
WHERE v.idCultivo        = @IdCultivo
  AND tmp.AnioProyeccion = @AnioProyeccion
  AND tmp.SemanaOrigen   = @SemanaOrigen
  AND tmp.Descripcion LIKE @DescripcionPrefijo;

-- =========================
-- Borrado opcional (descomentar para ejecutar)
-- =========================
-- -- Borrado seguro en transacción (con respaldo temporal)
-- BEGIN TRAN;
--     IF OBJECT_ID('tempdb..#BackupDelete') IS NOT NULL DROP TABLE #BackupDelete;
--     SELECT tmp.*
--     INTO #BackupDelete
--     FROM dbo.PBI_TablaMaestraProyeccion AS tmp
--     INNER JOIN dbo.Variedad AS v
--             ON v.idVariedad = tmp.idVariedad
--     WHERE v.idCultivo        = @IdCultivo
--       AND tmp.AnioProyeccion = @AnioProyeccion
--       AND tmp.SemanaOrigen   = @SemanaOrigen
--       AND tmp.Descripcion LIKE @DescripcionPrefijo;
--
--     DELETE tmp
--     FROM dbo.PBI_TablaMaestraProyeccion AS tmp
--     INNER JOIN dbo.Variedad AS v
--             ON v.idVariedad = tmp.idVariedad
--     WHERE v.idCultivo        = @IdCultivo
--       AND tmp.AnioProyeccion = @AnioProyeccion
--       AND tmp.SemanaOrigen   = @SemanaOrigen
--       AND tmp.Descripcion LIKE @DescripcionPrefijo;
--
--     SELECT @@ROWCOUNT AS FilasEliminadas;
-- COMMIT TRAN;
