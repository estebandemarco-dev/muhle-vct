/* vct-datagrid.js - v9 (pestana con subopciones: data-vctdg-tabgroup, en un bloque propio que se carga aunque la grilla ya este cargada; grilla dentro de tarjeta 360: clase vctdg-in-box; menu de fila de 3 puntos declarativo; toolbar estandar: buscador primero, filtros y "Registros por pagina" con el combo propio;
   en una tarjeta 360 el boton de alta del encabezado pasa al toolbar como "Nuevo")
   
   ============================================================================
   Motor de grilla unico para MAIN: busqueda, filtros, orden, paginado y export
   (Excel .xlsx / PDF con logo e imagenes via vct-export.js). Reemplaza a
   VCT.Grid + VCT.Export de vct-main.js y a toda la pila de CSS de tablas de
   vct-main.css. NO toca el motor de admin (vct-Core.js / vct-Table.js).

   El SP emite solo el "host" + la tabla; el motor CONSTRUYE toolbar y footer,
   asi que no pueden divergir entre pantallas:

     <div data-vct-dg
          data-vct-dg-id="reportes-seg-consultoria"
          data-vct-dg-title="Seguimiento de Consultoría"
          data-vct-dg-subtitle="Estado y avance de los proyectos."
          data-vct-dg-page-size="10"                 (opcional, default 10)
          data-vct-dg-unit="consultoría(s)"          (opcional, texto del contador)
          data-vct-dg-charts="charts-seg-consultoria" (opcional: id del modal de graficos)
          data-vct-dg-search-placeholder="Buscar..."  (opcional)>
         <div data-vct-dg-slot="filters"> ...filtros propios (p.ej. fechas)... </div>
         <div data-vct-dg-slot="actions"> ...p.ej. boton Nuevo... </div>
         <table>
           <thead><tr>
             <th data-vct-sortable="true" data-vct-sort-type="text|number|date">Cliente</th>
             <th data-vct-export-ignore="true">Acciones</th>
           </tr></thead>
           <tbody>
             <tr data-vct-row data-vct-filter-estado="ACTIVO" data-vct-search="texto extra">
               <td data-label="Cliente" data-vct-sort-value="..." data-vct-export-value="...">...</td>
             </tr>
           </tbody>
         </table>
     </div>

   Compatibles con el contrato viejo (para migrar sin reescribir los SP):
   th[data-vct-sortable|data-vct-sort-type|data-vct-export-ignore],
   tr[data-vct-row|data-vct-search|data-vct-filter-<clave>],
   td[data-vct-sort-value|data-vct-export-value], select[data-vct-grid-filter].

   API: VCTDataGrid.init(scope) | .get(id) | .refresh(id) | .render(id)
   Evento: "vctdg:render" en el host (detail: total, filtered, page, pages).
   ============================================================================ */
