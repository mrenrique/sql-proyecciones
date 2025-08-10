/*
Propósito:
  Enviar validación de Migración del Programa Semanal para un Cultivo y Año de Proyección específicos,
  mostrando totales por Año, por Variedad y por Calibre (PIVOT por semana).

Ámbito:
  Tablas: dbo.PBI_TablaMaestraProyeccion, dbo.Variedad, dbo.Calibres
  Parámetros: @idCultivo (INT), @FechaOrigen (DATE)
  Entornos: BD_Local

Salida esperada:
  1) Totales por Año (Año, Descripcion, Semana, Kilos formateados)
  2) Totales por Variedad (Variedad, Descripcion, Semana, Kilos formateados)
  3) Totales por Calibre con PIVOT dinámico por semana (columnas = semanas objetivo)

Riesgos y performance:
  - Evitar concatenar valores en SQL dinámico; usar sp_executesql con parámetros cuando sea posible.
  - La función FORMAT es conveniente pero costosa en conjuntos grandes; preferir números crudos para cálculos/exports.
  - Usar nombres de columnas explícitos (no SELECT *). Mantener esquemas (dbo.) y alias consistentes.
  - Alinear semanas usando ISO_WEEK respecto a @FechaOrigen para comparabilidad.

Procedimiento:
  1) Ajustar parámetros y derivar Año y Semanas objetivo.
  2) Ejecutar SELECT por Año.
  3) Ejecutar SELECT por Variedad.
  4) Construir y ejecutar PIVOT dinámico por Calibre.

Autor: enrique_mosqueira
Fecha: 2025-08-10
Notas:
  - Solo consultas (SELECT); no modifica datos.
  - Las columnas “Kilos” se muestran formateadas con separador de miles (string).
*/

-- =========================
-- Parámetros
-- =========================
DECLARE @idCultivo       INT  = 5;            -- Cultivo objetivo
DECLARE @FechaOrigen     DATE = '2025-07-23'; -- Fecha base para calcular Año y semanas

SET NOCOUNT ON;

-- =========================
-- Derivados (Año / Semanas)
-- =========================
DECLARE @AnioProyeccion       INT = YEAR(@FechaOrigen);
DECLARE @SemanaReProyeccionVF INT = DATEPART(ISO_WEEK, @FechaOrigen);               -- semana de Re-Proyeccion-VF
DECLARE @SemanaProyeccion     INT = DATEPART(ISO_WEEK, DATEADD(WEEK, 1, @FechaOrigen)); -- semana de Proyeccion (siguiente semana)

-- =========================
-- 1) Agregado por Año
-- =========================
SELECT
    t.AnioProyeccion  AS Año,
    t.Descripcion,
    t.SemanaProyeccion AS Semana,
    FORMAT(CAST(SUM(t.Toneladas) * 1000 AS INT), 'N0') AS Kilos
FROM dbo.PBI_TablaMaestraProyeccion AS t
INNER JOIN dbo.Variedad AS v
        ON v.idVariedad = t.idVariedad
WHERE v.idCultivo       = @idCultivo
  AND t.AnioProyeccion  = @AnioProyeccion
  AND (
        (t.Descripcion = N'Re-Proyeccion-VF' AND t.SemanaProyeccion = @SemanaReProyeccionVF) OR
        (t.Descripcion = N'Proyeccion'       AND t.SemanaProyeccion = @SemanaProyeccion)
      )
GROUP BY
    t.AnioProyeccion,
    t.Descripcion,
    t.SemanaProyeccion
ORDER BY
    t.Descripcion,
    t.SemanaProyeccion;

-- =========================
-- 2) Agregado por Variedad
-- =========================
SELECT
    v.Variedad,
    t.Descripcion,
    t.SemanaProyeccion AS Semana,
    FORMAT(CAST(SUM(t.Toneladas) * 1000 AS INT), 'N0') AS Kilos
FROM dbo.PBI_TablaMaestraProyeccion AS t
INNER JOIN dbo.Variedad AS v
        ON v.idVariedad = t.idVariedad
WHERE v.idCultivo       = @idCultivo
  AND t.AnioProyeccion  = @AnioProyeccion
  AND (
        (t.Descripcion = N'Re-Proyeccion-VF' AND t.SemanaProyeccion = @SemanaReProyeccionVF) OR
        (t.Descripcion = N'Proyeccion'       AND t.SemanaProyeccion = @SemanaProyeccion)
      )
