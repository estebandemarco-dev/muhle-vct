/* ========================================================================
   VCT ACCIONES                                                          v1
   ------------------------------------------------------------------------
   Pantalla Acciones (dbo.VCT_MAIN_ACCIONES, ACCIONES_PANTALLA_V2).
   - Cambio Lista / Calendario dentro de la card de cada pestana.
   - Calendario mensual armado con los datos ocultos .vct-acc-caldata
     (<i data-d="yyyymmdd" data-s="V|H|P|L" data-t="titulo">), filtrado por
     la situacion de la pestana (data-vct-acc-sit; T = todas).
   - Click en un dia: vuelve a Lista y busca esa fecha en la grilla.
   - "Marcar cumplida" / "Reabrir": buffer (ACC_ESTADO) + goto, y al volver
     queda abierta la misma pestana.
   Guarda propia: no depende de la guarda de vct-datagrid.js.
   ======================================================================== */
(function () {
    "use strict";
    if (window.VCTAcciones && window.VCTAcciones.version >= 1) return;

    var GUID_INICIO = "447E1496-AC9B-4821-B658-25AB8D1F45AE";
    var MESES = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
    var DIAS = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"];
    var SIT_CLS = { V: "is-red", H: "is-amb", P: "is-bor", L: "is-gry" };

    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function ymd(d) { return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()); }
    function parseYmd(s) { return new Date(+s.substr(0, 4), +s.substr(4, 2) - 1, +s.substr(6, 2)); }
    function dmy(s) { return s.substr(6, 2) + "/" + s.substr(4, 2) + "/" + s.substr(0, 4); }
    function esc(s) {
        return String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }

    /* ---------------- datos ---------------- */
    function readData(root) {
        if (root._accData) return root._accData;
        var list = [];
        var box = root.querySelector(".vct-acc-caldata");
        if (box) {
            box.querySelectorAll("i[data-d]").forEach(function (i) {
                list.push({ d: i.getAttribute("data-d"), s: i.getAttribute("data-s") || "L", t: i.getAttribute("data-t") || "" });
            });
        }
        root._accData = list;
        return list;
    }
    function itemsFor(root, sit) {
        return readData(root).filter(function (x) { return sit === "T" || x.s === sit; });
    }
    function todayOf(root) {
        var h = root.getAttribute("data-vct-acc-hoy");
        return h && h.length === 8 ? parseYmd(h) : new Date();
    }

    /* ---------------- calendario ---------------- */
    function initialMonth(root, panel) {
        var sit = panel.getAttribute("data-vct-acc-sit") || "T";
        var hoy = todayOf(root);
        if (sit === "V") {
            var it = itemsFor(root, "V");
            if (it.length) { var last = parseYmd(it[it.length - 1].d); return new Date(last.getFullYear(), last.getMonth(), 1); }
        }
        return new Date(hoy.getFullYear(), hoy.getMonth(), 1);
    }

    function renderCal(root, panel) {
        var cal = panel.querySelector("[data-vct-acc-cal]");
        if (!cal) return;
        var sit = panel.getAttribute("data-vct-acc-sit") || "T";
        if (!panel._accMonth) panel._accMonth = initialMonth(root, panel);
        var m0 = panel._accMonth;
        var hoyKey = ymd(todayOf(root));

        var byDay = {};
        itemsFor(root, sit).forEach(function (x) { (byDay[x.d] = byDay[x.d] || []).push(x); });

        var first = new Date(m0.getFullYear(), m0.getMonth(), 1);
        var offset = (first.getDay() + 6) % 7;               /* lunes = 0 */
        var days = new Date(m0.getFullYear(), m0.getMonth() + 1, 0).getDate();
        var total = 0;
        Object.keys(byDay).forEach(function (k) {
            if (k.substr(0, 6) === ymd(first).substr(0, 6)) total += byDay[k].length;
        });

        var h = '<div class="vct-acc-cal-head">' +
            '<button type="button" class="vct-acc-cal-nav" data-vct-acc-cal-nav="-1" aria-label="Mes anterior"><span data-vct-icon="chevron-left"></span></button>' +
            '<b>' + MESES[m0.getMonth()] + " " + m0.getFullYear() + '</b>' +
            '<button type="button" class="vct-acc-cal-nav" data-vct-acc-cal-nav="1" aria-label="Mes siguiente"><span data-vct-icon="chevron-right"></span></button>' +
            '<button type="button" class="vct-acc-cal-today" data-vct-acc-cal-nav="0">Hoy</button>' +
            '<span class="vct-acc-cal-total">' + total + (total === 1 ? " acción" : " acciones") + " en el mes</span>" +
            '</div><div class="vct-acc-calg">';
        DIAS.forEach(function (d) { h += '<span class="vct-acc-cal-dow">' + d + "</span>"; });
        for (var i = 0; i < offset; i++) h += '<span class="vct-acc-cal-day is-out"></span>';
        for (var d = 1; d <= days; d++) {
            var key = ymd(new Date(m0.getFullYear(), m0.getMonth(), d));
            var dow = (offset + d - 1) % 7;
            var its = byDay[key] || [];
            var cls = "vct-acc-cal-day" + (dow >= 5 ? " is-we" : "") + (key === hoyKey ? " is-today" : "") + (its.length ? " has-items" : "");
            h += '<div class="' + cls + '"' + (its.length ? ' data-vct-acc-day="' + key + '" role="button" tabindex="0" title="Ver las ' + its.length + ' acciones del ' + dmy(key) + ' en la lista"' : "") + ">";
            h += '<span class="vct-acc-cal-num">' + d + "</span>";
            its.slice(0, 2).forEach(function (x) {
                h += '<span class="vct-acc-pill ' + (SIT_CLS[x.s] || "is-gry") + '" title="' + esc(x.t) + '">' + esc(x.t) + "</span>";
            });
            if (its.length > 2) h += '<span class="vct-acc-more">+' + (its.length - 2) + " más</span>";
            h += "</div>";
        }
        h += "</div>" +
            '<div class="vct-acc-lg"><span><i class="is-red"></i>Vencida</span><span><i class="is-amb"></i>Hoy</span><span><i class="is-bor"></i>Próximos 7 días</span><span><i class="is-gry"></i>Más adelante</span>' +
            '<em>Tocá un día para ver sus acciones en la lista.</em></div>';
        cal.innerHTML = h;
        if (window.VCT && VCT.Icon && typeof VCT.Icon.init === "function") VCT.Icon.init(cal);
    }

    function setView(root, panel, view) {
        var list = panel.querySelector(".vct-acc-list");
        var cal = panel.querySelector("[data-vct-acc-cal]");
        if (!cal || !list) return;
        panel.querySelectorAll("[data-vct-acc-view]").forEach(function (b) {
            b.classList.toggle("is-on", b.getAttribute("data-vct-acc-view") === view);
            b.setAttribute("aria-pressed", b.getAttribute("data-vct-acc-view") === view ? "true" : "false");
        });
        if (view === "calendario") {
            renderCal(root, panel);
            list.hidden = true;
            cal.hidden = false;
        } else {
            cal.hidden = true;
            list.hidden = false;
        }
    }

    function searchInList(root, panel, key) {
        setView(root, panel, "lista");
        var input = panel.querySelector(".vctdg-search input");
        if (!input) return;
        input.value = dmy(key);
        input.dispatchEvent(new Event("input", { bubbles: true }));
        try { input.focus(); } catch (e) { }
    }

    /* ---------------- init ---------------- */
    function ensureActive(root) {
        var active = root.querySelector(".vct-360-panel.is-active");
        if (active) return;
        var name = root.getAttribute("data-vct-acc-default") || "todas";
        if (window.VCT && VCT.Tabs && typeof VCT.Tabs.activate === "function") VCT.Tabs.activate(root, name);
    }

    function init(root) {
        if (!root || root.getAttribute("data-vct-acc-ready") === "1") return;
        root.setAttribute("data-vct-acc-ready", "1");
        root._accData = null;
        /* VCT.Tabs puede venir de una V360 con "resumen" forzado: si no quedo
           ningun panel activo se abre la pestana sugerida por el SP. */
        setTimeout(function () { ensureActive(root); }, 0);
        setTimeout(function () { ensureActive(root); }, 400);
        /* el alerta del comando se va sola */
        var al = root.querySelector(".vct-acc-alert");
        if (al) setTimeout(function () { al.classList.add("is-hiding"); setTimeout(function () { if (al.parentNode) al.parentNode.removeChild(al); }, 400); }, 6000);
    }

    function scan(scope) {
        scope = scope || document;
        if (scope.matches && scope.matches("[data-vct-acc]")) init(scope);
        if (scope.querySelectorAll) scope.querySelectorAll("[data-vct-acc]").forEach(init);
    }

    /* ---------------- eventos (una sola vez, delegados) ---------------- */
    document.addEventListener("click", function (e) {
        var t = e.target;
        if (!t || !t.closest) return;

        var vb = t.closest("[data-vct-acc-view]");
        if (vb) {
            var p1 = vb.closest(".vct-acc-panel"), r1 = vb.closest("[data-vct-acc]");
            if (p1 && r1) { e.preventDefault(); setView(r1, p1, vb.getAttribute("data-vct-acc-view")); }
            return;
        }

        var nav = t.closest("[data-vct-acc-cal-nav]");
        if (nav) {
            var p2 = nav.closest(".vct-acc-panel"), r2 = nav.closest("[data-vct-acc]");
            if (!p2 || !r2) return;
            e.preventDefault();
            var step = parseInt(nav.getAttribute("data-vct-acc-cal-nav"), 10) || 0;
            if (step === 0) { var hy = todayOf(r2); p2._accMonth = new Date(hy.getFullYear(), hy.getMonth(), 1); }
            else { var m = p2._accMonth || initialMonth(r2, p2); p2._accMonth = new Date(m.getFullYear(), m.getMonth() + step, 1); }
            renderCal(r2, p2);
            return;
        }

        var day = t.closest("[data-vct-acc-day]");
        if (day) {
            var p3 = day.closest(".vct-acc-panel"), r3 = day.closest("[data-vct-acc]");
            if (p3 && r3) { e.preventDefault(); searchInList(r3, p3, day.getAttribute("data-vct-acc-day")); }
            return;
        }

        var b = t.closest("[data-vct-acc-estado]");
        if (b && !b.disabled) {
            e.preventDefault();
            var est = b.getAttribute("data-vct-acc-estado");
            if (est === "PENDIENTE" && !window.confirm("¿Volver a abrir esta acción?")) return;
            if (!window.VCT || !VCT.Buffer || !VCT.Navigation) return;
            b.disabled = true;
            var root = b.closest("[data-vct-acc]");
            var tab = root ? root.getAttribute("data-vct-tabs-active") : "";
            if (tab && VCT.Tabs && typeof VCT.Tabs.rememberInternalTab === "function") VCT.Tabs.rememberInternalTab(tab);
            var S = function (k, v) { return Promise.resolve(VCT.Buffer.store(k, v)); };
            S("TEXTO30", "ACC_ESTADO")
                .then(function () { return S("IDSELEC03", b.getAttribute("data-vct-acc-id")); })
                .then(function () { return S("TEXTO11", est); })
                .then(function () { return S("FLAG01", "1"); })
                .then(function () { VCT.Navigation.goto(b, GUID_INICIO); })
                .catch(function () { b.disabled = false; });
        }
    });

    document.addEventListener("keydown", function (e) {
        if (e.key !== "Enter" && e.key !== " ") return;
        var day = e.target && e.target.closest ? e.target.closest("[data-vct-acc-day]") : null;
        if (!day) return;
        e.preventDefault();
        day.click();
    });

    /* SPA: la pantalla se inyecta sin recargar */
    function boot() {
        scan(document);
        if (window.MutationObserver && document.body) {
            new MutationObserver(function (muts) {
                for (var i = 0; i < muts.length; i++) {
                    var add = muts[i].addedNodes;
                    for (var j = 0; j < add.length; j++) if (add[j].nodeType === 1) scan(add[j]);
                }
            }).observe(document.body, { childList: true, subtree: true });
        }
    }
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot); else boot();

    window.VCTAcciones = { version: 1, scan: scan, render: renderCal };
})();