(function (window, document) {
    "use strict";

    if (window.VCTDataGrid && window.VCTDataGrid.version) return;

    var HOST_SEL = "[data-vct-dg]";
    var PAGE_SIZES = [10, 20, 50, 100];
    var MOBILE_MQ = "(max-width: 640px)";
    var registry = {};
    var seq = 0;

    /* Regla de plataforma: toda fecha dentro de una grilla usa el Date Picker de VCT
       (vct-datepicker.js + .css), no el <input type="date"> nativo. El motor lo carga solo,
       una vez, cuando encuentra una fecha en una grilla -- la pantalla no tiene que acordarse
       de incluir los tags (si ya los incluye, no se duplica). Rutas relativas a este script. */
    var SELF_SRC = (function () {
        var s = document.currentScript;
        if (s && s.src) return s.src;
        var all = document.getElementsByTagName("script");
        for (var i = all.length - 1; i >= 0; i--) if (/vct-datagrid\.js/i.test(all[i].src || "")) return all[i].src;
        return "";
    })();
    function siblingUrl(path) {
        try { return new URL(path, SELF_SRC || window.location.href).href; } catch (e) { return path; }
    }
    function ensureDatePicker(host) {
        if (!host.querySelector('input[type="date"]')) return;
        if (!document.querySelector('link[href*="vct-datepicker.css"]')) {
            var link = document.createElement("link");
            link.rel = "stylesheet";
            link.href = siblingUrl("../css/vct-datepicker.css?v=1");
            document.head.appendChild(link);
        }
        if (!window.__vctDatePickerLoaded && !document.querySelector('script[src*="vct-datepicker.js"]')) {
            var sc = document.createElement("script");
            sc.src = siblingUrl("../js/vct-datepicker.js?v=2");
            document.head.appendChild(sc);
        }
    }

    /* ------------------------------------------------------------------
       Iconos (inline: el motor no depende de VCT.Icon ni de fuentes)
       ------------------------------------------------------------------ */
    function svg(inner, size) {
        var s = size || 15;
        return '<svg viewBox="0 0 24 24" width="' + s + '" height="' + s + '" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' + inner + "</svg>";
    }
    var ICON = {
        search: svg('<circle cx="11" cy="11" r="8"></circle><path d="m21 21-4.3-4.3"></path>', 15),
        excel: svg('<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><path d="M14 2v6h6"></path><path d="M8 13h2M8 17h2M14 13h2M14 17h2"></path>', 15),
        pdf: svg('<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><path d="M14 2v6h6"></path><path d="M16 13H8M16 17H8M10 9H8"></path>', 15),
        chart: svg('<path d="M3 3v16a2 2 0 0 0 2 2h16"></path><path d="M18 17V9M13 17V5M8 17v-3"></path>', 15),
        first: svg('<path d="m11 17-5-5 5-5M18 17l-5-5 5-5"></path>', 14),
        prev: svg('<path d="m15 18-6-6 6-6"></path>', 14),
        next: svg('<path d="m9 18 6-6-6-6"></path>', 14),
        chev: svg('<path d="m6 9 6 6 6-6"></path>', 12),
        last: svg('<path d="m6 17 5-5-5-5M13 17l5-5-5-5"></path>', 14),
        sort: '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path class="up" d="m17 9-5-5-5 5"></path><path class="down" d="m7 15 5 5 5-5"></path></svg>'
    };

    /* ------------------------------------------------------------------
       Utilidades
       ------------------------------------------------------------------ */
    function esc(text) {
        return String(text === null || text === undefined ? "" : text)
            .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }
    function clean(text) {
        return String(text === null || text === undefined ? "" : text).replace(/ /g, " ").replace(/\s+/g, " ").trim();
    }
    function norm(text) {
        var t = String(text === null || text === undefined ? "" : text).toLowerCase();
        return t.normalize ? t.normalize("NFD").replace(/[̀-ͯ]/g, "") : t;
    }
    function toast(msg, type) {
        try { if (window.VCT && window.VCT.Toast && window.VCT.Toast.show) { window.VCT.Toast.show(msg, type || "warning"); return; } } catch (e) { /* noop */ }
        if (window.console) console.warn("[VCTDataGrid] " + msg);
    }
    /* Combo propio de la plataforma (VCT.Select de vct-main.js) sobre un <select> nativo: el nativo
       sigue siendo la fuente de verdad (value + evento change). Si ya tenia combo, se rehace. */
    function enhanceSelect(sel) {
        if (!sel || sel.getAttribute("data-vct-native") === "true") return;
        if (!(window.VCT && VCT.Select && typeof VCT.Select.build === "function")) return;
        sel.classList.add("vct-select");
        var old = sel.nextElementSibling;
        if (old && old.classList.contains("vct-custom-select")) old.parentNode.removeChild(old);
        sel.removeAttribute("data-vct-select-ready");
        VCT.Select.build(sel);
    }
    function syncSelect(sel) {
        if (!sel || !(window.VCT && VCT.Select && typeof VCT.Select.sync === "function")) return;
        var w = sel.nextElementSibling;
        if (w && w.classList.contains("vct-custom-select")) VCT.Select.sync(sel, w);
    }

    function isTrue(v) { return v === true || v === "1" || String(v).toLowerCase() === "true" || String(v).toUpperCase() === "SI"; }
    function debounce(fn, wait) {
        var t;
        return function () { var a = arguments, c = this; clearTimeout(t); t = setTimeout(function () { fn.apply(c, a); }, wait); };
    }
    function isMobile() { return window.matchMedia && window.matchMedia(MOBILE_MQ).matches; }

    /* Numero es-AR (1.234,56) / punto decimal simple; null si no es numero. */
    function parseNum(text) {
        var t = clean(text).replace(/[%$\s]/g, "");
        if (!t) return null;
        if (/^-?\d{1,3}(\.\d{3})+(,\d+)?$/.test(t)) return parseFloat(t.replace(/\./g, "").replace(",", "."));
        if (/^-?\d+,\d+$/.test(t)) return parseFloat(t.replace(",", "."));
        if (/^-?\d+(\.\d+)?$/.test(t)) return parseFloat(t);
        return null;
    }
    function parseDate(text) {
        var t = clean(text), m;
        if ((m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$/.exec(t)))
            return new Date(+m[3], +m[2] - 1, +m[1], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0)).getTime();
        if ((m = /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/.exec(t)))
            return new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0)).getTime();
        return null;
    }
    function sortKind(raw) {
        var t = String(raw || "").toLowerCase();
        if (/^(number|money|decimal|percent|integer)$/.test(t)) return "number";
        if (/^(date|datetime)$/.test(t)) return "date";
        return "text";
    }
    var collator = (typeof Intl !== "undefined" && Intl.Collator) ? new Intl.Collator("es", { numeric: true, sensitivity: "base" }) : null;
    function compareText(a, b) { return collator ? collator.compare(a, b) : (a < b ? -1 : (a > b ? 1 : 0)); }

    function cellText(cell) {
        if (!cell) return "";
        var clone = cell.cloneNode(true);
        var junk = clone.querySelectorAll(".vct-table-cell-expand, .vctdg-more, .vctdg-sort, .vctdg-resizer, script, style");
        for (var i = 0; i < junk.length; i++) junk[i].parentNode.removeChild(junk[i]);
        return clean(clone.textContent);
    }

    /* Texto para exportar: si la celda es solo iconos/botones (sin texto), usa sus
       title / aria-label / data-vct-tooltip -> las columnas de iconos no salen vacias. */
    function exportText(cell) {
        var text = cellText(cell);
        if (text) return text;
        var labelled = cell.querySelectorAll("[title],[aria-label],[data-vct-tooltip]");
        var parts = [];
        for (var i = 0; i < labelled.length; i++) {
            var l = clean(labelled[i].getAttribute("title") || labelled[i].getAttribute("aria-label") || labelled[i].getAttribute("data-vct-tooltip"));
            if (l && parts.indexOf(l) < 0) parts.push(l);
        }
        return parts.join(", ");
    }

    /* ------------------------------------------------------------------
       Celdas dinamicas (modo configuracion)
       Cada columna = lista de "partes" combinables en cualquier orden:
         { text: "..." }                              texto (escapado)
         { badge: tone | {map:{VALOR:tone}, text} }   badge opcional
         { icon: "edit", title, command, target, attrs:{...}, tone, show:fn(row) }
         { icons: [ {icon,...}, {icon,...} ] }        varios iconos juntos
         { html: "<...>" }                            HTML libre
       Una parte puede ser funcion (row) => parte | [partes] | null.
       Si la parte no aplica (show:false / null) simplemente no se dibuja.
       ------------------------------------------------------------------ */
    function iconHtml(def) {
        var attrs = "";
        if (def.command) attrs += ' data-vct-command="' + esc(def.command) + '"';
        if (def.target) attrs += ' data-vct-target="' + esc(def.target) + '"';
        if (def.attrs) Object.keys(def.attrs).forEach(function (k) { attrs += " " + esc(k) + '="' + esc(def.attrs[k]) + '"'; });
        var glyph = def.svg ? def.svg : '<span data-vct-icon="' + esc(def.icon) + '"></span>';
        var label = def.title ? ' title="' + esc(def.title) + '" aria-label="' + esc(def.title) + '"' : "";
        var tone = def.tone ? " is-" + esc(def.tone) : "";
        return '<button type="button" class="vctdg-icon-btn' + tone + '"' + label + attrs + ">" + glyph + "</button>";
    }

    function badgeHtml(text, tone) {
        return '<span class="vctdg-badge is-' + esc(tone || "neutral") + '">' + esc(text) + "</span>";
    }

    function partsHtml(parts, row, value) {
        var out = [], icons = [];
        function flush() { if (icons.length) { out.push('<span class="vctdg-icons">' + icons.join("") + "</span>"); icons = []; } }
        (function walk(list) {
            list.forEach(function (part) {
                if (typeof part === "function") part = part(row, value);
                if (part === null || part === undefined || part === false) return;
                if (Array.isArray(part)) { walk(part); return; }
                if (typeof part === "string") { flush(); out.push(esc(part)); return; }
                if (part.show && !part.show(row, value)) return;
                if (part.icon || part.svg) { icons.push(iconHtml(part)); return; }
                if (part.icons) { part.icons.forEach(function (d) { if (!d.show || d.show(row, value)) icons.push(iconHtml(d)); }); return; }
                flush();
                if (part.badge !== undefined) {
                    var b = part.badge, tone = b, text = part.text !== undefined ? part.text : value;
                    if (b && typeof b === "object") {
                        text = b.text !== undefined ? b.text : text;
                        tone = (b.map && b.map[String(text).toUpperCase()]) || (b.map && b.map[text]) || b["default"] || "neutral";
                    }
                    if (text !== "" && text !== null && text !== undefined) out.push(badgeHtml(text, tone));
                } else if (part.html !== undefined) out.push(part.html);
                else if (part.text !== undefined) out.push(esc(part.text));
            });
        })(Array.isArray(parts) ? parts : [parts]);
        flush();
        return out.join(" ");
    }

    function cellValue(col, row) {
        var v = col.get ? col.get(row) : row[col.key];
        return v === null || v === undefined ? "" : v;
    }

    /* Crea una grilla completa a partir de configuracion y la inicializa.
       config = { id,title,subtitle,pageSize,unit,chartsId, columns:[{key,title,type,sortable,align,className,
                  exportIgnore,parts|render,exportValue,sortValue}], rows:[{...}], filters:[{key,label,options:[]}],
                  actions: "<html>", rowFilters: fn(row)->{estado:'ACTIVO'} } */
    function create(target, config) {
        var host = document.createElement("div");
        host.setAttribute("data-vct-dg", "");
        host.setAttribute("data-vct-dg-id", config.id || ("dg_" + (++seq)));
        if (config.title) host.setAttribute("data-vct-dg-title", config.title);
        if (config.subtitle) host.setAttribute("data-vct-dg-subtitle", config.subtitle);
        if (config.pageSize) host.setAttribute("data-vct-dg-page-size", config.pageSize);
        if (config.unit) host.setAttribute("data-vct-dg-unit", config.unit);
        if (config.chartsId) host.setAttribute("data-vct-dg-charts", config.chartsId);
        if (config.layout) host.setAttribute("data-vct-dg-layout", config.layout);
        if (config.resizable) host.setAttribute("data-vct-dg-resizable", "true");

        var html = "";
        if (config.filters && config.filters.length) {
            html += '<div data-vct-dg-slot="filters">' + config.filters.map(function (f) {
                return '<select class="vctdg-select" data-vct-dg-filter="' + esc(f.key) + '" aria-label="' + esc(f.label || f.key) + '"><option value="">' + esc(f.label || "Todos") + "</option>" +
                    (f.options || []).map(function (o) { var v = typeof o === "object" ? o.value : o, l = typeof o === "object" ? o.label : o; return '<option value="' + esc(v) + '">' + esc(l) + "</option>"; }).join("") + "</select>";
            }).join("") + "</div>";
        }
        if (config.actions) html += '<div data-vct-dg-slot="actions">' + config.actions + "</div>";

        var cols = config.columns || [];
        html += '<table><thead><tr>' + cols.map(function (c) {
            return "<th" + (c.sortable !== false && !c.exportIgnore && !c.noSort ? ' data-vct-sortable="true" data-vct-sort-type="' + esc(c.type || "text") + '"' : "") +
                (c.exportIgnore ? ' data-vct-export-ignore="true"' : "") +
                (c.width ? ' data-vct-width="' + esc(c.width) + '"' : "") +
                (c.minWidth ? ' data-vct-min-width="' + esc(c.minWidth) + '"' : "") +
                (c.maxWidth ? ' data-vct-max-width="' + esc(c.maxWidth) + '"' : "") +
                (c.truncate ? ' data-vct-truncate="' + (c.truncate === true ? 2 : esc(c.truncate)) + '"' : "") +
                (c.align ? ' style="text-align:' + esc(c.align) + '"' : "") + ">" + esc(c.title) + "</th>";
        }).join("") + "</tr></thead><tbody>" + (config.rows || []).map(function (row) {
            var fa = config.rowFilters ? config.rowFilters(row) : {};
            var attrs = Object.keys(fa || {}).map(function (k) { return " data-vct-filter-" + esc(k) + '="' + esc(fa[k]) + '"'; }).join("");
            return "<tr data-vct-row" + attrs + ">" + cols.map(function (c) {
                var value = cellValue(c, row);
                var inner = c.render ? c.render(row, value) : (c.parts ? partsHtml(c.parts, row, value) : esc(value));
                var extra = "";
                if (c.exportValue) extra += ' data-vct-export-value="' + esc(typeof c.exportValue === "function" ? c.exportValue(row, value) : value) + '"';
                if (c.sortValue || c.type === "number" || c.type === "date") extra += ' data-vct-sort-value="' + esc(c.sortValue ? c.sortValue(row, value) : value) + '"';
                return '<td data-label="' + esc(c.title) + '"' + (c.className ? ' class="' + esc(c.className) + '"' : "") + (c.align ? ' style="text-align:' + esc(c.align) + '"' : "") + extra + ">" + inner + "</td>";
            }).join("") + "</tr>";
        }).join("") + "</tbody></table>";
        host.innerHTML = html;

        target.appendChild(host);
        try { if (window.VCT && window.VCT.Icon && window.VCT.Icon.init) window.VCT.Icon.init(host); } catch (e) { /* noop */ }
        initOne(host);
        try { if (window.VCT && window.VCT.Icon && window.VCT.Icon.init) window.VCT.Icon.init(host); } catch (e) { /* noop */ }
        return registry[host.getAttribute("data-vct-dg-id")];
    }

    /* ------------------------------------------------------------------
       Construccion
       ------------------------------------------------------------------ */
    function childSlot(host, name) {
        for (var i = 0; i < host.children.length; i++)
            if (host.children[i].getAttribute("data-vct-dg-slot") === name) return host.children[i];
        return null;
    }

    function build(host) {
        var table = host.querySelector("table");
        var tbody = table && table.tBodies[0];
        if (!table || !tbody) return null;

        var id = host.getAttribute("data-vct-dg-id") || host.getAttribute("data-vct-grid-id") || ("dg_" + (++seq));
        var chartsId = host.getAttribute("data-vct-dg-charts") || "";
        var unit = host.getAttribute("data-vct-dg-unit") || "registro(s)";
        var placeholder = host.getAttribute("data-vct-dg-search-placeholder") || "Buscar...";
        var sizes = (host.getAttribute("data-vct-dg-page-sizes") || "").split(",").map(function (s) { return parseInt(s, 10); }).filter(function (n) { return n > 0; });
        if (!sizes.length) sizes = PAGE_SIZES.slice();
        var baseSize = parseInt(host.getAttribute("data-vct-dg-page-size"), 10) || 10;
        if (sizes.indexOf(baseSize) < 0) { sizes.push(baseSize); sizes.sort(function (a, b) { return a - b; }); }

        var slotFilters = childSlot(host, "filters");
        var slotActions = childSlot(host, "actions");

        host.classList.add("vctdg");
        if (host.getAttribute("data-vct-dg-density") === "compact") host.classList.add("is-compact");
        host.setAttribute("data-vct-dg-ready", "1");

        /* tabla propia (sin la clase legacy .vct-table, que arrastra CSS viejo) */
        table.className = "vctdg-table";
        table.removeAttribute("data-vct-grid-table");
        var wrap = document.createElement("div");
        wrap.className = "vctdg-wrap";
        table.parentNode.insertBefore(wrap, table);
        wrap.appendChild(table);
        /* se desarma un .vct-table-wrap legacy que quede vacio alrededor */
        var legacy = wrap.parentNode;
        if (legacy && legacy !== host && legacy.classList.contains("vct-table-wrap")) {
            legacy.parentNode.insertBefore(wrap, legacy);
            legacy.parentNode.removeChild(legacy);
        }

        var toolbar = document.createElement("div");
        toolbar.className = "vctdg-toolbar";
        toolbar.innerHTML =
            '<div class="vctdg-filters"></div>' +
            '<div class="vctdg-tools">' +
                '<span class="vctdg-meta" aria-live="polite"></span>' +
                '<button type="button" class="vctdg-btn vctdg-btn-excel" data-vctdg-export="excel" title="Exportar a Excel">' + ICON.excel + "<span>Excel</span></button>" +
                '<button type="button" class="vctdg-btn vctdg-btn-pdf" data-vctdg-export="pdf" title="Exportar a PDF">' + ICON.pdf + "<span>PDF</span></button>" +
                (chartsId ? '<button type="button" class="vctdg-btn vctdg-btn-charts" data-vct-command="open-modal" data-vct-target="' + esc(chartsId) + '" title="Ver gráficos">' + ICON.chart + "<span>Gráficos</span></button>" : "") +
            "</div>";
        var filtersBox = toolbar.querySelector(".vctdg-filters");
        var toolsBox = toolbar.querySelector(".vctdg-tools");
        if (slotFilters) { while (slotFilters.firstChild) filtersBox.appendChild(slotFilters.firstChild); slotFilters.parentNode.removeChild(slotFilters); }

        var search = document.createElement("label");
        search.className = "vctdg-search";
        search.innerHTML = ICON.search + '<input type="search" autocomplete="off" aria-label="Buscar en la tabla" placeholder="' + esc(placeholder) + '">';
        filtersBox.insertBefore(search, filtersBox.firstChild);   /* el buscador SIEMPRE primero, a la izquierda */

        var sortSel = document.createElement("select");
        sortSel.className = "vctdg-select vctdg-sortsel";
        sortSel.setAttribute("aria-label", "Ordenar por");
        filtersBox.appendChild(sortSel);

        if (slotActions) { while (slotActions.firstChild) toolsBox.appendChild(slotActions.firstChild); slotActions.parentNode.removeChild(slotActions); }

        var footer = document.createElement("div");
        footer.className = "vctdg-footer";
        footer.innerHTML =
            '<div class="vctdg-info" data-vctdg-info></div>' +
            '<nav class="vctdg-pager" aria-label="Paginación"></nav>' +
            '<label class="vctdg-size"><span>Registros por página:</span><select class="vctdg-select" aria-label="Registros por página">' +
                sizes.concat(isMobile() && sizes.indexOf(5) < 0 ? [5] : []).sort(function (a, b) { return a - b; })
                    .map(function (n) { return '<option value="' + n + '">' + n + "</option>"; }).join("") +
            "</select></label>";

        host.insertBefore(toolbar, wrap);
        host.appendChild(footer);

        /* filtros y cantidad por pagina: todos con el mismo combo (alto, hover y seleccion estandar) */
        Array.prototype.forEach.call(filtersBox.querySelectorAll("select"), function (sel) {
            if (sel === sortSel || sel.getAttribute("data-vct-select-ready") === "1") return;
            enhanceSelect(sel);
        });
        enhanceSelect(footer.querySelector(".vctdg-size select"));

        /* cabeceras ordenables */
        var headRow = table.tHead && table.tHead.rows[table.tHead.rows.length - 1];
        var headers = headRow ? Array.prototype.slice.call(headRow.cells) : [];
        var state = {
            id: id, host: host, wrap: wrap, table: table, tbody: tbody, headers: headers,
            title: host.getAttribute("data-vct-dg-title") || "",
            subtitle: host.getAttribute("data-vct-dg-subtitle") || "",
            unit: unit, chartsId: chartsId, sizes: sizes, cols: [],
            rows: [], ordered: [], search: "", filters: [],
            sortIndex: -1, sortDir: "", page: parseInt(host.getAttribute("data-vct-dg-page"), 10) || 1,
            pageSize: isMobile() ? 5 : baseSize, baseSize: baseSize, userSize: false,
            el: {
                toolbar: toolbar, meta: toolbar.querySelector(".vctdg-meta"), searchInput: search.querySelector("input"),
                info: footer.querySelector("[data-vctdg-info]"), pager: footer.querySelector(".vctdg-pager"),
                size: footer.querySelector(".vctdg-size select"), sortSel: sortSel,
                btnExcel: toolsBox.querySelector('[data-vctdg-export="excel"]'), btnPdf: toolsBox.querySelector('[data-vctdg-export="pdf"]')
            }
        };

        sortSel.innerHTML = '<option value="">Ordenar por…</option>';
        headers.forEach(function (th, index) {
            if (!isTrue(th.getAttribute("data-vct-sortable"))) return;
            var legacyIcons = th.querySelectorAll(".vct-sort-icon");
            for (var i = 0; i < legacyIcons.length; i++) legacyIcons[i].parentNode.removeChild(legacyIcons[i]);
            var label = cellText(th);
            var icon = document.createElement("span");
            icon.className = "vctdg-sort";
            icon.innerHTML = ICON.sort;
            th.appendChild(icon);
            th.classList.add("vctdg-sortable");
            th.tabIndex = 0;
            th.setAttribute("aria-sort", "none");
            th.__dgKind = sortKind(th.getAttribute("data-vct-sort-type"));
            sortSel.insertAdjacentHTML("beforeend",
                '<option value="' + index + ':asc">' + esc(label) + " ↑</option>" +
                '<option value="' + index + ':desc">' + esc(label) + " ↓</option>");
        });
        if (sortSel.options.length <= 1) sortSel.parentNode.removeChild(sortSel);

        applyColumns(state);

        registry[id] = state;
        return state;
    }

    /* ------------------------------------------------------------------
       Columnas: anchos, redimensionado opcional, "ver mas / ver menos"
       Todo por atributos del <th> (o por config en modo create()):
         data-vct-width="120" | "120px" | "15%" | "8rem"   ancho (numero = px)
         data-vct-min-width / data-vct-max-width           limites
         data-vct-truncate="2"                             recorta a N lineas (default 2) con toggle
       Del host:
         data-vct-dg-layout="fixed|auto"   (default auto: los anchos son sugerencia)
         data-vct-dg-resizable="true"      handles para arrastrar el ancho de cada columna
       ------------------------------------------------------------------ */
    function cssSize(raw) {
        var t = clean(raw);
        if (!t) return "";
        return /^\d+(\.\d+)?$/.test(t) ? t + "px" : t;
    }

    function applyColumns(state) {
        var any = false;
        var colgroup = document.createElement("colgroup");
        state.headers.forEach(function (th) {
            var col = document.createElement("col");
            var w = cssSize(th.getAttribute("data-vct-width")), mn = cssSize(th.getAttribute("data-vct-min-width")), mx = cssSize(th.getAttribute("data-vct-max-width"));
            if (w) { col.style.width = w; any = true; }
            if (mn) th.style.minWidth = mn;
            if (mx) th.style.maxWidth = mx;
            colgroup.appendChild(col);
            state.cols.push(col);
            if (th.hasAttribute("data-vct-truncate")) {
                var n = parseInt(th.getAttribute("data-vct-truncate"), 10);
                th.__dgLines = n > 0 ? n : 2;
            }
        });
        if (state.headers.length) state.table.insertBefore(colgroup, state.table.firstChild);
        if (state.host.getAttribute("data-vct-dg-layout") === "fixed") state.table.classList.add("is-fixed");

        if (isTrue(state.host.getAttribute("data-vct-dg-resizable"))) {
            state.headers.forEach(function (th, index) {
                if (index === state.headers.length - 1) return;
                var handle = document.createElement("span");
                handle.className = "vctdg-resizer";
                handle.setAttribute("aria-hidden", "true");
                handle.addEventListener("click", function (e) { e.stopPropagation(); });
                handle.addEventListener("mousedown", function (e) { startResize(state, index, e); });
                handle.addEventListener("touchstart", function (e) { startResize(state, index, e); }, { passive: false });
                th.appendChild(handle);
            });
        }
        return any;
    }

    function startResize(state, index, event) {
        event.preventDefault();
        event.stopPropagation();
        var touch = event.touches ? event.touches[0] : event;
        var startX = touch.clientX;
        /* se congela el ancho actual de TODAS las columnas para que nada "salte" */
        state.headers.forEach(function (th, i) { state.cols[i].style.width = th.getBoundingClientRect().width + "px"; });
        state.table.classList.add("is-fixed", "is-resizing");
        var startW = state.headers[index].getBoundingClientRect().width;
        var minW = parseFloat(state.headers[index].style.minWidth) || 48;
        function move(e) {
            var p = e.touches ? e.touches[0] : e;
            state.cols[index].style.width = Math.max(minW, startW + (p.clientX - startX)) + "px";
        }
        function up() {
            document.removeEventListener("mousemove", move);
            document.removeEventListener("mouseup", up);
            document.removeEventListener("touchmove", move);
            document.removeEventListener("touchend", up);
            state.table.classList.remove("is-resizing");
            updateClamps(state);
        }
        document.addEventListener("mousemove", move);
        document.addEventListener("mouseup", up);
        document.addEventListener("touchmove", move, { passive: false });
        document.addEventListener("touchend", up);
    }

    /* Envuelve el contenido de las celdas de columnas "truncate" (mueve los nodos: iconos/badges
       quedan intactos). Se hace POR FILA y solo al montarla en pantalla (la fila esta fuera del
       DOM en ese momento): decorar las miles de filas de golpe generaba decenas de miles de
       cambios de DOM y los observadores globales de vct-main.js los procesan uno por uno. */
    function decorateRow(state, row) {
        if (row.__dgDecorated) return;
        row.__dgDecorated = true;
        state.headers.forEach(function (th, i) {
            if (!th.__dgLines) return;
            var cell = row.cells[i];
            if (!cell || cell.__dgClamp) return;
            var box = document.createElement("div");
            box.className = "vctdg-clamp";
            box.style.setProperty("--vctdg-lines", th.__dgLines);
            while (cell.firstChild) box.appendChild(cell.firstChild);
            var more = document.createElement("button");
            more.type = "button";
            more.className = "vctdg-more";
            more.setAttribute("aria-expanded", "false");
            more.setAttribute("aria-label", "Ver más");
            more.title = "Ver más";
            more.innerHTML = '<span class="vctdg-more-t">Ver más</span>' + ICON.chev;
            cell.appendChild(box);
            cell.appendChild(more);
            cell.classList.add("vctdg-truncatable");
            cell.__dgClamp = box;
        });
    }

    function updateClamps(state) {
        var run = function () {
            (state.mounted || []).forEach(function (row) {
                for (var i = 0; i < row.cells.length; i++) {
                    var cell = row.cells[i], box = cell.__dgClamp;
                    if (!box) continue;
                    var expanded = cell.classList.contains("is-expanded");
                    cell.classList.toggle("has-overflow", expanded || box.scrollHeight > box.clientHeight + 1);
                }
            });
        };
        /* setTimeout y no rAF: rAF se pausa en pestañas no visibles y la medicion nunca corre */
        setTimeout(run, 0);
    }

    function toggleClamp(more) {
        var cell = more.closest("td");
        if (!cell) return;
        var open = cell.classList.toggle("is-expanded");
        more.setAttribute("aria-expanded", open ? "true" : "false");
        var label = open ? "Ver menos" : "Ver más";
        more.setAttribute("aria-label", label);
        more.title = label;
        more.querySelector(".vctdg-more-t").textContent = label;
    }

    /* ------------------------------------------------------------------
       Datos
       ------------------------------------------------------------------ */
    function readRows(state) {
        state.rows = Array.prototype.slice.call(state.tbody.querySelectorAll(":scope > tr[data-vct-row]"));
        state.rows.forEach(function (row, i) {
            row.__dgHay = norm(row.getAttribute("data-vct-search") || row.textContent);
            row.__dgOrder = i;
        });
        state.ordered = state.rows.slice();
        state.mounted = state.rows.slice();
        state.filters = Array.prototype.slice.call(state.host.querySelectorAll("[data-vct-dg-filter],[data-vct-grid-filter]"));
    }

    function rowMatches(state, row) {
        if (state.search) {
            for (var i = 0; i < state.searchTerms.length; i++)
                if (row.__dgHay.indexOf(state.searchTerms[i]) < 0) return false;
        }
        for (var f = 0; f < state.filters.length; f++) {
            var sel = state.filters[f];
            var value = String(sel.value || "").toLowerCase();
            if (!value) continue;
            var key = sel.getAttribute("data-vct-dg-filter") || sel.getAttribute("data-vct-grid-filter");
            if (String(row.getAttribute("data-vct-filter-" + key) || "").toLowerCase() !== value) return false;
        }
        return true;
    }

    function sortValue(row, index, kind) {
        var cell = row.cells[index];
        if (!cell) return null;
        var raw = cell.hasAttribute("data-vct-sort-value") ? cell.getAttribute("data-vct-sort-value")
            : (cell.__dgClamp ? cellText(cell) : cell.textContent);
        raw = clean(raw);
        if (raw === "") return null;
        if (kind === "number") return parseNum(raw);
        if (kind === "date") return parseDate(raw);
        return raw;
    }

    function applySort(state) {
        if (state.sortIndex < 0) {
            state.ordered = state.rows.slice().sort(function (a, b) { return a.__dgOrder - b.__dgOrder; });
        } else {
            var kind = state.headers[state.sortIndex].__dgKind || "text";
            var dir = state.sortDir === "desc" ? -1 : 1;
            var keyed = state.rows.map(function (row) { return { row: row, key: sortValue(row, state.sortIndex, kind) }; });
            keyed.sort(function (a, b) {
                var an = a.key === null || a.key === undefined, bn = b.key === null || b.key === undefined;
                if (an || bn) return an && bn ? a.row.__dgOrder - b.row.__dgOrder : (an ? 1 : -1);
                var c = kind === "text" ? compareText(a.key, b.key) : (a.key < b.key ? -1 : (a.key > b.key ? 1 : 0));
                return c !== 0 ? c * dir : a.row.__dgOrder - b.row.__dgOrder;
            });
            state.ordered = keyed.map(function (k) { return k.row; });
        }
        state.headers.forEach(function (th, i) {
            if (!th.classList.contains("vctdg-sortable")) return;
            var active = i === state.sortIndex;
            th.classList.toggle("is-asc", active && state.sortDir === "asc");
            th.classList.toggle("is-desc", active && state.sortDir === "desc");
            th.setAttribute("aria-sort", active ? (state.sortDir === "asc" ? "ascending" : "descending") : "none");
        });
        if (state.el.sortSel) state.el.sortSel.value = state.sortIndex < 0 ? "" : state.sortIndex + ":" + state.sortDir;
    }

    /* ------------------------------------------------------------------
       Render
       ------------------------------------------------------------------ */
    function pagerHtml(page, pages) {
        function btn(target, icon, label, disabled, active) {
            return '<button type="button" class="vctdg-page' + (active ? " is-active" : "") + '" data-vctdg-page="' + target + '" aria-label="' + label + '"' +
                (disabled ? " disabled" : "") + (active ? ' aria-current="page"' : "") + ">" + icon + "</button>";
        }
        var start = Math.max(1, page - 2), end = Math.min(pages, start + 4);
        start = Math.max(1, end - 4);
        var html = btn(1, ICON.first, "Primera página", page === 1) + btn(page - 1, ICON.prev, "Página anterior", page === 1);
        for (var p = start; p <= end; p++) html += btn(p, String(p), "Página " + p, false, p === page);
        return html + btn(page + 1, ICON.next, "Página siguiente", page === pages) + btn(pages, ICON.last, "Última página", page === pages);
    }

    /* Monta en el <tbody> SOLO las filas de la pagina actual; el resto vive en memoria
       (state.rows). El .vctdg-wrap se saca del documento mientras se cambian las filas y se
       vuelve a poner: asi son 2 cambios de DOM en vez de cientos. Cada nodo agregado al
       documento dispara ~12 observadores de vct-main.js (uno hace un querySelectorAll de todo
       el documento: ~5 ms por nodo en una pantalla de 40k nodos), y con miles de filas eso eran
       decenas de segundos de pantalla trabada. */
    function mountRows(state, pageRows, showEmpty) {
        var wrap = state.wrap, parent = wrap.parentNode, marker = null;
        if (parent) { marker = document.createComment("vctdg"); parent.replaceChild(marker, wrap); }
        try {
            (state.mounted || []).forEach(function (row) { if (row.parentNode === state.tbody) state.tbody.removeChild(row); });
            var empty = state.tbody.querySelector(":scope > tr.vctdg-empty");
            if (empty) state.tbody.removeChild(empty);
            var frag = document.createDocumentFragment();
            pageRows.forEach(function (row) { decorateRow(state, row); frag.appendChild(row); });
            state.tbody.insertBefore(frag, state.tbody.firstChild);
            if (showEmpty) {
                empty = document.createElement("tr");
                empty.className = "vctdg-empty";
                empty.innerHTML = '<td colspan="' + Math.max(1, state.headers.length) + '">' + esc(state.host.getAttribute("data-vct-dg-empty") || "No hay registros que coincidan con la búsqueda.") + "</td>";
                state.tbody.appendChild(empty);
            }
        } finally {
            if (marker) parent.replaceChild(wrap, marker);
        }
        state.mounted = pageRows;
    }

    function render(state) {
        state.searchTerms = norm(state.search).split(/\s+/).filter(Boolean);
        var filtered = state.ordered.filter(function (row) { return rowMatches(state, row); });
        var total = state.rows.length;
        var pages = Math.max(1, Math.ceil(filtered.length / state.pageSize));
        if (state.page > pages) state.page = pages;
        if (state.page < 1) state.page = 1;
        var from = filtered.length ? (state.page - 1) * state.pageSize : 0;
        var to = Math.min(filtered.length, from + state.pageSize);

        mountRows(state, filtered.slice(from, to), total > 0 && filtered.length === 0);

        state.el.meta.textContent = filtered.length + " " + state.unit;
        state.el.info.textContent = "Mostrando " + (filtered.length ? from + 1 : 0) + " a " + to + " de " + filtered.length + " registro(s)";
        state.el.pager.innerHTML = pages > 1 ? pagerHtml(state.page, pages) : "";
        if (state.el.size.value !== String(state.pageSize)) { state.el.size.value = String(state.pageSize); syncSelect(state.el.size); }
        state.el.btnExcel.disabled = state.el.btnPdf.disabled = total === 0;

        state.filtered = filtered;
        updateClamps(state);
        state.host.dispatchEvent(new CustomEvent("vctdg:render", { bubbles: true, detail: { id: state.id, total: total, filtered: filtered.length, page: state.page, pages: pages } }));
    }

    /* ------------------------------------------------------------------
       Export
       ------------------------------------------------------------------ */
    function exportColumns(state) {
        var cols = [];
        state.headers.forEach(function (th, i) {
            if (isTrue(th.getAttribute("data-vct-export-ignore"))) return;
            var first = state.rows[0] && state.rows[0].cells[i];
            if (first && isTrue(first.getAttribute("data-vct-export-ignore"))) return;
            cols.push({ index: i, title: cellText(th) });
        });
        return cols;
    }

    function exportSpec(state) {
        var cols = exportColumns(state);
        var rows = (state.filtered || state.ordered).map(function (row) {
            return cols.map(function (c) {
                var cell = row.cells[c.index];
                if (!cell) return "";
                return cell.hasAttribute("data-vct-export-value") ? cell.getAttribute("data-vct-export-value") : exportText(cell);
            });
        });
        var title = state.title;
        if (!title) {
            var h = state.host.closest(".vct-card, [data-vct-page]");
            var t = h && h.querySelector(".vct-card-title, .vct-page-title, h1, h2");
            title = t ? clean(t.textContent) : (document.title || "Exportación");
        }
        return { title: title, subtitle: state.subtitle, filename: title, columns: cols.map(function (c) { return { title: c.title }; }), rows: rows };
    }

    /* Graficos del modal asociado -> imagenes (se clonan fuera de pantalla porque el modal cerrado no se puede rasterizar). */
    function chartImages(state) {
        if (!state.chartsId || !window.VCTExport || !window.VCTExport.rasterize) return Promise.resolve([]);
        var modal = document.getElementById(state.chartsId) || document.querySelector('[data-vct-component="modal"][data-vct-id="' + state.chartsId + '"]');
        if (!modal) return Promise.resolve([]);
        var charts = modal.querySelectorAll(".vct-report-chart");
        if (!charts.length) return Promise.resolve([]);

        var stage = document.createElement("div");
        stage.setAttribute("aria-hidden", "true");
        stage.style.cssText = "position:fixed;left:-10000px;top:0;width:380px;background:#fff;pointer-events:none;";
        document.body.appendChild(stage);

        var jobs = Array.prototype.map.call(charts, function (chart) {
            if (chart.style.display === "none") return Promise.resolve(null);
            var clone = chart.cloneNode(true);
            stage.appendChild(clone);
            var titleEl = chart.querySelector(".vct-report-chart-title");
            return window.VCTExport.rasterize(clone).then(function (dataUrl) {
                return dataUrl ? { dataUrl: dataUrl, caption: titleEl ? clean(titleEl.textContent) : "" } : null;
            }).catch(function () { return null; });
        });
        return Promise.all(jobs).then(function (list) {
            if (stage.parentNode) stage.parentNode.removeChild(stage);
            return list.filter(Boolean);
        });
    }

    function runExport(state, kind) {
        if (!window.VCTExport) { toast("Falta cargar vct-export.js: no se puede exportar.", "warning"); return; }
        var spec = exportSpec(state);
        var btn = kind === "pdf" ? state.el.btnPdf : state.el.btnExcel;
        btn.classList.add("is-busy");
        var job = kind === "pdf"
            ? chartImages(state).then(function (images) { spec.images = images; return window.VCTExport.pdf(spec); })
            : window.VCTExport.excel(spec);
        Promise.resolve(job).catch(function (e) { toast("No se pudo exportar: " + (e && e.message ? e.message : e), "warning"); })
            .then(function () { btn.classList.remove("is-busy"); });
    }

    /* ------------------------------------------------------------------
       Eventos
       ------------------------------------------------------------------ */
    function sortBy(state, index) {
        if (state.sortIndex === index) state.sortDir = state.sortDir === "asc" ? "desc" : "asc";
        else { state.sortIndex = index; state.sortDir = "asc"; }
        state.page = 1;
        applySort(state);
        render(state);
    }

    function wire(state) {
        var debounced = debounce(function () { state.search = state.el.searchInput.value; state.page = 1; render(state); }, 300);
        state.el.searchInput.addEventListener("input", debounced);
        state.el.searchInput.addEventListener("keydown", function (e) { if (e.key === "Enter") e.preventDefault(); });

        state.host.addEventListener("change", function (e) {
            var t = e.target;
            if (t === state.el.size) {
                var n = parseInt(t.value, 10);
                state.pageSize = n > 0 ? n : state.baseSize;
                state.userSize = true;
                state.page = 1;
                render(state);
            } else if (t === state.el.sortSel) {
                if (!t.value) { state.sortIndex = -1; state.sortDir = ""; }
                else { var p = t.value.split(":"); state.sortIndex = parseInt(p[0], 10); state.sortDir = p[1]; }
                state.page = 1;
                applySort(state);
                render(state);
            } else if (state.filters.indexOf(t) >= 0) {
                state.page = 1;
                render(state);
            }
        });

        state.host.addEventListener("click", function (e) {
            var pageBtn = e.target.closest("[data-vctdg-page]");
            if (pageBtn && state.host.contains(pageBtn) && !pageBtn.disabled) {
                state.page = parseInt(pageBtn.getAttribute("data-vctdg-page"), 10) || 1;
                render(state);
                return;
            }
            var more = e.target.closest(".vctdg-more");
            if (more && state.host.contains(more)) { toggleClamp(more); return; }
            var exp = e.target.closest("[data-vctdg-export]");
            if (exp && state.host.contains(exp)) {
                e.preventDefault();
                if (!exp.disabled && !exp.classList.contains("is-busy")) runExport(state, exp.getAttribute("data-vctdg-export"));
                return;
            }
            var th = e.target.closest("th.vctdg-sortable");
            if (th && state.host.contains(th)) sortBy(state, state.headers.indexOf(th));
        });

        state.host.addEventListener("keydown", function (e) {
            if (e.key !== "Enter" && e.key !== " ") return;
            var th = e.target.closest && e.target.closest("th.vctdg-sortable");
            if (th && state.host.contains(th)) { e.preventDefault(); sortBy(state, state.headers.indexOf(th)); }
        });

        /* Una grilla dentro de un panel oculto (display:none) mide 0: se re-mide cuando
           cambia de tamaño o pasa a ser visible (ej. cambiar de pestaña en Reportes). */
        if (window.ResizeObserver) {
            var lastW = 0;
            new window.ResizeObserver(debounce(function () {
                var w = state.host.offsetWidth;
                if (!w) { lastW = 0; return; }
                if (w !== lastW) { lastW = w; updateClamps(state); }
            }, 80)).observe(state.host);
        }

        if (window.matchMedia) {
            var mq = window.matchMedia(MOBILE_MQ);
            var onChange = function () {
                if (state.userSize) return;
                var size = mq.matches ? 5 : state.baseSize;
                if (mq.matches && !Array.prototype.some.call(state.el.size.options, function (o) { return o.value === "5"; })) {
                    state.el.size.insertAdjacentHTML("afterbegin", '<option value="5">5</option>');
                    enhanceSelect(state.el.size);
                }
                state.pageSize = size;
                state.page = 1;
                render(state);
            };
            if (mq.addEventListener) mq.addEventListener("change", onChange); else if (mq.addListener) mq.addListener(onChange);
        }
    }

    /* ------------------------------------------------------------------
       API publica + arranque
       ------------------------------------------------------------------ */
    /* Tarjeta 360 (.vct-360-box) con una sola grilla: los botones del encabezado
       (.vct-360-box-actions, p.ej. "Agregar" domicilio) pasan al toolbar, a la derecha
       de Excel/PDF, con el mismo alto. Solo existen si el SP los dibujo (permiso del perfil).
       El texto "Agregar" se unifica como "Nuevo". */
    function adoptBoxActions(state) {
        var box = state.host.closest ? state.host.closest(".vct-360-box") : null;
        if (!box) return;
        box.classList.add("vctdg-in-box");   /* linea fina bajo el titulo + espacio antes del toolbar (CSS) */
        if (box.querySelectorAll("[data-vct-dg]").length !== 1) return;
        var actions = null;
        for (var i = 0; i < box.children.length; i++) {
            if (box.children[i].classList.contains("vct-360-box-head")) { actions = box.children[i].querySelector(".vct-360-box-actions"); break; }
        }
        if (!actions || !actions.children.length) return;
        var tools = state.el.toolbar.querySelector(".vctdg-tools");
        while (actions.firstElementChild) {
            var btn = actions.firstElementChild;
            var spans = btn.querySelectorAll("span");
            for (var j = 0; j < spans.length; j++) {
                if (!spans[j].hasAttribute("data-vct-icon") && /^\s*agregar\s*$/i.test(spans[j].textContent)) spans[j].textContent = "Nuevo";
            }
            tools.appendChild(btn);
        }
        actions.hidden = true;
    }

    /* ------------------------------------------------------------------
       Menu de fila (3 puntos, siempre ultima columna). Declarativo: el SP pone
         <button class="vct-row-menu-trigger" data-vctdg-rowmenu>...</button>
         <div class="vctdg-rowmenu-items" hidden> botones (VCT_MAIN_RENDER_ACTION) </div>
       Los botones salen de PrmActions segun permisos del perfil (icono + texto).
       El motor los muestra en un menu flotante; al elegir uno se dispara el
       boton original, que atiende la plataforma (grid-action, etc.).
       ------------------------------------------------------------------ */
    var rowMenu = { el: null, trigger: null };
    function closeRowMenu() {
        if (rowMenu.el && rowMenu.el.parentNode) rowMenu.el.parentNode.removeChild(rowMenu.el);
        if (rowMenu.trigger) rowMenu.trigger.classList.remove("is-open");
        rowMenu.el = null; rowMenu.trigger = null;
    }
    function openRowMenu(btn) {
        closeRowMenu();
        var cell = btn.parentNode;
        var src = cell ? cell.querySelector(".vctdg-rowmenu-items") : null;
        if (!src || !src.children.length) return;
        var originals = Array.prototype.slice.call(src.children);
        var menu = document.createElement("div");
        menu.className = "vctdg-rowmenu";
        menu.setAttribute("role", "menu");
        originals.forEach(function (orig, i) {
            var item = document.createElement("button");
            item.type = "button";
            item.className = "vctdg-rowmenu-item";
            item.setAttribute("role", "menuitem");
            item.setAttribute("data-vctdg-idx", String(i));
            var icon = orig.querySelector("[data-vct-icon]");
            var label = orig.getAttribute("data-vct-tooltip") || cellText(orig);
            item.innerHTML = (icon ? '<span class="vctdg-rowmenu-icon" data-vct-icon="' + esc(icon.getAttribute("data-vct-icon")) + '"></span>' : "") +
                "<span>" + esc(label) + "</span>";
            menu.appendChild(item);
        });
        menu.addEventListener("click", function (e) {
            var it = e.target.closest(".vctdg-rowmenu-item");
            if (!it) return;
            e.preventDefault();
            e.stopPropagation();
            var orig = originals[parseInt(it.getAttribute("data-vctdg-idx"), 10)];
            closeRowMenu();
            if (orig) orig.click();
        });
        document.body.appendChild(menu);
        if (window.VCT && VCT.Icon && typeof VCT.Icon.init === "function") VCT.Icon.init(menu);
        var r = btn.getBoundingClientRect(), mw = menu.offsetWidth, mh = menu.offsetHeight;
        var left = Math.max(8, Math.min(r.right - mw, window.innerWidth - mw - 8));
        var top = r.bottom + 4;
        if (top + mh > window.innerHeight - 8 && r.top - mh - 4 > 8) top = r.top - mh - 4;
        menu.style.left = left + "px";
        menu.style.top = top + "px";
        btn.classList.add("is-open");
        rowMenu.el = menu; rowMenu.trigger = btn;
    }
    document.addEventListener("click", function (e) {
        var btn = e.target.closest ? e.target.closest("[data-vctdg-rowmenu]") : null;
        if (btn) {
            e.preventDefault();
            e.stopPropagation();
            if (rowMenu.trigger === btn) closeRowMenu(); else openRowMenu(btn);
            return;
        }
        if (rowMenu.el && !rowMenu.el.contains(e.target)) closeRowMenu();
    });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") closeRowMenu(); });
    window.addEventListener("resize", closeRowMenu);
    window.addEventListener("scroll", closeRowMenu, true);

    function initOne(host) {
        if (host.getAttribute("data-vct-dg-ready") === "1") return registry[host.getAttribute("data-vct-dg-id")] || null;
        ensureDatePicker(host);
        /* Todo el armado (toolbar, footer, mover filas) se hace con el host FUERA del documento:
           ver mountRows(). El host vuelve a su lugar al final (aun si algo falla). */
        var parent = host.parentNode, marker = null;
        if (parent) { marker = document.createComment("vctdg-init"); parent.replaceChild(marker, host); }
        var state = null;
        try {
            state = build(host);
            if (!state) return null;
            readRows(state);
            applySort(state);
            wire(state);
            render(state);
            return state;
        } finally {
            if (marker) parent.replaceChild(host, marker);
            if (state) adoptBoxActions(state);
        }
    }

    function init(scope) {
        scope = scope || document;
        var hosts = [];
        if (scope.matches && scope.matches(HOST_SEL)) hosts.push(scope);
        if (scope.querySelectorAll) Array.prototype.forEach.call(scope.querySelectorAll(HOST_SEL), function (h) { hosts.push(h); });
        hosts.forEach(function (h) { try { initOne(h); } catch (e) { if (window.console) console.error("[VCTDataGrid]", e); } });
    }

    /* Re-lee las filas del <tbody> (usar cuando se REEMPLAZO el contenido del tbody; las filas que
       estaban fuera de pantalla se descartan, solo se conservan las que hay en el tbody). */
    function refresh(id) {
        var state = registry[id];
        if (!state) return;
        readRows(state);
        applySort(state);
        render(state);
    }

    window.addEventListener("resize", debounce(function () {
        Object.keys(registry).forEach(function (id) { updateClamps(registry[id]); });
    }, 150));

    window.VCTDataGrid = {
        version: "1.0",
        init: init,
        create: create,
        html: {
            badge: badgeHtml,
            icon: iconHtml,
            icons: function (list) { return '<span class="vctdg-icons">' + list.map(iconHtml).join("") + "</span>"; }
        },
        get: function (id) { return registry[id] || null; },
        refresh: refresh,
        render: function (id) { if (registry[id]) render(registry[id]); }
    };

    function start() {
        init(document);
        if (window.MutationObserver) {
            var target = document.getElementById("mainContainer") || document.documentElement;
            var pending = false;
            new MutationObserver(function (mutations) {
                if (pending) return;
                for (var i = 0; i < mutations.length; i++) {
                    for (var j = 0; j < mutations[i].addedNodes.length; j++) {
                        var n = mutations[i].addedNodes[j];
                        if (n.nodeType === 1 && ((n.matches && n.matches(HOST_SEL)) || (n.querySelector && n.querySelector(HOST_SEL)))) {
                            pending = true;
                            setTimeout(function () { pending = false; init(document); }, 0);
                            return;
                        }
                    }
                }
            }).observe(target, { childList: true, subtree: true });
        }
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
    else start();
})(window, document);