GROUP BY
    v.Variedad,
    t.Descripcion,
    t.SemanaProyeccion
ORDER BY
    v.Variedad,
    t.Descripcion,
    t.SemanaProyeccion;

-- =========================
-- 3) Agregado por Calibre (PIVOT dinámico por Semana)
-- =========================
DECLARE @sql     NVARCHAR(MAX);
DECLARE @cols    NVARCHAR(MAX);
DECLARE @fmtCols NVARCHAR(MAX);

-- Columnas dinámicas = semanas presentes en el filtro (Re-Proyeccion-VF y Proyeccion)
SELECT
    @cols = STUFF((
        SELECT DISTINCT ',' + QUOTENAME(t.SemanaProyeccion)
        FROM dbo.PBI_TablaMaestraProyeccion AS t
        INNER JOIN dbo.Variedad AS v
                ON v.idVariedad = t.idVariedad
        WHERE v.idCultivo      = @idCultivo
          AND t.AnioProyeccion = @AnioProyeccion
          AND (
                (t.Descripcion = N'Re-Proyeccion-VF' AND t.SemanaProyeccion = @SemanaReProyeccionVF) OR
                (t.Descripcion = N'Proyeccion'       AND t.SemanaProyeccion = @SemanaProyeccion)
              )
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
    , 1, 1, ''),

    @fmtCols = STUFF((
        SELECT DISTINCT ',FORMAT(p.' + QUOTENAME(t.SemanaProyeccion) + ',''N0'') AS ' + QUOTENAME(t.SemanaProyeccion)
        FROM dbo.PBI_TablaMaestraProyeccion AS t
        INNER JOIN dbo.Variedad AS v
                ON v.idVariedad = t.idVariedad
        WHERE v.idCultivo      = @idCultivo
          AND t.AnioProyeccion = @AnioProyeccion
          AND (
                (t.Descripcion = N'Re-Proyeccion-VF' AND t.SemanaProyeccion = @SemanaReProyeccionVF) OR
                (t.Descripcion = N'Proyeccion'       AND t.SemanaProyeccion = @SemanaProyeccion)
              )
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
    , 1, 1, '');

-- SQL dinámico (parametrizado)
SET @sql = N'
SELECT
    p.Calibre' + CASE WHEN NULLIF(@fmtCols, N'') IS NOT NULL THEN N',' + @fmtCols ELSE N'' END + N'
FROM (
    SELECT
        c.Calibre,
        t.SemanaProyeccion,
        CAST(ROUND(SUM(t.Toneladas) * 1000, 0) AS INT) AS Kilos
    FROM dbo.PBI_TablaMaestraProyeccion AS t
    INNER JOIN dbo.Variedad  AS v ON v.idVariedad  = t.idVariedad
    INNER JOIN dbo.Calibres  AS c ON c.idCalibre   = t.idCalibre
    WHERE v.idCultivo      = @p_idCultivo
      AND t.AnioProyeccion = @p_AnioProyeccion
      AND (
            (t.Descripcion = N''Re-Proyeccion-VF'' AND t.SemanaProyeccion = @p_SemReProy) OR
            (t.Descripcion = N''Proyeccion''       AND t.SemanaProyeccion = @p_SemProy)
          )
    GROUP BY c.Calibre, t.SemanaProyeccion
) AS d
PIVOT (
    SUM(d.Kilos) FOR d.SemanaProyeccion IN (__COLS__)
) AS p
ORDER BY TRY_CAST(p.Calibre AS INT);';

-- Inyectar lista de columnas del PIVOT
SET @sql = REPLACE(@sql, N'__COLS__', ISNULL(@cols, N'[SinSemanas]')); -- fallback defensivo

-- Debug opcional
-- PRINT @sql;

-- Ejecutar con parámetros
EXEC sys.sp_executesql
     @sql,
     N'@p_idCultivo INT, @p_AnioProyeccion INT, @p_SemReProy INT, @p_SemProy INT',
     @p_idCultivo = @idCultivo,
     @p_AnioProyeccion = @AnioProyeccion,
     @p_SemReProy = @SemanaReProyeccionVF,
     @p_SemProy   = @SemanaProyeccion;
