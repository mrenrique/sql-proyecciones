/*
Propósito:
  Verificar registros capturados por un evaluador específico para
  una evaluación, un lote y una fecha concreta.

Ámbito:
  Tablas: dbo.LecturaRegistro2, dbo.Lote
  Parámetros: @LoteNombre, @Fecha, @IdEvaluacion, @IdUsuario
  Entornos: BD_Local / Azure (si aplica)

Autor: enrique_mosqueira
Fecha: 2025-08-10

Notas:
  - Solo consulta (SELECT), no modifica datos.
  - Útil para auditorías y control de calidad de registros por evaluador.
  - Ajustar parámetros antes de ejecutar.
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
  AND CAST(t.FechaMovil AS DATE) = @Fecha
  AND t.idEvaluacion  = @IdEvaluacion
  AND t.idUsuario     = @IdUsuario
ORDER BY t.FechaMovil, t.idLote;
