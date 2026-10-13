/* ============================================================================
   AGENDA_CONSULTOR_2_PERMISOS
   ----------------------------------------------------------------------------
   Alta de permisos y visibilidad de menu para la pantalla Agenda del consultor.
   Sin esto, VCT_MAIN_AGENDA_CONSULTOR devuelve "Acceso restringido".

   Crea:
     - Actions      : AGENDA_CONSULTOR.VIEW (SIDEBAR) y .EDIT (ACTION).
     - PrmActions   : idem, SideBarId=9 (lo lee VCT_MAIN_GET_ACTIONS, prefijo
                      'AGENDA_CONSULTOR.%' -> no colisiona con 'AGENDA.%').
     - GroupsActions: VIEW+EDIT a GERENCIA, SQUAD, ADMINISTRACION, PROYECTOS,
                      CONSULTORES.
     - SideBarGroups: visibilidad del menu (SideBarId=9, Id=10) para
                      ADMINISTRACION, PROYECTOS, CONSULTORES (GERENCIA/SQUAD ya).

   Todo guardado (IF NOT EXISTS): re-ejecutable. No pisa nada.
   ============================================================================ */
USE [MuhlePROD];
GO
SET NOCOUNT ON;

/* ---------- 1) Actions ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Actions WHERE Id = 'AGENDA_CONSULTOR.VIEW')
    INSERT dbo.Actions (Id, Name, IdPadre, Tipo)
    VALUES ('AGENDA_CONSULTOR.VIEW', 'Ver agenda del consultor', NULL, 'SIDEBAR');

IF NOT EXISTS (SELECT 1 FROM dbo.Actions WHERE Id = 'AGENDA_CONSULTOR.EDIT')
    INSERT dbo.Actions (Id, Name, IdPadre, Tipo)
    VALUES ('AGENDA_CONSULTOR.EDIT', 'Editar agenda del consultor', NULL, 'ACTION');

/* ---------- 2) PrmActions (Id es IDENTITY: no se inserta) ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.PrmActions WHERE ActionID = 'AGENDA_CONSULTOR.VIEW')
    INSERT dbo.PrmActions (ActionID, ActionType, Title, Icon, KeyField, StorageKey, TargetTab, SortOrder, TargetGuid, SideBarId)
    VALUES ('AGENDA_CONSULTOR.VIEW', 'VIEW', 'Ver agenda', 'eye', 'Clave', 'IDSELEC01', NULL, 3, NULL, 9);

IF NOT EXISTS (SELECT 1 FROM dbo.PrmActions WHERE ActionID = 'AGENDA_CONSULTOR.EDIT')
    INSERT dbo.PrmActions (ActionID, ActionType, Title, Icon, KeyField, StorageKey, TargetTab, SortOrder, TargetGuid, SideBarId)
    VALUES ('AGENDA_CONSULTOR.EDIT', 'EDIT', 'Editar agenda', 'edit', 'Clave', 'IDSELEC01', NULL, 2, NULL, 9);

/* ---------- 3) GroupsActions (grants por perfil) ---------- */
INSERT dbo.GroupsActions (GroupId, ActionId)
SELECT G.v, A.v
FROM (VALUES ('GERENCIA'),('SQUAD'),('ADMINISTRACION'),('PROYECTOS'),('CONSULTORES')) G(v)
CROSS JOIN (VALUES ('AGENDA_CONSULTOR.VIEW'),('AGENDA_CONSULTOR.EDIT')) A(v)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.GroupsActions GA
    WHERE UPPER(LTRIM(RTRIM(GA.GroupId))) = G.v
      AND UPPER(LTRIM(RTRIM(GA.ActionId))) = A.v);

/* ---------- 4) SideBarGroups (ver el menu Agenda = SideBarId 9, Id 10) ---------- */
INSERT dbo.SideBarGroups (Id, SideBarId, GroupId)
SELECT N'10', N'9', X.v
FROM (VALUES ('ADMINISTRACION'),('PROYECTOS'),('CONSULTORES')) X(v)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.SideBarGroups s
    WHERE CONVERT(VARCHAR(50), s.SideBarId) = '9'
      AND UPPER(LTRIM(RTRIM(s.GroupId))) = X.v);

/* ---------- 5) Verificacion ---------- */
PRINT '--- Actions AGENDA_CONSULTOR ---';
SELECT Id, Tipo FROM dbo.Actions WHERE Id LIKE 'AGENDA_CONSULTOR.%' ORDER BY Id;

PRINT '--- PrmActions AGENDA_CONSULTOR ---';
SELECT ActionID, ActionType, SideBarId FROM dbo.PrmActions WHERE ActionID LIKE 'AGENDA_CONSULTOR.%' ORDER BY ActionID;

PRINT '--- GroupsActions AGENDA_CONSULTOR ---';
SELECT GroupId, ActionId FROM dbo.GroupsActions WHERE UPPER(ActionId) LIKE 'AGENDA_CONSULTOR.%' ORDER BY ActionId, GroupId;

PRINT '--- SideBarGroups menu Agenda (SideBarId 9) ---';
SELECT Id, SideBarId, GroupId FROM dbo.SideBarGroups WHERE CONVERT(VARCHAR(50), SideBarId) = '9' ORDER BY GroupId;
GO
