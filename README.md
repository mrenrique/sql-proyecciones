# SQL - Área de Proyecciones

Repositorio que almacena los scripts SQL utilizados por el área de **Proyecciones** para validaciones, reportes, correcciones y procesos ad-hoc sobre las bases de datos (SQL Server y Azure SQL).

## 📌 Convenciones de nombres
- `VAL_YYYYMMDD_descripcion.sql` → Scripts de validación (SELECT).
- `FIX_YYYYMMDD_descripcion.sql` → Scripts correctivos (UPDATE/DELETE/INSERT).
- `RPT_YYYYMMDD_nombre.sql` → Scripts para reportes recurrentes.
- `UTL_nombre.sql` → Scripts utilitarios (funciones, procedimientos, plantillas).

## 📂 Carpetas
- **ad-hoc/** → Consultas puntuales no recurrentes.
- **validaciones/** → Scripts para revisión y control de calidad de datos.
- **correcciones/** → Scripts correctivos sobre datos.
- **reportes/** → Consultas recurrentes para reportes del área.
- **utilidades/** → Funciones y utilidades compartidas.

## 🚦 Buenas prácticas
1. **Separar validación y actualización**: siempre incluir SELECT antes de UPDATE/DELETE.
2. **Transacciones y COMMIT manual**: por defecto, dejar `COMMIT` comentado.
3. **Comentarios en cada script**:
   - Propósito, tablas, filtros, parámetros, autor, fecha.
4. **Pruebas en entorno seguro** antes de producción.
5. **Evidencia**: guardar resultados clave en comentario o archivo anexo.

## ⚠️ Seguridad
- No subir credenciales ni datos sensibles.
- Si el script requiere parámetros, dejar variables configurables (`@Campania`, `@Cultivo`, etc.).

---
