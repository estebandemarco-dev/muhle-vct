# Muhle VCT — contexto para Claude Code

Este archivo lo lee Claude Code automáticamente al abrir la carpeta del repo. Es el contexto compartido del equipo: **Esteban de Marco** (owner del proyecto, relación con el cliente Vocaturo) y **Martín Aja**. Si algo de acá queda viejo, se corrige en este archivo y se commitea.

Responder siempre en **español**.

## Qué es

Plataforma de gestión de la consultora **Vocaturo** (proyectos de normas ISO: consultoría, auditoría, capacitación). Se está rehaciendo el "MAIN" con estética nueva sobre la plataforma Muhle (legacy en producción: vocaturo.muhle.io).

- **Desarrollo (desa):** http://vocaturo.desa.interdev.online — SQL Server 192.168.10.227 (SQL 2017 Express), base `MuhlePROD`, compatibilidad **140**.
- **Producción:** sigue en compatibilidad **100**: no usar `OPENJSON`, `TRY_CONVERT`, `STRING_AGG ... WITHIN GROUP` en SPs que vayan a prod.
- La "ley" funcional es la reunión resumida en `Resumen_reunion_sistema_gestion.txt`: todo vive a nivel PROYECTO y el plan estratégico es el eje.

## Reglas de trabajo (importantes)

1. **El servidor es la fuente.** La copia local puede estar vieja. Antes de modificar un SP o un css/js existente, partir de la versión vigente del servidor (`DUMP_SP_DEFINICION.sql`, `db/objetos/`, o `tools/pull_assets.ps1` para css/js).
2. **Las personas corren los scripts**, no Claude: los SQL se pegan en SSMS y los assets se suben a mano al servidor web. Entregar el script completo listo para pegar.
3. **Sin credenciales:** Claude no usa ni guarda contraseñas de la base ni del servidor, y no se loguea en el navegador (lo hace la persona).
4. **Diagnósticos:** todo `DIAG_*.sql` empieza con `:OUT <carpeta del repo>\_diag\<NOMBRE>.txt` (SSMS en Query > SQLCMD Mode); la persona corre F5 y Claude lee el .txt.
5. **Mails de prueba** solo a `martin.aja@squad.com.ar` y `esteban.de.marco@squad.com.ar` (destino LIBRE en las plantillas) hasta pasar a producción. Nunca a analistas/consultores reales.
6. **Scripts re-ejecutables:** cada parche lleva una marca (ej. `VISITAS_V1`, `ACCIONES_RUTEO_V1`) y si ya está aplicado avisa y no hace nada.
7. **Caché:** al cambiar un css/js subir el `?v=N` en el SP que lo carga (el JS tiene guardas tipo `__vctXLoaded`: recargar la página completa).
8. **Git:** ramas + Pull Request a `main`. No commitear `*.config`, `Bin`, `lib`, `_diag` ni nada con claves (ver `.gitignore`).
9. **Sin objetos nuevos por cada cambio:** no crear vistas, funciones de tabla ni tablas auxiliares para resolver un pedido. La lógica va dentro del SP que arma la pantalla o procesa la acción. Una tabla nueva solo si el modelo de datos lo pide de verdad y Esteban lo aprueba. (Se borraron todas las vistas y las funciones `VCT_PROYECTO_*` el 10/10/2026.)
10. **Estándar de grillas (toda grilla nueva o rehecha):** motor `vct-datagrid.js` igual que Clientes/Consultores/Empleados (`data-vct-dg`, `-page-size="10"`, `-density="compact"`, `-layout="fixed"`), misma tipografía, filtros arriba (buscador + `data-vct-dg-slot="filters"`), badges `vct-360-badge` alineados en su columna, columnas con `data-vct-width` para que no haya scroll horizontal, montos a la derecha. Nada de tablas HTML sueltas.
11. **Estándar de KPIs:** solo indicadores con sentido real sobre datos que existen (no inventar). Título corto en un renglón (ej. "Ventas del mes", no "Clientes con proyectos activos"). En una misma fila, cada KPI con tono distinto (`blue`, `violet`, `mint`, `amber`) e ícono distinto y que exista en el set de `data-vct-icon` (no existen: folder-plus, file-warning, wallet, plane, rocket). Sin saludos ni divs que ocupen lugar. Los dashboards llevan solo KPIs y gráficos (nada de grillas de proyectos/visitas).
12. **Paleta estándar de gráficos (Manual de Identidad Vocaturo):** la marca es bordó `#66062D` (Pantone 7421 C), gris `#333233` (Black 7 C) y blanco, tipografía Gotham. Los gráficos usan solo tonalidades de bordó y gris, alternadas. Base de 4 (gráficos de un color, que rotan al azar sin repetir en el panel, y anillos de hasta 4 partes): bordó medio `#8C1D47`, grafito `#4A4849`, bordó claro `#CF6F92`, gris medio `#8E8C8D`. Con más de 4 partes se usa la extendida de 10, siempre en este orden: los 4 base + `#66062D`, `#C4C2C3`, `#B23E68`, `#2B2A2B`, `#E8A9C0`, `#6E6C6D`. Más de 10 partes: las 9 mayores + "Otros" en `#6E6C6D`. No se usan otros colores en gráficos (salvo el ámbar de alerta "excedido").

## Arquitectura (lo mínimo para no perderse)

