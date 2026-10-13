/* vct-agenda-consultor.js - v1
   ============================================================================
   Agenda del consultor (dbo.VCT_MAIN_AGENDA_CONSULTOR). Reusa la estetica del
   calendario de feriados (clases de vct-agenda.css) pero pinta, por dia, el
   ESTADO de disponibilidad del consultor que arma VCT_FN_AGENDA_CONSULTOR_RANGO.

   El SP manda todos los dias de una ventana amplia en data-vct-agc-dias (JSON);
   aca navegamos los meses sin ir al server. El unico round-trip es cambiar de
   consultor (solo perfiles VE_TODO): guarda IDSELEC01 y recarga la pantalla.

   v1 = solo lectura.
   ============================================================================ */
(function (window, document) {
    "use strict";
    if (window.__vctAgcLoaded) return;
    window.__vctAgcLoaded = true;

    var MESES = ["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"];
    var DIAS_ABREV = ["Dom","Lun","Mar","Mié","Jue","Vie","Sáb"];
    var DIAS_LARGO = ["Domingo","Lunes","Martes","Miércoles","Jueves","Viernes","Sábado"];

    function pad(n){ return (n<10?"0":"")+n; }
    function dateKey(d){ return d.getFullYear()+"-"+pad(d.getMonth()+1)+"-"+pad(d.getDate()); }
    function sameDay(a,b){ return a.getFullYear()===b.getFullYear() && a.getMonth()===b.getMonth() && a.getDate()===b.getDate(); }
    function addDays(d,n){ var x=new Date(d); x.setDate(x.getDate()+n); return x; }
    function wait(ms){ return new Promise(function(r){ setTimeout(r,ms); }); }
    function esc(s){ return String(s==null?"":s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }
    function escAttr(s){ return esc(s).replace(/"/g,"&quot;"); }

    /* estado -> etiqueta y clase */
    function clsOf(e){ return "vct-agc-" + String(e||"libre").toLowerCase(); }
    function fmtH(n){ n = +n||0; return (Math.round(n*10)/10).toString(); }

    function boot(){
        document.querySelectorAll("[data-vct-agc-root]").forEach(function(root){
            if (root.getAttribute("data-vct-agc-inited")==="1") return;
            root.setAttribute("data-vct-agc-inited","1");
            init(root);
        });
    }

    function init(root){
        var today = new Date(); today.setHours(0,0,0,0);

        /* datos */
        var dias = {};
        try {
            var raw = root.getAttribute("data-vct-agc-dias") || "[]";
            JSON.parse(raw).forEach(function(r){ dias[r.f] = r; });
        } catch(e){ dias = {}; }

        var paneEl   = root.querySelector("[data-vct-agc-pane]");
        var statsEl  = root.querySelector("[data-vct-agc-stats]");
        var titleEl  = root.querySelector("[data-vct-agc-title]");
        var selMonth = root.querySelector("[data-vct-agc-month]");
        var selYear  = root.querySelector("[data-vct-agc-year]");
        var selCons  = root.querySelector("[data-vct-agc-select-cons]");
        var btnPrev  = root.querySelector("[data-vct-agc-prev]");
        var btnNext  = root.querySelector("[data-vct-agc-next]");
        var viewBtns = root.querySelectorAll("[data-vct-agc-view]");

        /* reload al cambiar de consultor (solo VE_TODO): arranca una tarea nueva
           con ACTION=AGENDA_CONSULTOR + el consultor elegido. El separador de
           parametros de start_params es ';' (NO '||'). Es la misma via que usa
           el menu lateral (newTaskForContactWithParams). */
        if (selCons){
            selCons.addEventListener("change", function(){
                var id = selCons.value || "";
                if (typeof window.newTaskForContactWithParams !== "function") return;
                if (typeof window.vctSetActiveModule === "function") { try { vctSetActiveModule("9"); } catch(e){} }
                newTaskForContactWithParams("VOCATURO", "ACTION=AGENDA_CONSULTOR;IDSELEC01=" + id, "VCT_GESTION", "Agenda");
            });
        }

        if (!paneEl) return; /* sin consultor elegido: solo queda el prompt */

        var state = { cursor: new Date(today), view: "month" };

        function dayInfo(d){
            var k = dateKey(d);
            var r = dias[k];
            if (r) return r;
            var wd = d.getDay();
            if (wd===0 || wd===6) return { f:k, e:"FINDE", c:0, o:0, d:0, m:"" };
            return { f:k, e:"LIBRE", c:8, o:0, d:8, m:"" };
        }

        /* ---- selects de navegacion ---- */
        (function fillYears(){
            var minY=today.getFullYear()-1, maxY=today.getFullYear()+2;
            selYear.innerHTML="";
            for(var y=minY;y<=maxY;y++){
                var o=document.createElement("option"); o.value=String(y); o.textContent=String(y);
                selYear.appendChild(o);
            }
        })();

        function syncSelects(){
            selMonth.value=String(state.cursor.getMonth()+1);
            selYear.value=String(state.cursor.getFullYear());
        }

        /* ---- stats del mes visible ---- */
        function renderStats(){
            if (!statsEl) return;
            var y=state.cursor.getFullYear(), m=state.cursor.getMonth();
            var cap=0, ocu=0, disp=0, bloq=0, fer=0;
            var dim=new Date(y, m+1, 0).getDate();
            for(var i=1;i<=dim;i++){
                var r=dayInfo(new Date(y,m,i));
                cap += +r.c||0; ocu += +r.o||0; disp += +r.d||0;
                if (r.e==="BLOQUEADO") bloq++;
                if (r.e==="FERIADO") fer++;
            }
            function tile(tone,label,val,sub,icon){
                return '<div class="vct-360-stat" data-vct-tone="'+tone+'"><span>'
                     + '<span class="vct-360-stat-label">'+label+'</span><b>'+val+'</b><small>'+sub+'</small></span>'
                     + '<span class="vct-360-stat-icon"><span data-vct-icon="'+icon+'"></span></span></div>';
            }
            statsEl.innerHTML =
                  tile("mint","Horas libres", fmtH(disp), "en el mes", "check")
                + tile("violet","Horas ocupadas", fmtH(ocu), "visitas", "briefcase")
                + tile("blue","Capacidad", fmtH(cap), "horas hábiles", "clock-3")
                + tile("amber","No disponible", bloq, "día(s) bloqueado(s)", "ban");
        }

        /* ---- celda contenido ---- */
        function cellBadge(r){
            if (r.e==="FERIADO" || r.e==="BLOQUEADO") return r.m ? '<span class="vct-agc-cell-note">'+esc(r.m)+'</span>' : '';
            if (r.e==="FINDE") return '';
            if (r.e==="OCUPADO") return '<span class="vct-agc-cell-note">Ocupado</span>';
            if (r.e==="PARCIAL") return '<span class="vct-agc-cell-note">'+fmtH(r.d)+'h libres</span>';
            return '<span class="vct-agc-cell-note">'+fmtH(r.d)+'h</span>'; /* LIBRE */
        }

        /* ---- vistas ---- */
        function renderMonth(){
            var year=state.cursor.getFullYear(), month=state.cursor.getMonth()+1;
            titleEl.textContent=MESES[month-1]+" "+year;
            var first=new Date(year,month-1,1), startW=first.getDay();
            var dim=new Date(year,month,0).getDate();
            var totalCells=Math.ceil((startW+dim)/7)*7, dayNum=1-startW;

            var html='<table class="vct-agenda-table vct-agc-table"><thead><tr>'
                + DIAS_ABREV.map(function(d){ return "<th>"+d+"</th>"; }).join("") + '</tr></thead><tbody>';
            for(var w=0; w<totalCells/7; w++){
                html+="<tr>";
                for(var dd=0; dd<7; dd++){
                    if(dayNum<1 || dayNum>dim){ html+='<td class="vct-agenda-cell vct-agenda-cell-empty"></td>'; }
                    else{
                        var cd=new Date(year,month-1,dayNum), k=dateKey(cd), r=dayInfo(cd);
                        var isToday=sameDay(cd,today);
                        var cls="vct-agenda-cell "+clsOf(r.e)+(isToday?" vct-agenda-cell-today":"");
                        html+='<td class="'+cls+'" data-vct-agc-day="'+k+'"'+(r.m?' title="'+escAttr(r.m)+'"':'')+'>';
                        html+='<span class="vct-agenda-daynum">'+dayNum+'</span>';
                        html+=cellBadge(r);
                        html+='</td>';
                    }
                    dayNum++;
                }
                html+="</tr>";
            }
            html+="</tbody></table>";
            paneEl.innerHTML=html;
            bindDayClicks();
        }

        function renderWeek(){
            var start=addDays(state.cursor, -state.cursor.getDay()), end=addDays(start,6);
            titleEl.textContent=start.getDate()+" "+MESES[start.getMonth()].substr(0,3)+" - "+end.getDate()+" "+MESES[end.getMonth()].substr(0,3)+" "+end.getFullYear();
            var html='<div class="vct-agenda-weeklist">';
            for(var i=0;i<7;i++){
                var d=addDays(start,i), k=dateKey(d), r=dayInfo(d), isToday=sameDay(d,today);
                html+='<div class="vct-agenda-weekrow '+clsOf(r.e)+'" data-vct-agc-day="'+k+'">';
                html+='<div class="vct-agenda-weekrow-date'+(isToday?" is-today":"")+'">';
                html+='<span class="vct-agenda-weekrow-dayname">'+DIAS_ABREV[i]+'</span>';
                html+='<span class="vct-agenda-weekrow-daynum">'+d.getDate()+'</span>';
                html+='<span class="vct-agenda-weekrow-month">'+MESES[d.getMonth()].substr(0,3)+'</span>';
                html+='</div>';
                html+='<div class="vct-agenda-weekrow-card vct-agc-weekcard">';
                html+='<span class="vct-agc-badge '+clsOf(r.e)+'">'+estadoLabel(r)+'</span>';
                if (r.m) html+='<span class="vct-agenda-weekrow-text">'+esc(r.m)+'</span>';
                else if (r.e==="PARCIAL"||r.e==="LIBRE") html+='<span class="vct-agenda-weekrow-text">'+fmtH(r.d)+'h libres de '+fmtH(r.c)+'h</span>';
                html+='</div></div>';
            }
            html+='</div>';
            paneEl.innerHTML=html;
            bindDayClicks();
        }

        /* ---- edición de bloqueos (solo con permiso EDIT) ---- */
        var canEdit = root.getAttribute("data-vct-agc-can-edit")==="1";
        var consId  = root.getAttribute("data-vct-agc-cons") || "";
        function saveBlock(fecha, motivo, unblock){
            if (typeof window.newTaskForContactWithParams !== "function") return;
            if (typeof window.vctSetActiveModule === "function") { try { vctSetActiveModule("9"); } catch(e){} }
            var mot = String(motivo||"").replace(/[;=+]/g," ").trim().slice(0,200);
            var params = "ACTION=AGENDA_CONSULTOR;IDSELEC01=" + consId + ";TEXTO01=" + fecha
                       + (unblock ? ";FLAG02=1" : (";FLAG01=1;TEXTO02=" + mot));
            newTaskForContactWithParams("VOCATURO", params, "VCT_GESTION", "Agenda");
        }

        function renderDay(){
            var d=state.cursor, r=dayInfo(d), key=dateKey(d), past=d<today;
            titleEl.textContent=DIAS_LARGO[d.getDay()]+" "+d.getDate()+" de "+MESES[d.getMonth()]+" "+d.getFullYear();
            var html='<div class="vct-agenda-day vct-agc-dayview '+clsOf(r.e)+'">';
            html+='<div class="vct-agenda-day-num">'+d.getDate()+'</div>';
            html+='<div class="vct-agenda-day-name">'+DIAS_LARGO[d.getDay()]+'</div>';
            html+='<div class="vct-agc-dayview-badge"><span class="vct-agc-badge '+clsOf(r.e)+'">'+estadoLabel(r)+'</span></div>';
            if (r.m) html+='<div class="vct-agc-dayview-note">'+esc(r.m)+'</div>';
            if (r.e!=="FINDE" && r.e!=="FERIADO" && r.e!=="BLOQUEADO")
                html+='<div class="vct-agc-dayview-hours">'+fmtH(r.d)+'h libres de '+fmtH(r.c)+'h ('+fmtH(r.o)+'h ocupadas)</div>';

            if (canEdit && !past && r.e!=="FERIADO" && r.e!=="FINDE"){
                if (r.e==="BLOQUEADO"){
                    html+='<div class="vct-agc-edit"><button type="button" class="vct-btn vct-agc-btn-unblock" data-vct-agc-unblock>Quitar bloqueo (volver a disponible)</button></div>';
                } else {
                    html+='<div class="vct-agc-edit">'
                        + '<input type="text" class="vct-input vct-agc-mot" placeholder="Motivo (vacaciones, licencia...)" maxlength="200">'
                        + '<button type="button" class="vct-btn vct-agc-btn-block" data-vct-agc-block>Marcar no disponible</button>'
                        + '</div>';
                }
            }
            html+='</div>';
            paneEl.innerHTML=html;

            var bBtn=paneEl.querySelector("[data-vct-agc-block]");
            if (bBtn) bBtn.addEventListener("click", function(){
                var mot=(paneEl.querySelector(".vct-agc-mot")||{}).value||"";
                saveBlock(key, mot, false);
            });
            var uBtn=paneEl.querySelector("[data-vct-agc-unblock]");
            if (uBtn) uBtn.addEventListener("click", function(){ saveBlock(key, "", true); });
        }

        function estadoLabel(r){
            switch(r.e){
                case "FINDE": return "Fin de semana";
                case "FERIADO": return "Feriado";
                case "BLOQUEADO": return "No disponible";
                case "OCUPADO": return "Ocupado";
                case "PARCIAL": return "Parcial";
                default: return "Libre";
            }
        }

        function bindDayClicks(){
            paneEl.querySelectorAll("[data-vct-agc-day]").forEach(function(cell){
                cell.addEventListener("click", function(){
                    var p=cell.getAttribute("data-vct-agc-day").split("-");
                    state.cursor=new Date(+p[0], +p[1]-1, +p[2]);
                    state.view="day"; setView("day"); render();
                });
            });
        }

        function setView(v){
            state.view=v;
            viewBtns.forEach(function(b){ b.classList.toggle("is-active", b.getAttribute("data-vct-agc-view")===v); });
        }

        function render(){
            if (state.view==="week") renderWeek();
            else if (state.view==="day") renderDay();
            else renderMonth();
            renderStats();
            syncSelects();
        }

        /* ---- eventos ---- */
        if (btnPrev) btnPrev.addEventListener("click", function(){
            if (state.view==="month") state.cursor.setMonth(state.cursor.getMonth()-1);
            else if (state.view==="week") state.cursor=addDays(state.cursor,-7);
            else state.cursor=addDays(state.cursor,-1);
            render();
        });
        if (btnNext) btnNext.addEventListener("click", function(){
            if (state.view==="month") state.cursor.setMonth(state.cursor.getMonth()+1);
            else if (state.view==="week") state.cursor=addDays(state.cursor,7);
            else state.cursor=addDays(state.cursor,1);
            render();
        });
        if (selMonth) selMonth.addEventListener("change", function(){ state.cursor.setMonth(+selMonth.value-1); render(); });
        if (selYear)  selYear.addEventListener("change", function(){ state.cursor.setFullYear(+selYear.value); render(); });
        viewBtns.forEach(function(b){ b.addEventListener("click", function(){ setView(b.getAttribute("data-vct-agc-view")); render(); }); });

        render();
    }

    if (document.readyState==="loading") document.addEventListener("DOMContentLoaded", boot);
    else boot();
    if (window.MutationObserver){
        var pend=false;
        new MutationObserver(function(){
            if (pend) return; pend=true;
            setTimeout(function(){ pend=false; boot(); }, 40);
        }).observe(document.documentElement, { childList:true, subtree:true });
    }
})(window, document);
