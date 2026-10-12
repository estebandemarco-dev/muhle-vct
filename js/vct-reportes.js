/* ========================================================================
   VCT REPORTES - V3
   ------------------------------------------------------------------------
   Menu superior con dropdown por categoria (Actividad y proyectos /
   Personas / Viaticos / Rentabilidad), mas breadcrumb debajo. Aislado de
   vct-main.js, mismo criterio que vct-config-parametria.js, pero con
   nombres de atributo propios de Reportes.

   Contrato HTML esperado (lo arma VCT_MAIN_REPORTES):
     <div data-vct-report-root data-vct-report-active="<reporte>">
         <nav class="vct-report-topnav">
             <!-- item directo (categoria de 1 solo reporte, ej.
                  Rentabilidad): data-vct-report-cat Y data-vct-report-
                  group juntos en el MISMO boton -->
             <button data-vct-report-cat="rentabilidad" data-vct-report-group="rentabilidad">Rentabilidad</button>
             <!-- categoria con dropdown: SIN data-vct-report-group propio -->
             <div class="vct-report-topnav-item">
                 <button data-vct-report-cat="actividad" aria-expanded="false">Actividad y proyectos</button>
                 <div class="vct-report-dropdown" data-vct-report-cat-panel="actividad">
                     <button data-vct-report-group="parte-actividades">...</button>
                     ...
                 </div>
             </div>
             ...
         </nav>
         <div class="vct-report-breadcrumb" data-vct-report-breadcrumb></div>
         <div data-vct-report-group-panel="parte-actividades">...</div>
         ...
     </div>
   ======================================================================== */
