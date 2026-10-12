<%@ Page Language="VB" AutoEventWireup="false" ValidateRequest="false" EnableViewStateMac="false" Inherits="MWebLibrary.clsMain" %>
<!DOCTYPE html>
<html lang="es">
    <head>
        <title>Mühle | Main</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="../css/w3.css"/>
        <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.15.3/css/all.css">
        <link rel="stylesheet" href="../lib/DataTables/datatables.min.css" />
        <link rel="stylesheet" href="../css/font-awesome-5-all.css"/>
        <link rel="stylesheet" href="../css/sw2/sweetalert2.min.css"/>
        <link rel="stylesheet" href="../css/progress-wizard.min.css"/>
        <link rel="shortcut icon" href="../favicon.ico" type="image/x-icon"/>
        <link rel="icon" href="../favicon.ico" type="image/x-icon"/>
        <link rel="stylesheet" href="../css/main.css"/>
        <!-- Escala unica de campos de formulario (escritorio): ver css/vct-forms.css -->
        <link rel="stylesheet" href="../css/vct-forms.css?v=1"/>
        
        <style>
            /* ⚪ TOPBAR BLANCA ULTRA CLEAN */
            body #muhleTopBar.w3-muhle-topbar {
                height: 60px !important;
                background-color: #ffffff !important;
                border-bottom: 1px solid #e2e8f0 !important;
                box-shadow: 0 2px 10px rgba(0,0,0,0.05) !important;
                position: fixed !important;
                top: 0 !important;
                left: 0 !important;
                width: 100% !important;              
                padding: 0 !important;
                margin: 0 !important;
                z-index: 1000 !important;
                display: flex !important;
                align-items: center !important;
                justify-content: space-between !important;
            }
            
            /* LOGO IZQUIERDO */
            body #muhleTopBar .w3-muhle-logo-container {
                position: absolute !important;
                left: 0 !important;
                top: 0 !important;
                height: 60px !important;
                display: flex !important;
                align-items: center !important;
            }
            
            body #muhleTopBar .w3-muhle-logo {
                height: 38px !important;
                width: auto !important;
                margin-left: 15px !important;
                display: block !important;
                object-fit: contain !important;
            }

            /* SECCIÓN DERECHA DE USUARIO */
            .vct-header-right-container {
                position: absolute !important;
                right: 15px !important;
                top: 0 !important;
                height: 60px !important;
                display: flex !important;
                align-items: center !important;
                gap: 12px !important;
            }

            /* WIDGET DE USUARIO */
            .vct-user-widget {
                display: flex !important;
                align-items: center !important;
                gap: 10px !important;
                padding: 4px 10px !important;
                border-radius: 8px !important;
                background: #f8fafc !important;
                border: 1px solid #e2e8f0 !important;
                transition: background 0.2s ease !important;
            }
            .vct-user-widget:hover {
                background: #f1f5f9 !important;
            }

            /* AVATAR CIRCULAR */
            .vct-avatar {
                width: 34px !important;
                height: 34px !important;
                border-radius: 50% !important;
                background: #66062C !important;
                border: 1px solid #cbd5e1 !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                overflow: hidden !important;
                flex-shrink: 0 !important;
                margin-bottom: 3px;
            }

            .vct-avatar img {
                width: 100% !important;
                height: 100% !important;
                object-fit: cover !important;
                object-position: center !important;
                display: block !important;
                margin-bottom: 3px;
            }

            /* TEXTO Y NOMBRE */
            .vct-user-details {
                display: flex !important;
                flex-direction: column !important;
                text-align: left !important;
            }

            .vct-user-subtitle {
                color: #64748b !important;
                font-size: 10px !important;
                font-weight: 600 !important;
                line-height: 1 !important;
                text-transform: uppercase !important;
            }

            .vct-user-title {
                color: #0f172a !important;
                font-size: 13px !important;
                font-weight: 700 !important;
                line-height: 1.2 !important;
            }

            /* BOTÓN SALIR */
            .w3-muhle-topbar-button {
                height: 36px !important;
                width: 36px !important;
                display: inline-flex !important;
                align-items: center !important;
                justify-content: center !important;
                background: transparent !important;
                border: none !important;
                border-radius: 8px !important;
                cursor: pointer !important;
                transition: background 0.2s !important;
            }
            .w3-muhle-topbar-button:hover {
                background: #fee2e2 !important;
            }
            .w3-muhle-topbar-button i {
                color: #66062D !important;
                font-size: 16px !important;
            }

            /* ESTILOS DEL SIDEBAR INYECTADO DESDE SQL */
            body #muhleSideBar {
                display: block !important;
                visibility: visible !important;
                position: fixed !important;
                top: 60px !important;
                left: 0 !important;
                height: calc(100vh - 60px) !important;
                width: 60px !important;
                background-color: #66062C !important;
                z-index: 999 !important;
                overflow: hidden !important;
                box-shadow: 2px 0 15px rgba(0,0,0,0.1) !important;
            }

            body #muhleSideBar a {
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                color: rgba(255, 255, 255, 0.7) !important;
                text-decoration: none !important;
                height: 55px !important;
                width: 60px !important;
                transition: all 0.2s ease !important;
            }

            body #muhleSideBar a:first-child {
                margin-top: 15px !important;
            }

            body #muhleSideBar a:hover {
                background-color: rgba(255, 255, 255, 0.15) !important;
                color: #ffffff !important;
            }

            body #muhleSideBar a i {
                font-size: 18px !important;
            }

            body #muhleSideBar a span {
                display: none !important;
            }

            /* CONTENIDO ACOPLADO */
            body #main.w3-main {
                margin-left: 60px !important;
                margin-top: 60px !important;
                padding: 0 !important;
            }

            body #mainContainer {
                padding: 20px !important;
            }
        </style>
    </head>
    <body class="w3-light-grey">

        <!------ BARRA SUPERIOR ------>
        <div id="muhleTopBar" class="w3-bar w3-top w3-muhle-topbar">
            <span class="w3-bar-item w3-muhle-logo-container">
                <a href="javascript:loadHome();"><img class="w3-muhle-logo" src="../img/logo.jpg"></a>
            </span>
            
            <div class="vct-header-right-container">
                <!-- WIDGET DE PERFIL -->
                <div class="vct-user-widget" onclick="profile();" style="cursor: pointer;" title="Ver Perfil">
                    <div class="vct-avatar">
                        <img src="../img/avatar1.png" alt="Avatar">
                    </div>
                    <div class="vct-user-details">
                        <span class="vct-user-subtitle">¡HOLA!</span>
                        <span class="vct-user-title">
                            <span id="fullname"><asp:Label id="lblAgentValue" runat="server" Text=""></asp:Label></span>
                        </span>
                    </div>
                </div>

                <!-- BOTÓN DE SALIR -->
                <button type="button" class="w3-muhle-topbar-button" onclick="logout();" title="Salir del Sistema">
                    <i class="fas fa-sign-out-alt"></i>
                </button>
            </div>
        </div>

        <!-- ℹ️ EL SIDEBAR SE INYECTA AHORA AUTOMÁTICAMENTE DESDE EL SP HOME_INICIO_PORTAL EN @OMENU -->

        <div id="muhlePopup" class="w3-hide">
            <span class="closebtn" onclick="this.parentElement.style.display='none';">&times;</span>
            <span id="muhlePopupMessage">This is an alert box.</span>
        </div>

        <!------ CONTENIDO DINÁMICO ------>
        <div id="main" class="w3-main">
            <div class="w3-container">
                <div id="loader" class="loading" style="display: none;"><div class="loader"></div></div>
                <div id="mainContainer" class="w3-light-grey"></div>
            </div>
        </div>

        <script src="../lib/jquery/jquery.min.js"></script>
        <script src="../lib/jquery-file-upload/vendor/jquery.ui.widget.js"></script>
        <script src="../lib/jquery-file-upload/jquery.iframe-transport.js"></script>
        <script src="../lib/jquery-file-upload/jquery.fileupload.js"></script>
        <script src="../lib/DataTables/datatables.min.js"></script>
        <script src="../lib/easy-timer/easytimer.min.js"></script>
        <script src="../lib/tableToExcel/tableToExcel.js"></script>
        <script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyBZxqMtqChOx4vdThcsr_-W2CJ762OBxRg"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.3/Chart.min.js"></script>
        <script src="../css/sw2/sweetalert2.all.min.js"></script>
        <script src="../css/sw2/sweetalert2.min.js"></script>
        <script src="../js/main.js"></script>
        <script>
        try {
            var full_name = document.getElementById("fullname").innerText.trim();
            if(full_name && full_name !== "") {
                if(full_name.indexOf(',') !== -1) {
                    var name = full_name.split(',')[1].trim();
                    document.getElementById("fullname").innerHTML = name.split(' ')[0];
                } else {
                    document.getElementById("fullname").innerHTML = full_name.split(' ')[0];
                }
            }
        } catch(e) { console.log(e); }

        function loadHome() {
            try {
                newTaskForContactWithParams('VOCATURO', 'ACTION=INICIO', 'XAGENDA', 'Inicio');
            } catch(err) {
                console.warn("Mühle loadHome fallback:", err);
                $('#mainContainer').empty();
            }
        }

        function profile() {
            $('#mainContainer').hide(); 
            $('#loader').show();
            $.ajax({
                type: 'GET', 
                url: '../profile/', 
                dataType: "text",
                success: function (data) { 
                    $("#mainContainer").html(data); 
                    $('#loader').hide(); 
                    $("#mainContainer").show(); 
                },
                error: function (httpReq, status, exception) { 
                    console.log(status + " " + exception); 
                    $('#loader').hide();
                    $('#mainContainer').show();
                }
            });
        }

        function logout() {
            $('#mainContainer').hide(); 
            $('#loader').show();
            $.ajax({
                type: 'GET', 
                url: '../logout/', 
                dataType: "text",
                success: function (data) { 
                    window.location.href = '../'; 
                },
                error: function (httpReq, status, exception) { 
                    console.log(status + " " + exception); 
                    $('#loader').hide();
                }
            });
        }

        $(document).ready(function () {
            loadHome();
        });
        </script>
    </body>
</html>