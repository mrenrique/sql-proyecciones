/*
Propósito:
  Duplicar una cartilla (evaluación), en tabla Evaluacion y EstructuraLectura
  para visualizar en Geotest. Asignando un nuevo nombre e ID, con posibilidad
  de ajustar posteriormente la estructura de la nueva cartilla.

Ámbito:
  Tablas: dbo.Evaluacion, dbo.EstructuraLectura
  Parámetros: @IdEvaluacionOrigen (INT), @NuevoNombre (NVARCHAR)
  Entornos: BD_Local, Azure Piura, Azure, Arandano, Azure, Palta

Salida esperada:
  - Nuevo registro en Evaluacion con @NuevoNombre.
  - Duplicado de la EstructuraLectura apuntando al nuevo idEvaluacion.
  - Script opcional para actualizar campos de la nueva cartilla.

Procedimiento:
  1) Validar idEvaluacion de cartilla a duplicar.
     ===Paso 2, 3 y 4 se ejecutan al mismo tiempo===
  2) Insertar Evaluacion duplicada con nuevo nombre.
  3) Insertar EstructuraLectura vinculada al nuevo idEvaluacion.
  4) Confirmar transacción (o rollback si se requiere).
  5) (Opcional) Generar script UPDATE para personalizar estructura.

Autor: enrique_mosqueira
Fecha: 2025-08-20
Notas:
  - El proceso excluye los campos identity (idEvaluacion, idEstructuraLectura).
  - Se deja transacción explícita para revertir en caso de error.
  - Incluye opción de generar scripts parametrizados de UPDATE.
  - TODO: Si se ejecuta el paso 4 por separado, no se realizan los cambios pero se genera el autoincremental en tabla evalauacion
    Si no tiene solución, modificar para que muestre como lucirían las filas a insertar en ambas tablas.
    Con ello, ejecutar directamente la query para insertar
*/

-- =========================
-- Parámetros
-- =========================
DECLARE @IdEvaluacionOrigen INT           = 30;                 -- cartilla origen
DECLARE @NuevoNombre        NVARCHAR(200) = N'Ensayo Paniculas';-- nombre nuevo
DECLARE @NuevoIdEvaluacion  INT;                                -- id destino generado

SET NOCOUNT ON;

-- =========================
-- Paso 1: Validación (previsualizar cartilla origen)
-- =========================
SELECT * 
FROM dbo.Evaluacion 
WHERE idEvaluacion = @IdEvaluacionOrigen;

SELECT * 
FROM dbo.EstructuraLectura 
WHERE idEvaluacion = @IdEvaluacionOrigen;

-- =========================
-- Paso 2: Duplicar Evaluacion (nuevo registro)
-- =========================
BEGIN TRAN;

DECLARE @NewEval TABLE (idEvaluacion INT);

INSERT INTO dbo.Evaluacion
(
    Descripcion,
    Estado,
    Nombre,
    Imagen,
    FondoColor,
    idCultivo,
    IP,
    USS,
    PSS,
    Reporte,
    FechaRegistro
)
OUTPUT inserted.idEvaluacion INTO @NewEval
SELECT
    @NuevoNombre AS Descripcion,
    E.Estado,
    @NuevoNombre AS Nombre,  -- << cambio solicitado
    E.Imagen,
    E.FondoColor,
    E.idCultivo,
    E.IP,
    E.USS,
    E.PSS,
    E.Reporte,
    E.FechaRegistro
FROM dbo.Evaluacion AS E
WHERE E.idEvaluacion = @IdEvaluacionOrigen;

SELECT @NuevoIdEvaluacion = idEvaluacion 
FROM @NewEval;