(function (window, document) {
    "use strict";

    /* Un boton de categoria con data-vct-report-group propio (Resumen,
       Rentabilidad) ES a la vez su propio grupo -- no tiene dropdown. */
    function catOf(root, group) {
        var direct = root.querySelector('[data-vct-report-cat][data-vct-report-group="' + group + '"]');
        if (direct) return direct.getAttribute("data-vct-report-cat");
        var btn = root.querySelector('[data-vct-report-group="' + group + '"]');
        var panel = btn ? btn.closest("[data-vct-report-cat-panel]") : null;
        return panel ? panel.getAttribute("data-vct-report-cat-panel") : null;
    }

    function closeAllDropdowns(root) {
        root.querySelectorAll("[data-vct-report-cat-panel]").forEach(function (panel) {
            panel.classList.remove("is-open");
        });
        root.querySelectorAll("[data-vct-report-cat]").forEach(function (btn) {
            if (!btn.hasAttribute("data-vct-report-group")) btn.setAttribute("aria-expanded", "false");
        });
    }

    function openDropdown(root, cat) {
        var panel = root.querySelector('[data-vct-report-cat-panel="' + cat + '"]');
        if (!panel) return;
        panel.classList.add("is-open");
        var btn = root.querySelector('[data-vct-report-cat="' + cat + '"]');
        if (btn) btn.setAttribute("aria-expanded", "true");
    }

    function updateBreadcrumb(root, cat, group) {
        var bc = root.querySelector("[data-vct-report-breadcrumb]");
        if (!bc) return;
        var catBtn = root.querySelector('[data-vct-report-cat="' + cat + '"]');
        var groupBtn = root.querySelector('[data-vct-report-group="' + group + '"]');
        var catLabel = catBtn ? catBtn.textContent.trim() : "";
        var groupLabel = groupBtn ? groupBtn.textContent.trim() : "";
        var parts = ["Reportes"];
        if (catLabel) parts.push(catLabel);
        if (groupLabel && groupLabel !== catLabel) parts.push(groupLabel);
        /* v15: mismo breadcrumb que la pestaña Agenda: separador y ultimo nivel en bordo */
        bc.textContent = "";
        parts.forEach(function (p, i) {
            if (i) { var sep = document.createElement("span"); sep.className = "vct-report-crumb-sep"; sep.textContent = "\u203A"; bc.appendChild(sep); }
            var el = document.createElement(i === parts.length - 1 ? "b" : "span");
            el.textContent = p;
            bc.appendChild(el);
        });
    }

    /* ====================================================================
       v16 - COLUMNAS "OPCION A" POR REPORTE (no depende del SP)
       Marca los <th> de cada grilla con los atributos que lee la extension
       de detalle de vct-datagrid.js (v10+):
         detail -> columna que pasa al detalle de la fila (flecha)
         sub    -> columna que va como 2do renglon de otra (Proyecto bajo Cliente)
         person -> avatar con iniciales + nombre
         svc    -> icono + nombre del servicio
       Los titulos se comparan sin tildes ni mayusculas. Excel/PDF exportan todo.
       ==================================================================== */
    var VIAT = { sub: { "proyecto": "Cliente" }, svc: ["servicio"], person: ["huesped", "pasajero"],
                 detail: ["nro factura", "fecha factura", "tipo huesped", "tipo pasajero", "forma pago", "desc. forma pago", "cuotas"] };
    var REPORT_COLS = {
        "reportes-parte-actividades": { sub: { "descripcion": "Cliente" }, svc: ["servicio"], person: ["consultor"],
                                        detail: ["observaciones", "obs. calificacion", "obs. hoja ruta"] },
        "reportes-seg-consultoria": { sub: { "proyecto": "Cliente" }, detail: ["personal afectado", "frec. envio plan", "observaciones"] },
        "reportes-seg-auditoria": { sub: { "proyecto": "Cliente" }, detail: ["lugar", "auditores", "fecha pa", "fecha inf.", "tiempo inf."] },
        "reportes-seg-capacitacion": { sub: { "proyecto": "Cliente" }, detail: ["instructores", "material", "recibido", "fecha inf.", "tiempo inf."] },
        "reportes-calif-consultores": { person: ["consultor"], svc: ["tipo servicio", "servicio"] },
        "reportes-indice-ocupacion": { person: ["consultor"] },
        "reportes-seg-hoteles": VIAT,
        "reportes-seg-pasajes": VIAT,
        "reportes-seg-remis": VIAT,
        "reportes-rentabilidad": { sub: { "proyecto": "Cliente" }, detail: ["costo estim.", "utilidad estim.", "compras acum."] }
    };

    function foldText(t) {
        t = String(t == null ? "" : t).replace(/\s+/g, " ").trim().toLowerCase();
        return t.normalize ? t.normalize("NFD").replace(/[̀-ͯ]/g, "") : t;
    }

    function applyReportColumns(scope) {
        var hosts = [];
        if (scope.matches && scope.matches("[data-vct-dg-id]")) hosts.push(scope);
        Array.prototype.forEach.call(scope.querySelectorAll("[data-vct-dg-id]"), function (h) { hosts.push(h); });
        var touched = [];
        hosts.forEach(function (host) {
            var cfg = REPORT_COLS[host.getAttribute("data-vct-dg-id")];
            var thead = host.querySelector("table thead");
            if (!cfg || !thead || host.__repCols) return;
            host.__repCols = true;
            Array.prototype.forEach.call(thead.querySelectorAll("th"), function (th) {
                var t = foldText(th.textContent);
                if ((cfg.detail || []).indexOf(t) >= 0 && !th.hasAttribute("data-vct-detail")) th.setAttribute("data-vct-detail", "1");
                if (cfg.sub && cfg.sub[t] && !th.hasAttribute("data-vct-sub-of")) th.setAttribute("data-vct-sub-of", cfg.sub[t]);
                if ((cfg.person || []).indexOf(t) >= 0 && !th.hasAttribute("data-vct-person")) th.setAttribute("data-vct-person", "1");
                if ((cfg.svc || []).indexOf(t) >= 0 && !th.hasAttribute("data-vct-svc")) th.setAttribute("data-vct-svc", "1");
            });
            touched.push(host.getAttribute("data-vct-dg-id"));
        });
        return touched;
    }

    function rerender(ids) {
        if (!window.VCTDataGrid || !window.VCTDataGrid.render) return;
        ids.forEach(function (id) { try { window.VCTDataGrid.render(id); } catch (e) { /* noop */ } });
    }

    function activateTopnav(root, cat) {
        root.querySelectorAll("[data-vct-report-cat]").forEach(function (btn) {
            btn.classList.toggle("is-active", btn.getAttribute("data-vct-report-cat") === cat);
        });
    }

    function activateGroup(root, group) {
        root.querySelectorAll("[data-vct-report-group]").forEach(function (btn) {
            btn.classList.toggle("is-active", btn.getAttribute("data-vct-report-group") === group);
        });
        root.querySelectorAll("[data-vct-report-group-panel]").forEach(function (panel) {
            panel.classList.toggle("is-active", panel.getAttribute("data-vct-report-group-panel") === group);
        });
        root.setAttribute("data-vct-report-active", group);
        /* Las grillas de un panel que estaba oculto miden 0 (recortes "Ver mas"): se
           re-renderizan al mostrarse. */
        if (window.VCTDataGrid) {
            root.querySelectorAll('[data-vct-report-group-panel="' + group + '"] [data-vct-dg-id]').forEach(function (host) {
                window.VCTDataGrid.render(host.getAttribute("data-vct-dg-id"));
            });
        }
    }

    function activate(root, group) {
        var cat = catOf(root, group);
        if (cat) {
            activateTopnav(root, cat);
            updateBreadcrumb(root, cat, group);
        }
        activateGroup(root, group);
        closeAllDropdowns(root);
    }

    /* El SP siempre imprime el boton "Ver completo" en las celdas
       truncatable, aunque el dato este vacio (ej. Observaciones, que casi
       nunca tiene texto) -- eso deja una flechita flotando sola en la
       celda, sin nada para desplegar. Se oculta por JS cuando el texto de
       la celda esta vacio. */
    function hideEmptyExpandButtons(root) {
        root.querySelectorAll(".vct-table-cell-truncatable").forEach(function (cell) {
            var text = cell.querySelector(".vct-table-cell-text");
            var btn = cell.querySelector(".vct-table-cell-expand");
            if (!text || !btn) return;
            btn.style.display = text.textContent.trim() === "" ? "none" : "";
        });
    }

    /* Un grafico cuenta como "sin datos" si su unico contenido es el
       placeholder que ya arma el SP: .vct-gantt-empty (gantt y barchart
       comparten esa clase para el caso vacio) o, en un donut, una leyenda
       de un solo item SIN <b> (los items reales siempre tienen <b>cantidad
       </b> -- el placeholder "Sin datos" es el unico caso sin ese tag). */
    function isChartEmpty(chartEl) {
        var seriesEl = chartEl.querySelector(".vct-gantt, .vct-barchart");
        if (seriesEl) {
            return seriesEl.children.length === 1 &&
                   seriesEl.children[0].classList.contains("vct-gantt-empty");
        }
        var legend = chartEl.querySelector(".vct-donut-legend");
        if (legend) {
            var items = legend.querySelectorAll(".vct-donut-legend-item");
            return items.length === 1 && !items[0].querySelector("b");
        }
        return false;
    }

    /* Oculta las cards de .vct-report-chart-grid que resultaron sin datos
       para el filtro actual, y reacomoda data-vct-chart-cols al numero de
       cards que quedaron visibles -- sin esto, ocultar un grafico dejaba
       un hueco vacio en vez de que los demas se repartieran el 100%. */
    function hideEmptyCharts(root) {
        root.querySelectorAll(".vct-report-chart-grid").forEach(function (grid) {
            var visible = 0;
            grid.querySelectorAll(".vct-report-chart").forEach(function (chart) {
                if (isChartEmpty(chart)) {
                    chart.style.display = "none";
                } else {
                    visible++;
                }
            });
            if (visible > 0) grid.setAttribute("data-vct-chart-cols", String(visible));
        });
    }

    /* ========================================================================
       FILTRO LIVIANO (sin recarga completa)
       ------------------------------------------------------------------------
       Antes: cualquier "change"/Enter en un filtro disparaba
       VCT.DomForm.validateAndNext -> window.next() -> sendForm() (js/Main.js),
       que serializa TODO el form y reemplaza TODO #mainContainer con la
       respuesta -- aunque el SP ya calculaba (ver VCT_MAIN_REPORTES.sql,
       @CALC_TODOS_LOS_PANELES) solo el panel activo en estos casos, el
       cliente igual repintaba toda la pagina (flash completo, pierde scroll,
       cierra dropdowns abiertos).

       Ahora: se replica el MISMO POST que ya hace sendForm() (mismo form,
       mismo action_name=continue, mismo endpoint task/Default.aspx -- no se
       inventa un endpoint nuevo ni se toca js/Main.js, que es codigo de
       framework compartido por toda la app) pero con nuestro propio
       $.ajax + callback: en vez de $("#mainContainer").html(data), se
       parsea la respuesta y se reemplaza SOLO el innerHTML del panel
       actualmente activo (data-vct-report-group-panel). El resto de la
       pagina (topnav, breadcrumb, scroll, los otros 9 paneles ya
       pre-renderizados) queda intacto.

       SP.FLAG01=1 es la señal que lee VCT_MAIN_REPORTES.sql para saber que
       este pedido puntual es justamente uno de estos (y por lo tanto solo
       necesita calcular el panel activo, no los 10) -- ver el comentario
       "PERF" en el SP.

       Si algo falla (jQuery no esta, no hay form, el fetch falla, o la
       respuesta no trae el panel esperado) se cae al camino de siempre
       (click en el boton oculto data-vct-command="validate-next"), asi
       el filtro nunca se "pierde" silenciosamente. */
    /* Error del servidor / timeout en una busqueda liviana: se avisa DENTRO del panel y se
       conservan los datos que ya estaban en pantalla (antes se caia al camino pesado, que
       pisaba toda la pagina con el error de SQL). */
    function showPanelError(panelEl, message) {
        if (!panelEl) return;
        var old = panelEl.querySelector(":scope > .vct-report-error");
        if (old) old.parentNode.removeChild(old);
        var box = document.createElement("div");
        box.className = "vct-report-error";
        box.setAttribute("role", "alert");
        box.innerHTML = "<strong>No se pudo completar la búsqueda.</strong> <span></span>" +
            '<button type="button" class="vct-report-error-close" aria-label="Cerrar">&times;</button>';
        box.querySelector("span").textContent = message;
        box.querySelector("button").addEventListener("click", function () { box.parentNode && box.parentNode.removeChild(box); });
        panelEl.insertBefore(box, panelEl.firstChild);
        try { if (window.VCT && VCT.Toast && VCT.Toast.show) VCT.Toast.show("La búsqueda no se pudo completar. Probá con un rango de fechas más corto.", "warning"); } catch (e) { /* noop */ }
    }

    function looksLikeServerError(html) {
        return /Se produjo un error en la ejecuci/i.test(html || "") && !/data-vct-report-group-panel/.test(html || "");
    }

    function patchPanel(root, panelName, html) {
        if (!panelName) return false;
        var doc = new DOMParser().parseFromString(html, "text/html");
        var freshPanel = doc.querySelector('[data-vct-report-group-panel="' + panelName + '"]');
        var livePanel = root.querySelector('[data-vct-report-group-panel="' + panelName + '"]');
        if (!freshPanel || !livePanel) return false;
        /* Respuesta sin contenido real (p.ej. el SP devolvio otro panel o fallo): NO se
           pisa el panel vivo con vacio -- se cae al camino de siempre. */
        if (!freshPanel.querySelector("[data-vct-dg], .vct-card-body")) return false;
        /* Se arma TODO en un fragmento fuera del documento (nodos adoptados, sin re-serializar el
           HTML) y las grillas se inicializan ahi mismo; recien despues entra al documento de una
           sola vez. Cada nodo agregado al documento dispara los observadores globales de
           vct-main.js (~5 ms por nodo): con miles de filas, insertarlas "vivas" trababa la pantalla. */
        var frag = document.createDocumentFragment();
        while (freshPanel.firstChild) frag.appendChild(document.adoptNode(freshPanel.firstChild));
        applyReportColumns(frag);
        if (window.VCTDataGrid) window.VCTDataGrid.init(frag);
        livePanel.textContent = "";
        livePanel.appendChild(frag);
        rerender(Array.prototype.map.call(livePanel.querySelectorAll("[data-vct-dg-id]"), function (h) { return h.getAttribute("data-vct-dg-id"); }));
        hideEmptyExpandButtons(livePanel);
        hideEmptyCharts(livePanel);
        return true;
    }

    /* Overlay de carga global de la plataforma (.vct-loading-overlay + .vct-spinner, definido en
       vct-main.css, seccion "SPINNER DE CARGA GLOBAL"). La busqueda liviana no pasa por el
       postback de la plataforma, asi que lo muestra/oculta ella misma. Se reusa el elemento
       si ya existe. Fallback inline por si el CSS de la plataforma no estuviera cargado. */
    function setOverlay(on) {
        var el = document.querySelector("[data-vct-loading-overlay]") || document.querySelector(".vct-loading-overlay");
        if (!el && on) {
            el = document.createElement("div");
            el.className = "vct-loading-overlay";
            el.setAttribute("data-vct-loading-overlay", "");
            el.innerHTML = '<div class="vct-spinner"></div>';
            document.body.appendChild(el);
        }
        if (!el) return;
        el.classList.toggle("is-active", !!on);
        if (!on) el.style.removeProperty("display");
        else if (window.getComputedStyle(el).display === "none") el.style.setProperty("display", "flex", "important");
    }

    function submitFilterLight(root, scope) {
        var fallbackBtn = scope.querySelector('[data-vct-command="validate-next"]');
        var $ = window.jQuery;
        var formId = (window.VCT && VCT.Util && VCT.Util.getFormId) ? VCT.Util.getFormId(scope) : "";
        var form = formId ? document.getElementById(formId) : null;
        var canSync = window.VCT && VCT.DomForm && typeof VCT.DomForm.syncToBuffer === "function";

        if (!$ || !form || !canSync) {
            if (fallbackBtn) fallbackBtn.click();
            return;
        }

        /* Mismas precondiciones que VCT.DomForm.validateAndNext */
        if (window.VCT.Validation && typeof VCT.Validation.validate === "function" && !VCT.Validation.validate(scope)) return;
        if (scope.dataset.vctFilterBusy === "1") return;
        scope.dataset.vctFilterBusy = "1";

        var panelEl = scope.closest("[data-vct-report-group-panel]");
        var searchBtn = scope.querySelector("[data-vct-report-search]");
        var searchLabel = searchBtn ? searchBtn.querySelector("span") : null;
        if (panelEl) panelEl.classList.add("is-loading");
        if (searchBtn) searchBtn.disabled = true;
        if (searchLabel) searchLabel.textContent = "Buscando…";
        setOverlay(true);
        var finish = function () {
            scope.dataset.vctFilterBusy = "0";
            setOverlay(false);
            if (panelEl) panelEl.classList.remove("is-loading");
            if (searchBtn) searchBtn.disabled = false;
            if (searchLabel) searchLabel.textContent = "Buscar";
        };
        var panelName = panelEl ? panelEl.getAttribute("data-vct-report-group-panel") : (root.getAttribute("data-vct-report-active") || "");

        /* syncToBuffer -> activateScope deja UNA sola copia con name de cada SP.xxx (la de
           ESTE panel) y les saca el name a las de los otros 9 paneles. Sin esto, form.serialize()
           manda SP.ACTIVE_TAB / SP.TEXTO03 x10 y el servidor se queda con la ultima copia
           (otro panel, fechas viejas) -> panel vacio. */
        VCT.DomForm.syncToBuffer(scope, function (ok) {
            if (!ok) { finish(); return; }
            window.setTimeout(function () {
                var actionField = document.getElementById(formId + "_action_name");
                if (actionField) actionField.value = "continue";
                var payload = $(form).serialize() + "&SP.FLAG01=1";

                $.ajax({
                    type: "POST",
                    url: "../task/Default.aspx",
                    data: payload,
                    dataType: "text"
                }).done(function (html) {
                    if (looksLikeServerError(html)) {
                        showPanelError(panelEl, /Timeout/i.test(html)
                            ? "El servidor tardó demasiado en responder (el rango de fechas es muy grande). Elegí un rango más corto."
                            : "El servidor devolvió un error al procesar los filtros.");
                        return;
                    }
                    var old = panelEl && panelEl.querySelector(":scope > .vct-report-error");
                    if (old) old.parentNode.removeChild(old);
                    if (!patchPanel(root, panelName, html) && fallbackBtn) fallbackBtn.click();
                }).fail(function () {
                    showPanelError(panelEl, "No hubo respuesta del servidor. Revisá la conexión o probá con un rango de fechas más corto.");
                }).always(finish);
            }, 40);
        });
    }

    function init(root) {
        if (root.dataset.vctReportReady === "1") return;
        root.dataset.vctReportReady = "1";

        hideEmptyExpandButtons(root);
        hideEmptyCharts(root);
        rerender(applyReportColumns(root));

        var initial = root.getAttribute("data-vct-report-active") || "";
        if (!initial || !root.querySelector('[data-vct-report-group="' + initial + '"]')) {
            var firstBtn = root.querySelector("[data-vct-report-group]");
            initial = firstBtn ? firstBtn.getAttribute("data-vct-report-group") : "";
        }
        if (initial) activate(root, initial);

        root.addEventListener("click", function (event) {
            var catBtn = event.target.closest("[data-vct-report-cat]");
            if (catBtn) {
                event.preventDefault();
                var cat = catBtn.getAttribute("data-vct-report-cat");
                var ownGroup = catBtn.getAttribute("data-vct-report-group");
                if (ownGroup) {
                    activate(root, ownGroup);
                } else {
                    var panel = root.querySelector('[data-vct-report-cat-panel="' + cat + '"]');
                    var wasOpen = panel && panel.classList.contains("is-open");
                    closeAllDropdowns(root);
                    if (!wasOpen) openDropdown(root, cat);
                }
                return;
            }

            var groupBtn = event.target.closest("[data-vct-report-group]");
            if (groupBtn && !groupBtn.hasAttribute("data-vct-report-cat")) {
                event.preventDefault();
                activate(root, groupBtn.getAttribute("data-vct-report-group"));
                return;
            }

            if (!event.target.closest("[data-vct-report-cat-panel]")) {
                closeAllDropdowns(root);
            }
        });

        document.addEventListener("click", function (event) {
            if (!root.contains(event.target)) closeAllDropdowns(root);
        });

        /* Busqueda de Reportes (SPA, sin salto de pagina):
           - Al setear un filtro (change) o con Enter se lanza UN solo pedido que
             actualiza unicamente el panel activo (submitFilterLight), sin recargar la
             pantalla ni mover el scroll (listener de "change" mas abajo, con debounce).
           - El boton "Buscar" (data-vct-report-search) ya no se muestra; el handler queda
             por compatibilidad con paneles que aun lo tengan.
           El buscador de texto de la grilla vive en el motor de grilla
           (vct-datagrid.js) y filtra en el navegador, sin pedir nada al servidor. */
        root.addEventListener("click", function (event) {
            var btn = event.target.closest("[data-vct-report-search]");
            if (!btn) return;
            event.preventDefault();
            var scope = btn.closest("[data-vct-form-scope]");
            if (scope) submitFilterLight(root, scope);
        });

        root.addEventListener("keydown", function (event) {
            if (event.key !== "Enter") return;
            var scope = event.target.closest("[data-vct-form-scope]");
            if (!scope) return;
            event.preventDefault();
            submitFilterLight(root, scope);
        });

        /* Sin boton Buscar: la consulta se lanza al setear un filtro (fecha o combo).
           Es el mismo pedido liviano de arriba (solo el panel activo, sin salto de pagina);
           con debounce para que cambiar varios campos seguidos sea UNA sola consulta, y en
           silencio (sin errores de validacion) mientras falte alguna fecha o el rango este
           invertido. */
        var autoTimers = new WeakMap();
        root.addEventListener("change", function (event) {
            var scope = event.target.closest && event.target.closest("[data-vct-form-scope]");
            if (!scope || !scope.querySelector("[data-vct-report-search], [data-vct-command=\"validate-next\"]")) return;

            var dates = scope.querySelectorAll('input[type="date"]');
            var vals = [];
            for (var i = 0; i < dates.length; i++) {
                if (!dates[i].value) return;
                vals.push(dates[i].value);
            }
            if (vals.length === 2 && vals[0] > vals[1]) return;

            window.clearTimeout(autoTimers.get(scope));
            autoTimers.set(scope, window.setTimeout(function () {
                submitFilterLight(root, scope);
            }, 350));
        });
    }

    /* Celdas de texto largo (Cliente, Proyecto, Observaciones, Personal
       Afectado, etc.) truncadas a 1 sola linea con boton para desplegar --
       mismo sistema/clases que la grilla de templates de email
       (vct-table-cell-truncatable / vct-table-cell-expand / is-expanded en
       vct-email-template-designer.js), replicado aca porque esa grilla
       vive en un archivo aislado que Reportes no carga. */
    function toggleCellExpand(button) {
        var cell = button.closest(".vct-table-cell-truncatable");
        if (!cell) return;
        cell.classList.toggle("is-expanded");
    }

    function scan(scope) {
        scope = scope || document;
        var roots = [];
        if (scope.matches && scope.matches("[data-vct-report-root]")) roots.push(scope);
        if (scope.querySelectorAll) scope.querySelectorAll("[data-vct-report-root]").forEach(function (r) { roots.push(r); });
        roots.forEach(init);
    }

    document.addEventListener("click", function (event) {
        var expandBtn = event.target.closest("[data-vct-cell-expand]");
        if (!expandBtn || !expandBtn.closest("[data-vct-report-root]")) return;
        event.preventDefault();
        toggleCellExpand(expandBtn);
    });

    scan(document);

    if (window.MutationObserver) {
        new MutationObserver(function (mutations) {
            mutations.forEach(function (m) {
                Array.prototype.forEach.call(m.addedNodes || [], function (n) {
                    if (n && n.nodeType === 1) scan(n);
                });
            });
        }).observe(document.documentElement, { childList: true, subtree: true });
    }
})(window, document);
