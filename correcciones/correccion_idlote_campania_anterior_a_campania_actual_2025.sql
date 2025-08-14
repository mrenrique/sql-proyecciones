/*
Propósito:
  Identificar lecturas registradas en la campaña actual (por fechas)
  que fueron asociadas a un idLote de campañas anteriores y,
  opcionalmente, corregir su idLote al de la campaña actual (mismo nombre de lote).

  Consultar registros en la tabla LecturaRegistro2 que se hayan registrado con un idLote a una campaña anterior
  Una vez identificados, actualizar con su idlote correspondiente a la campaña actual

Ámbito:
  Tablas: LecturaRegistro2, Evaluacion, Usuario, Lote, AreaCultivable, Variedad
  Parámetros:
    - @IdCultivo (INT)
    - @Anio       (INT) -> campaña objetivo
  Entornos: BD_Local

Salida esperada:
  - Listado de lecturas afectadas (campaña por fechas = @Anio, pero idLote de campaña <> @Anio).
  - Previsualización del mapeo idLoteAnterior → idLoteActual por nombre de lote.
  - (Opcional) UPDATE con OUTPUT del cambio realizado.

Procedimiento:
  1) Ajustar parámetros y rango de fechas de la campaña.
  2) Validar si existen lecturas con idLote de campañas pasadas.
  3) Previsualizar el mapeo a idLote de la campaña actual.
  4) (Opcional) Ejecutar UPDATE con OUTPUT dentro de una transacción.

Autor: enrique_mosqueira
Fecha: 2025-08-14
Notas:
  - UPDATE comentado por seguridad; validar resultados antes de ejecutar.
  - SET XACT_ABORT ON para abortar la transacción ante errores de ejecución.
*/

-- =========================
-- Parámetros
-- =========================
DECLARE @CultivoID  int = 13;
DECLARE @Anio       int = 2025;

DECLARE @FecIni date = DATEFROMPARTS(@Anio, 1, 1);
DECLARE @FecFin date = DATEFROMPARTS(@Anio + 1, 1, 1); -- límite superior exclusivo

SET XACT_ABORT ON;

-- 1). Consultar si hay registros con idLote correspondiente a campañas pasadas
SELECT
    t.idLecturaRegistro,
    t.idEvaluacion,
    t.idUsuario,
    t.idLote                  AS idLoteRegistrado,
    l.[Campaña]               AS CampaniaDelLote,
    t.FechaRegistro,
    u.Nombre                  AS Usuario,
    l.Nombre                  AS NombreLote
FROM LecturaRegistro2       AS t
JOIN evaluacion             AS e ON e.idEvaluacion = t.idEvaluacion
JOIN Usuario                AS u ON u.idUsuario    = t.idUsuario
JOIN Lote                   AS l ON l.idLote       = t.idLote
WHERE e.idCultivo = @CultivoID
    AND t.FechaRegistro >= @FecIni
    AND t.FechaRegistro <  @FecFin
    AND l.[Campaña] <> @Anio;

-- 2). Modificar registros con idlote de Campaña anterior con idlote Campaña actual
BEGIN TRAN;

    WITH LotesCampañaActual AS (
        SELECT DISTINCT l.Nombre AS NombreLote, l.idLote
        FROM Lote l
        JOIN AreaCultivable ac ON ac.idLote = l.idLote
        JOIN Variedad v        ON v.idVariedad = ac.idVariedad
        WHERE v.idCultivo = @CultivoID
            AND l.[Campaña] = @Anio
    ),
    RegistrosPorCorregir AS (
        SELECT  t.idLecturaRegistro,
                t.idLote          AS idLoteAnterior,
                lActual.idLote    AS idLoteActual
        FROM LecturaRegistro2 t
        JOIN evaluacion   e   ON e.idEvaluacion = t.idEvaluacion AND e.idCultivo = @CultivoID
        JOIN Lote         l   ON l.idLote       = t.idLote
        JOIN LotesCampañaActual lActual
            ON lActual.NombreLote = l.Nombre
        WHERE t.FechaRegistro >= @FecIni
        AND t.FechaRegistro <  @FecFin
        AND l.[Campaña] <> @Anio
    )
    UPDATE t
        SET t.idLote = r.idLoteActual
    OUTPUT
        deleted.idLote AS idLote_Anterior,
        inserted.idLote AS idLote_Nuevo,
        inserted.idLecturaRegistro,
        SYSUTCDATETIME() AS FechaCambioUTC
    FROM LecturaRegistro2 t
    JOIN RegistrosPorCorregir r
        ON r.idLecturaRegistro = t.idLecturaRegistro;

    -- Revisa la cuadrícula de resultados del OUTPUT.

    -- Si la validación está OK, ejecutas sólo TRAN para confirmar cambios y hacerlos permanentes:
    COMMIT TRAN;

    -- Si la validación es incorrecta, ejecutar ROLLBACK para reverir todo lo que se hizo en esa transacción.
    COMMIT ROLLBACK;