- Cada pantalla de MAIN la arma un SP `VCT_MAIN_*` con `@IPKEYJOB`, `@FORM_ID`, `@IUNIDAD` (= perfil, ej. `GERENCIA`), `@IAGENTE` (= usuario) y devuelve HTML.
- Estado entre pantallas: tabla `VCT_BUFFER` (`TEXTO11..30`, `IDSELEC01..03`, `FLAG01`, `ACTION`). Los comandos de las pantallas viajan en `TEXTO30`.
- Ruteo: `STEP_TRANSACTION_FLOW` / `STORED_PROCEDURES`; decisión por `ACTION` del buffer. `window.goto(formId, guid)` conserva el buffer. INICIO → `447E1496-AC9B-4821-B658-25AB8D1F45AE`, CLIENTES → `26899560-A8E8-4E54-A3C8-F9ED1E95DC45`. `PROYECTOS` y `AGENDA_CONSULTOR` no tienen SP y caen en el Inicio.
- Abrir la 360 de un proyecto: `VCT.Buffer.store('IDSELEC01', cliente)` + grid-action `data-vct-store="IDSELEC02"` `data-vct-guid="330B876D-4E57-4E2E-BFC3-D7B998D09725"`.
- Permisos: única fuente `dbo.VCT_MAIN_GET_ACTIONS(@IUNIDAD, módulo)` (Groups → GroupsActions → PrmActions). Nada hardcodeado ni con LIKE: si no devuelve el permiso, se agrega en `PrmActions`. Funciones escalares: solo queda `VCT_MAIN_RENDER_ACTION`. Un usuario = un perfil.
- Vínculo usuario ↔ persona: `VCT_CONSULTORES.ID_USUARIO_SEGURIDAD` / `VCT_EMPLEADOS.ID_USUARIO_SEGURIDAD` (consultores requieren `INGRESA_SISTEMA = 1`).
- UI: grillas con el motor `vct-datagrid.js` (`data-vct-dg`), selects/inputs de 38px y el date picker propio (nunca `<input type=date>` nativo). Componentes 360: `.vct-360-module`, `.vct-360-stats-row` / `.vct-360-stat[data-vct-tone]`, `.vct-360-box`. Paleta: bordó `#66062D`, neutros slate.

## Gotchas de SQL que ya nos mordieron

- Concatenar literales VARCHAR corta a 8000: arrancar con `CONVERT(VARCHAR(MAX), '')`.
- No poner `;` antes de `ELSE`. `PRINT` no acepta subconsultas (usar variable).
- `--` dentro de un `/* */` antes del `*/` rompe el comentario.
- Pegar dos scripts juntos produce `GOUSE`: una ventana de SSMS por script.
- Parches sobre la definición vigente: pasar CREATE→ALTER mirando las 40 letras antes de `PROCEDURE`/`FUNCTION` y envolver `EXEC sp_executesql` en `TRY/CATCH`.

## Estructura del repo

- Raíz: scripts de entrega numerados en orden de ejecución (`PROYECTO_ALTA_1..5`, `PROYECTO_LANZ_1..5`, `PROYECTO_PLAN_1..3`, `PROYECTO_VISITAS_1..3`, `INICIO_PERFIL_1..4`, `ACCIONES_1..3`, `PULIDO_*`, `FIX_*`) y diagnósticos `DIAG_*`.
- **Espejo del servidor** (`C:\inetpub\wwwroot\muhle-vct`): `css/`, `js/`, `main/`, `task/`, `login/`, `profile/`, `admin/`, `img/`, `lib/`, `Bin/`, los `.aspx`… con la misma estructura. `css/` y `js/` se actualizan con `tools/pull_assets.ps1` (lee el listado de carpetas del servidor y baja todo, salvo `tools/assets_excluir.txt`). Nunca van al repo `web.config` (machineKey) ni `Log/`. Las copias sueltas `vct-*.css/js` de la raíz NO son la fuente. Ojo: si un css/js se cambió en el repo y todavía no se subió al servidor, correr el script lo pisa; subirlo antes o restaurarlo con git.
- `db/objetos/`: definiciones de SPs/funciones volcadas de la base (`db/DUMP_OBJETOS.sql` + `tools/split_dump.py`).
- `db/AUDITORIA_*`: trigger de auditoría DDL (mail en cada cambio de estructura) y vigilante de archivos del servidor web (`tools/vigilante`).

## Estado (09/10/2026)

Andando y probado punta a punta en desa (proyecto de prueba 1343): alta de proyecto (+mail), lanzamiento 4 pasos + iniciar (+mail), plan estratégico (plan base 47 ítems, cronograma, export, aviso de cambio de fecha por mail), visitas y horas, avance sincronizado en las listas 360, Inicio por perfil con campanita de notificaciones, pantalla Acciones (KPIs, gráficos, cerrar/reabrir gestiones), sidebar móvil con nombres.

Pendientes: correr `PULIDO_1_TILDES_AVISOS.sql`; grilla de Acciones angosta en celular; decidir si ADMINISTRACION edita el lanzamiento; destinatarios reales de mails al ir a prod; pantallas de Proyectos y Agenda; borrar proyectos de prueba 1339–1343 y personas "(PRUEBA)" (lo hace el equipo, al final). Presentación al cliente: ~22/10.