/* ============================================================================
   Pestana con subopciones (v9). Bloque PROPIO: la plataforma no recarga la
   pagina al navegar, y el motor de grilla de arriba no se vuelve a ejecutar si
   ya estaba cargado (guarda VCTDataGrid). Este bloque tiene su propia guarda.
   ============================================================================ */
(function (window, document) {
    "use strict";
    if (window.VCTTabGroupReady) return;
    window.VCTTabGroupReady = true;
    function escA(v) { return String(v == null ? "" : v).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }
    /* ------------------------------------------------------------------
       v8: Pestana con subopciones ("Agenda" con flecha y menu). Declarativo:
         <button class="vctdg-tabgroup" data-vctdg-tabgroup data-vctdg-tabs="agenda,dias">
             <span data-vct-icon="calendar"></span><span>Agenda</span>
             <span class="vctdg-tabgroup-chev" data-vct-icon="chevron-down"></span></button>
         <div class="vctdg-tabgroup-items" hidden>
             <button data-vctdg-subtab="agenda">...</button>
             <button data-vctdg-subtab="dias">... <small>12</small></button></div>
       El boton no tiene data-vct-tab (no cambia de panel por si mismo); cada
       subopcion activa su panel con VCT.Tabs.activate. El boton queda marcado
       (is-active) mientras el panel activo sea uno de los suyos.
       ------------------------------------------------------------------ */
    var tabMenu = { el: null, trigger: null };
    function tabRoot(btn) { return btn.closest("[data-vct-tabs]") || btn.closest("[data-vct-module]"); }
    function syncTabGroups() {
        var groups = document.querySelectorAll("[data-vctdg-tabgroup]");
        for (var i = 0; i < groups.length; i++) {
            var g = groups[i], root = tabRoot(g);
            var active = root ? (root.getAttribute("data-vct-tabs-active") || "") : "";
            var list = (g.getAttribute("data-vctdg-tabs") || "").split(",");
            var on = false;
            for (var k = 0; k < list.length; k++) if (String(list[k]).replace(/^\s+|\s+$/g, "") === active) on = true;
            g.classList.toggle("is-active", on);
        }
    }
    function closeTabMenu() {
        if (tabMenu.el && tabMenu.el.parentNode) tabMenu.el.parentNode.removeChild(tabMenu.el);
        if (tabMenu.trigger) tabMenu.trigger.classList.remove("is-open");
        tabMenu.el = null; tabMenu.trigger = null;
    }
    function openTabMenu(btn) {
        closeTabMenu();
        var src = btn.nextElementSibling;
        if (!src || !src.classList.contains("vctdg-tabgroup-items") || !src.children.length) return;
        var root = tabRoot(btn);
        var active = root ? (root.getAttribute("data-vct-tabs-active") || "") : "";
        var menu = document.createElement("div");
        menu.className = "vctdg-rowmenu is-tabgroup";
        menu.setAttribute("role", "menu");
        Array.prototype.forEach.call(src.children, function (orig) {
            var name = orig.getAttribute("data-vctdg-subtab");
            if (!name) return;
            var icon = orig.querySelector("[data-vct-icon]");
            var label = orig.querySelector("span:not([data-vct-icon])");
            var count = orig.querySelector("small");
            var item = document.createElement("button");
            item.type = "button";
            item.className = "vctdg-rowmenu-item" + (name === active ? " is-active" : "");
            item.setAttribute("role", "menuitem");
            item.setAttribute("data-vctdg-subtab", name);
            item.innerHTML = (icon ? '<span class="vctdg-rowmenu-icon" data-vct-icon="' + escA(icon.getAttribute("data-vct-icon")) + '"></span>' : "") +
                "<span>" + (label ? label.innerHTML : escA(name)) + "</span>" +
                (count ? "<small>" + count.innerHTML + "</small>" : "");
            menu.appendChild(item);
        });
        menu.addEventListener("click", function (e) {
            var it = e.target.closest(".vctdg-rowmenu-item");
            if (!it) return;
            e.preventDefault();
            e.stopPropagation();
            var name = it.getAttribute("data-vctdg-subtab");
            closeTabMenu();
            if (root && name && window.VCT && VCT.Tabs && typeof VCT.Tabs.activate === "function") VCT.Tabs.activate(root, name);
            syncTabGroups();
        });
        document.body.appendChild(menu);
        if (window.VCT && VCT.Icon && typeof VCT.Icon.init === "function") VCT.Icon.init(menu);
        var r = btn.getBoundingClientRect(), mw = menu.offsetWidth, mh = menu.offsetHeight;
        var left = Math.max(8, Math.min(r.left, window.innerWidth - mw - 8));
        var top = r.bottom + 4;
        if (top + mh > window.innerHeight - 8 && r.top - mh - 4 > 8) top = r.top - mh - 4;
        menu.style.left = left + "px";
        menu.style.top = top + "px";
        btn.classList.add("is-open");
        tabMenu.el = menu; tabMenu.trigger = btn;
    }
    document.addEventListener("click", function (e) {
        var btn = e.target.closest ? e.target.closest("[data-vctdg-tabgroup]") : null;
        if (btn) {
            e.preventDefault();
            e.stopPropagation();
            if (tabMenu.trigger === btn) closeTabMenu(); else openTabMenu(btn);
            return;
        }
        if (tabMenu.el && !tabMenu.el.contains(e.target)) closeTabMenu();
    });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") closeTabMenu(); });
    window.addEventListener("resize", closeTabMenu);
    window.addEventListener("scroll", closeTabMenu, true);
    if (window.MutationObserver) {
        var tabSyncPending = false;
        new MutationObserver(function () {
            if (tabSyncPending) return;
            tabSyncPending = true;
            setTimeout(function () { tabSyncPending = false; syncTabGroups(); }, 0);
        }).observe(document.documentElement, { attributes: true, attributeFilter: ["data-vct-tabs-active"], childList: true, subtree: true });
    }


    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", syncTabGroups);
    else syncTabGroups();
})(window, document);
