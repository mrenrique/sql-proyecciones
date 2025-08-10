/*
Propósito:
  Verificar registros capturados por un evaluador específico para una evaluación, un lote y una fecha concreta.

Ámbito:
  Tablas: dbo.LecturaRegistro2, dbo.Lote
  Parámetros: @LoteNombre (NVARCHAR(50)), @Fecha (DATE), @IdEvaluacion (INT), @IdUsuario (INT)
  Entornos: BD_Local / Azure

Salida esperada:
  Filas de LecturaRegistro2 del lote y fecha dadas, con NombreLote.

Riesgos y performance:
  - Evitar CAST sobre la columna de fecha; usar filtro por rango [@Fecha, @Fecha+1).
  - Listar columnas explícitamente (no SELECT *).

Procedimiento:
  1) Ajustar parámetros.
  2) Ejecutar SELECT (solo lectura).

Autor: enrique_mosqueira
Fecha: 2025-08-10
Notas:
  - Solo consulta (SELECT), no modifica datos.
  - Útil para auditorías y control de calidad de registros por evaluador.
*/

-- =========================
-- Parámetros
-- =========================
DECLARE @LoteNombre   NVARCHAR(50) = N'L1635';         -- nombre exacto del lote
DECLARE @Fecha        DATE         = '2025-08-02';    -- fecha a verificar
DECLARE @IdEvaluacion INT          = 137;             -- ID de la evaluación
DECLARE @IdUsuario    INT          = 2366;            -- ID del evaluador/usuario

SET NOCOUNT ON;

-- =========================
-- Consulta principal
-- =========================
SELECT 
    t.*,   -- OJO: considera listar columnas explícitamente
    l.Nombre AS NombreLote
FROM dbo.LecturaRegistro2 AS t
INNER JOIN dbo.Lote        AS l ON l.idLote = t.idLote
WHERE l.Nombre       = @LoteNombre
  -- AND CAST(t.FechaMovil AS DATE) = @Fecha
  AND t.FechaMovil >= @Fecha AND t.FechaMovil < DATEADD(DAY, 1, @Fecha) -- SARGable: Así se cubre las 24 horas del día de la variable, sin tener que truncar horas ni usar CAST o CONVERT
  AND t.idEvaluacion  = @IdEvaluacion
  AND t.idUsuario     = @IdUsuario
ORDER BY t.FechaMovil, t.idLote;
