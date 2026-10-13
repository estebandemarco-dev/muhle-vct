/* ========================================================================
   VCT PROYECTOS                                                         v1
   ------------------------------------------------------------------------
   Pantalla Proyectos (opcion del sidebar).
   Filtro de Servicio: un proyecto puede tener varios servicios, y el motor
   de grillas filtra por valor exacto. Cada fila trae data-vct-srv="co au ca"
   (lista); al cambiar el combo [data-vct-dg-filter="srv"] se recalcula
   data-vct-filter-srv en TODAS las filas (tambien las que el paginado saco
   del DOM, via VCTDataGrid.get) antes de que el motor filtre.
   Guarda propia: no depende de la version de vct-datagrid.js.
   ======================================================================== */
(function () {
    "use strict";
    if (window.VCTProyectos && window.VCTProyectos.version >= 1) return;

    function applySrv(sel) {
        var host = sel.closest ? sel.closest("[data-vct-dg]") : null;
        if (!host) return;
        var id = host.getAttribute("data-vct-dg-id");
        var value = String(sel.value || "").toLowerCase();
        var state = window.VCTDataGrid && VCTDataGrid.get ? VCTDataGrid.get(id) : null;
        var rows = state && state.rows ? state.rows : host.querySelectorAll("tr[data-vct-row]");
        Array.prototype.forEach.call(rows, function (row) {
            var list = " " + String(row.getAttribute("data-vct-srv") || "").toLowerCase() + " ";
            row.setAttribute("data-vct-filter-srv", value && list.indexOf(" " + value + " ") >= 0 ? value : "-");
        });
    }

    /* fase de captura: corre antes que el listener del motor (en el host) */
    document.addEventListener("change", function (e) {
        var t = e.target;
        if (t && t.matches && t.matches("select[data-vct-dg-filter=\"srv\"]")) applySrv(t);
    }, true);

    window.VCTProyectos = { version: 1, applySrv: applySrv };
})();
