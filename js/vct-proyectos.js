/* ========================================================================
   VCT PROYECTOS                                                         v5
   ------------------------------------------------------------------------
   Pantalla Proyectos (opcion del sidebar, dbo.VCT_MAIN_PROYECTOS).
   - Filtro Servicio: un proyecto puede tener varios servicios y el motor de
     grillas filtra por valor exacto. Cada fila trae data-vct-srv="co au ca";
     al cambiar el combo se recalcula data-vct-filter-srv en TODAS las filas
     (tambien las que el paginado saco del DOM, via VCTDataGrid.get) antes de
     que el motor filtre (listener en fase de captura).
   - Boton de modo [data-vct-pry-modo] ("Otros estados" / "En curso y
     confirmados"): guarda TEXTO30 en el buffer ESPERANDO a que se grabe
     (storeQueued) y refresca el mismo paso con VCT.Navigation.next: vuelve a
     correr VCT_MAIN_PROYECTOS con ACTION=PROYECTOS y el modo pedido.
   Guarda propia: no depende de la version de vct-datagrid.js.
   ======================================================================== */
(function () {
    "use strict";
    if (window.VCTProyectos && window.VCTProyectos.version >= 5) return;

    function rowsOf(sel) {
        var host = sel.closest ? sel.closest("[data-vct-dg]") : null;
        if (!host) return [];
        var id = host.getAttribute("data-vct-dg-id");
        var state = window.VCTDataGrid && VCTDataGrid.get ? VCTDataGrid.get(id) : null;
        return state && state.rows ? state.rows : host.querySelectorAll("tr[data-vct-row]");
    }

    function applySrv(sel) {
        var value = String(sel.value || "").toLowerCase();
        Array.prototype.forEach.call(rowsOf(sel), function (row) {
            var list = " " + String(row.getAttribute("data-vct-srv") || "").toLowerCase() + " ";
            row.setAttribute("data-vct-filter-srv", value && list.indexOf(" " + value + " ") >= 0 ? value : "-");
        });
    }

    /* fase de captura: corre antes que el listener del motor (en el host) */
    document.addEventListener("change", function (e) {
        var t = e.target;
        if (t && t.matches && t.matches("select[data-vct-dg-filter=\"srv\"]")) applySrv(t);
    }, true);

    function refrescar(btn) {
        var modo = btn.getAttribute("data-vct-pry-modo") || "PRY_MODO_VIGENTES";
        var go = function () { VCT.Navigation.next(btn); };
        if (VCT.Buffer.storeQueued) VCT.Buffer.storeQueued("TEXTO30", modo, null, go);
        else { VCT.Buffer.store("TEXTO30", modo); setTimeout(go, 400); }
    }

    document.addEventListener("click", function (e) {
        var b = e.target && e.target.closest ? e.target.closest("[data-vct-pry-modo]") : null;
        if (!b || b.disabled) return;
        e.preventDefault();
        e.stopPropagation();
        if (!window.VCT || !VCT.Buffer || !VCT.Navigation) { if (window.console) console.error("[VCTProyectos] falta VCT.Buffer / VCT.Navigation"); return; }
        b.disabled = true;
        b.classList.add("is-loading");
        try { refrescar(b); }
        catch (err) { b.disabled = false; b.classList.remove("is-loading"); if (window.console) console.error("[VCTProyectos]", err); }
    }, true);

    window.VCTProyectos = { version: 5, applySrv: applySrv };
})();