-- =========================
-- Paso 3: Duplicar EstructuraLectura (con nuevo idEvaluacion)
-- =========================
INSERT INTO dbo.EstructuraLectura
(
    idEvaluacion,
    Activos,
    Nombres,
    ValorEnfocar,
    Valida,
    Limpiar,
    LimpiaNivel,
    Aumentos,
    Minimos,
    Maximos,
    Repite,
    Formula,
    Estado,
    DobleUsuario,
    Historico,
    Descripciones,
    [input],
    [output],
    verifica
)
SELECT
    @NuevoIdEvaluacion AS idEvaluacion,
    L.Activos,
    L.Nombres,
    L.ValorEnfocar,
    L.Valida,
    L.Limpiar,
    L.LimpiaNivel,
    L.Aumentos,
    L.Minimos,
    L.Maximos,
    L.Repite,
    L.Formula,
    L.Estado,
    L.DobleUsuario,
    L.Historico,
    L.Descripciones,
    L.[input],
    L.[output],
    L.verifica
FROM dbo.EstructuraLectura AS L
WHERE L.idEvaluacion = @IdEvaluacionOrigen;

-- =========================
-- Paso 4: Confirmar o revertir transacción
-- =========================
COMMIT TRAN;
-- ROLLBACK TRAN;   -- <- usar en caso de error

-- =========================
-- Paso 5: Validar duplicación
-- =========================
SELECT * 
FROM dbo.Evaluacion 
WHERE idEvaluacion = @NuevoIdEvaluacion;

SELECT * 
FROM dbo.EstructuraLectura 
WHERE idEvaluacion = @NuevoIdEvaluacion;

-- =========================
-- Paso 6 (Opcional): Generar script UPDATE parametrizado
-- =========================
DECLARE @ConTransaccion BIT = 1;      -- 1 = genera BEGIN/ROLLBACK

SELECT
    CASE WHEN @ConTransaccion = 1 
         THEN 'BEGIN TRAN;' + '|||' + CHAR(13) + CHAR(10) ELSE '' END +
    'UPDATE dbo.EstructuraLectura' + CHAR(13) + '|||' +
    'SET' + CHAR(13) +
    ' Activos      = ' + ISNULL('N''' + REPLACE(Activos,     '''', '''''') + '''', 'NULL') + ',' + CHAR(13) +
    '||| Nombres      = ' + ISNULL('N''' + REPLACE(Nombres,     '''', '''''') + '''', 'NULL') + ',' + CHAR(13) +
    '||| ValorEnfocar = ' + ISNULL(CONVERT(VARCHAR(50), ValorEnfocar), 'NULL') + ',' + CHAR(13) +
    '||| Valida       = ' + ISNULL('N''' + REPLACE(Valida,      '''', '''''') + '''', 'NULL') + ',' + CHAR(13) +
    '||| Limpiar      = ' + ISNULL('N''' + REPLACE(Limpiar,     '''', '''''') + '''', 'NULL') + ',' + CHAR(13) +
    '||| LimpiaNivel  = ' + ISNULL('N''' + REPLACE(LimpiaNivel, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) +
    '||| Aumentos     = ' + ISNULL('N''' + REPLACE(Aumentos,    '''', '''''') + '''', 'NULL') + ',' + CHAR(13) +
    '||| Minimos      = ' + ISNULL('N''' + REPLACE(Minimos,     '''', '''''') + '''', 'NULL') + ',' + CHAR(13) +
    '||| Maximos      = ' + ISNULL('N''' + REPLACE(Maximos,     '''', '''''') + '''', 'NULL') + ',' + CHAR(13) +
    '||| Repite       = ' + ISNULL('N''' + REPLACE(Repite,      '''', '''''') + '''', 'NULL') + CHAR(13) +
    '||| WHERE idEvaluacion = ' + CONVERT(VARCHAR(20), @NuevoIdEvaluacion) + ';' + CHAR(13) +
    CASE
        WHEN @ConTransaccion = 1
        THEN '||| --COMMIT TRAN;   -- <- quitar comentario para confirmar' + CHAR(13) +
             '||| ROLLBACK TRAN;   -- <- por defecto, no guarda'
        ELSE ''
    END
AS ScriptUPDATE
FROM dbo.EstructuraLectura
WHERE idEvaluacion = @NuevoIdEvaluacion;
