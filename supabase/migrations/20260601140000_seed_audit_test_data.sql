-- Seed: comprehensive test data for audit_logs
-- Covers multiple resource types, results, dates, and actor roles

DO $$
DECLARE
  v_profile_id uuid;
  v_unit_1_id uuid;
  v_unit_2_id uuid;
  v_crew_id uuid;
  v_aircraft_id uuid;
  v_route_id uuid;
  v_order_id uuid;
  v_access_id uuid;
  v_report_id uuid;
  v_closure_id uuid;
  v_user_id uuid;
  v_msg_id uuid;
  v_profile_leader uuid;
  v_profile_admin uuid;
  v_profile_cmd uuid;
  v_profile_unit_admin uuid;
  v_profile_ttaa uuid;
BEGIN
  -- Get reference IDs
  SELECT id INTO v_profile_leader   FROM public.profiles WHERE role = 'leader'         LIMIT 1;
  SELECT id INTO v_profile_admin    FROM public.profiles WHERE role = 'general_admin'  LIMIT 1;
  SELECT id INTO v_profile_cmd      FROM public.profiles WHERE role = 'unit_command'   LIMIT 1;
  SELECT id INTO v_profile_unit_admin FROM public.profiles WHERE role = 'unit_admin'   LIMIT 1;
  SELECT id INTO v_profile_ttaa     FROM public.profiles WHERE role = 'ttaa'           LIMIT 1;
  SELECT id INTO v_unit_1_id        FROM public.units LIMIT 1 OFFSET 0;
  SELECT id INTO v_unit_2_id        FROM public.units LIMIT 1 OFFSET 1;

  -- Use any available profile if specific role not found
  IF v_profile_leader IS NULL THEN SELECT id INTO v_profile_leader FROM public.profiles LIMIT 1; END IF;
  IF v_profile_admin IS NULL THEN SELECT id INTO v_profile_admin FROM public.profiles LIMIT 1; END IF;
  IF v_profile_cmd IS NULL THEN SELECT id INTO v_profile_cmd FROM public.profiles LIMIT 1; END IF;
  IF v_profile_unit_admin IS NULL THEN SELECT id INTO v_profile_unit_admin FROM public.profiles LIMIT 1; END IF;
  IF v_profile_ttaa IS NULL THEN SELECT id INTO v_profile_ttaa FROM public.profiles LIMIT 1; END IF;

  -- Get resource IDs
  SELECT id INTO v_crew_id     FROM public.crew_members LIMIT 1;
  SELECT id INTO v_aircraft_id FROM public.aircraft    LIMIT 1;
  SELECT id INTO v_route_id    FROM public.routes      LIMIT 1;
  SELECT id INTO v_order_id    FROM public.flight_orders LIMIT 1;
  SELECT id INTO v_closure_id  FROM public.closure_requests LIMIT 1;
  SELECT id INTO v_user_id     FROM public.profiles    LIMIT 1 OFFSET 0;
  SELECT id INTO v_msg_id      FROM public.messages    LIMIT 1;

  -- Clean up any previous test data
  DELETE FROM public.audit_logs WHERE metadata->>'source' = 'test_seed';

  -- =====================================================
  -- CREW (Tripulación) — 5 events
  -- =====================================================
  INSERT INTO public.audit_logs (actor_id, actor_role, actor_unit_id, action, resource_type, resource_id, result, ip_address, metadata, created_at)
  VALUES
    (v_profile_cmd,    'unit_command',   v_unit_1_id, 'create',            'crew', v_crew_id,     'success', '192.168.10.5',  '{"source":"test_seed","detail":"Alta tripulante Sargento Perez"}',                        now() - interval '10 minutes'),
    (v_profile_cmd,    'unit_command',   v_unit_1_id, 'update',            'crew', v_crew_id,     'success', '192.168.10.5',  '{"source":"test_seed","detail":"Actualizacion calificaciones"}',                            now() - interval '1 hour'),
    (v_profile_unit_admin, 'unit_admin', v_unit_1_id, 'update',           'crew', v_crew_id,     'success', '192.168.10.8',  '{"source":"test_seed","detail":"Cambio de grado"}',                                          now() - interval '3 hours'),
    (v_profile_ttaa,   'ttaa',           v_unit_2_id, 'delete',           'crew', null,          'denied',  '192.168.20.3',  '{"source":"test_seed","detail":"TTAA no tiene permiso crew.manage"}',                     now() - interval '6 hours'),
    (v_profile_admin,  'general_admin',  null,        'deactivate',       'crew', v_crew_id,     'success', '172.16.0.1',    '{"source":"test_seed","detail":"Desactivacion de tripulante"}',                            now() - interval '2 days'),

  -- =====================================================
  -- AIRCRAFT (Aeronaves) — 4 events
  -- =====================================================
    (v_profile_unit_admin, 'unit_admin', v_unit_1_id, 'create',           'aircraft', v_aircraft_id, 'success', '192.168.10.20', '{"source":"test_seed","detail":"Registro de aeronave BELL-412"}',                        now() - interval '30 minutes'),
    (v_profile_cmd,    'unit_command',   v_unit_1_id, 'update',           'aircraft', v_aircraft_id, 'success', '192.168.10.5',  '{"source":"test_seed","detail":"Actualizacion horas de vuelo"}',                         now() - interval '12 hours'),
    (v_profile_ttaa,   'ttaa',           v_unit_2_id, 'create',           'aircraft', null,          'denied',  '192.168.20.3',  '{"source":"test_seed","detail":"TTAA no tiene aircraft.manage"}',                        now() - interval '1 day'),
    (v_profile_leader, 'leader',         null,        'deactivate',       'aircraft', v_aircraft_id, 'success', '10.0.0.50',     '{"source":"test_seed","detail":"Baja de aeronave por lider"}',                           now() - interval '2 days'),

  -- =====================================================
  -- ROUTE (Rutas) — 3 events
  -- =====================================================
    (v_profile_cmd,    'unit_command',   v_unit_1_id, 'create',           'route', v_route_id,   'success', '192.168.10.5',  '{"source":"test_seed","detail":"Nueva ruta Norte-Sur"}',                                  now() - interval '45 minutes'),
    (v_profile_admin,  'general_admin',  null,        'delete',           'route', v_route_id,   'success', '172.16.0.1',    '{"source":"test_seed","detail":"Eliminacion de ruta obsoleta"}',                         now() - interval '4 days'),
    (v_profile_unit_admin, 'unit_admin', v_unit_2_id, 'create',           'route', null,          'denied',  '192.168.20.8',  '{"source":"test_seed","detail":"No tiene routes.manage"}',                              now() - interval '5 days'),

  -- =====================================================
  -- FLIGHT_ORDER (Órdenes de Vuelo) — 6 events
  -- =====================================================
    (v_profile_unit_admin, 'unit_admin', v_unit_1_id, 'create',            'flight_order', v_order_id, 'success', '192.168.10.20', '{"source":"test_seed","detail":"OV #2026-042 creada"}',                                    now() - interval '20 minutes'),
    (v_profile_cmd,    'unit_command',   v_unit_1_id, 'submit',            'flight_order', v_order_id, 'success', '192.168.10.5',  '{"source":"test_seed","detail":"OV enviada a revision"}',                                   now() - interval '15 minutes'),
    (v_profile_leader, 'leader',         null,        'approve',           'flight_order', v_order_id, 'success', '10.0.0.50',     '{"source":"test_seed","detail":"OV aprobada por Lider"}',                                    now() - interval '10 minutes'),
    (v_profile_cmd,    'unit_command',   v_unit_2_id, 'submit',            'flight_order', null,       'denied',  '192.168.20.5',  '{"source":"test_seed","detail":"OV sin tripulacion minima"}',                               now() - interval '8 hours'),
    (v_profile_ttaa,   'ttaa',           v_unit_1_id, 'approve',           'flight_order', v_order_id, 'denied',  '192.168.10.3',  '{"source":"test_seed","detail":"TTAA no tiene flight_orders.review"}',                    now() - interval '1 day'),
    (v_profile_admin,  'general_admin',  null,        'close',             'flight_order', v_order_id, 'success', '172.16.0.1',    '{"source":"test_seed","detail":"Cierre de OV completado"}',                                now() - interval '3 days'),

  -- =====================================================
  -- ACCESS (Accesos / permisos de usuario) — 3 events
  -- =====================================================
    (v_profile_leader, 'leader',         null,        'grant_access',      'access', v_user_id,   'success', '10.0.0.50',     '{"source":"test_seed","detail":"Acceso concedido a nuevo TTAA"}',                           now() - interval '5 hours'),
    (v_profile_leader, 'leader',         null,        'revoke_access',     'access', v_user_id,   'success', '10.0.0.50',     '{"source":"test_seed","detail":"Acceso revocado por inactividad"}',                         now() - interval '2 days'),
    (v_profile_cmd,    'unit_command',   v_unit_1_id, 'grant_access',      'access', null,         'denied',  '192.168.10.5',  '{"source":"test_seed","detail":"unit_command no tiene users.assign_access"}',             now() - interval '6 days'),

  -- =====================================================
  -- AUTH (Autenticación) — 4 events
  -- =====================================================
    (v_profile_leader, 'leader',         null,        'login',             'auth', null,         'success', '10.0.0.50',     '{"source":"test_seed"}',                                                                     now() - interval '5 minutes'),
    (v_profile_cmd,    'unit_command',   v_unit_1_id, 'login',             'auth', null,         'success', '192.168.10.5',  '{"source":"test_seed"}',                                                                     now() - interval '1 hour'),
    (v_profile_ttaa,   'ttaa',           v_unit_2_id, 'login',             'auth', null,         'failed',  '192.168.20.99', '{"source":"test_seed","detail":"Contrasena incorrecta - intento 3"}',                     now() - interval '4 hours'),
    (v_profile_admin,  'general_admin',  null,        'password_reset',    'auth', null,         'success', '172.16.0.1',    '{"source":"test_seed","detail":"Reseteo de contrasena exitoso"}',                        now() - interval '3 days'),

  -- =====================================================
  -- PERMISSION (Permisos) — 2 events
  -- =====================================================
    (v_profile_leader, 'leader',         null,        'update_permissions','permission', null,   'success', '10.0.0.50',     '{"source":"test_seed","detail":"Permiso audit.read agregado a unit_command"}',            now() - interval '1 day'),
    (v_profile_admin,  'general_admin',  null,        'update_permissions','permission', null,   'denied',  '172.16.0.1',    '{"source":"test_seed","detail":"Admin no tiene permissions.manage"}',                   now() - interval '7 days'),

  -- =====================================================
  -- USER (Usuarios) — 2 events
  -- =====================================================
    (v_profile_leader, 'leader',         null,        'update_role',       'user', v_user_id,    'success', '10.0.0.50',     '{"source":"test_seed","detail":"Rol cambiado de unit_admin a unit_command"}',            now() - interval '8 hours'),
    (v_profile_admin,  'general_admin',  null,        'update_status',     'user', v_user_id,    'success', '172.16.0.1',    '{"source":"test_seed","detail":"Usuario marcado como inactivo"}',                       now() - interval '3 days'),

  -- =====================================================
  -- SETTINGS (Configuración) — 1 event
  -- =====================================================
    (v_profile_leader, 'leader',         null,        'update_config',     'settings', null,      'success', '10.0.0.50',     '{"source":"test_seed","detail":"Configuracion de notificaciones actualizada"}',          now() - interval '1 day'),

  -- =====================================================
  -- REPORT (Reportes) — 1 event
  -- =====================================================
    (v_profile_admin,  'general_admin',  null,        'export_pdf',        'report', v_order_id,  'success', '172.16.0.1',    '{"source":"test_seed","detail":"Exportacion PDF de OV #2026-042"}',                      now() - interval '2 hours'),

  -- =====================================================
  -- CLOSURE (Cierres) — 2 events
  -- =====================================================
    (v_profile_cmd,    'unit_command',   v_unit_2_id, 'request_closure',   'closure', v_closure_id,'success', '192.168.20.5',  '{"source":"test_seed","detail":"Solicitud de cierre por condiciones meteorologicas"}',   now() - interval '4 hours'),
    (v_profile_leader, 'leader',         null,        'approve_closure',   'closure', v_closure_id,'success', '10.0.0.50',     '{"source":"test_seed","detail":"Cierre aprobado por Lider"}',                           now() - interval '3 hours'),

  -- =====================================================
  -- NOTIFICATION (Notificaciones) — 1 event
  -- =====================================================
    (v_profile_leader, 'leader',         null,        'broadcast',         'notification', null,   'success', '10.0.0.50',     '{"source":"test_seed","detail":"Aviso general: mantenimiento programado"}',              now() - interval '6 hours');

  RAISE NOTICE 'Test audit data inserted successfully';
END $$;
