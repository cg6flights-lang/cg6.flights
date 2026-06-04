insert into public.permissions (key, description, module)
values
  ('users.read', 'Leer usuarios autorizados', 'users'),
  ('users.manage', 'Administrar usuarios', 'users'),
  ('users.assign_access', 'Asignar rol, unidad y estado', 'users'),
  ('roles.read', 'Leer roles oficiales', 'roles'),
  ('permissions.read', 'Leer permisos', 'permissions'),
  ('permissions.manage', 'Administrar permisos por rol', 'permissions'),
  ('units.read', 'Leer unidades autorizadas', 'units'),
  ('units.manage', 'Administrar unidades', 'units'),
  ('aircraft.read', 'Leer aeronaves', 'aircraft'),
  ('aircraft.manage', 'Administrar aeronaves', 'aircraft'),
  ('crew.read', 'Leer tripulacion', 'crew'),
  ('crew.manage', 'Administrar tripulacion', 'crew'),
  ('flight_orders.read', 'Leer ordenes de vuelo', 'flight_orders'),
  ('flight_orders.create', 'Crear ordenes de vuelo', 'flight_orders'),
  ('flight_orders.review', 'Revisar ordenes de vuelo', 'flight_orders'),
  ('flight_orders.close', 'Cerrar ordenes de vuelo', 'flight_orders'),
  ('flights.read', 'Leer vuelos', 'flights'),
  ('flights.create', 'Crear vuelos', 'flights'),
  ('flights.update', 'Actualizar vuelos', 'flights'),
  ('flight_status.create', 'Crear eventos de estado', 'flight_status'),
  ('closures.request', 'Solicitar cierres', 'closures'),
  ('closures.review', 'Revisar cierres', 'closures'),
  ('closures.reopen', 'Reabrir cierres', 'closures'),
  ('history.read', 'Leer historicos', 'history'),
  ('audit.read', 'Leer auditoria', 'audit'),
  ('notifications.read', 'Leer notificaciones', 'notifications'),
  ('notifications.manage', 'Administrar notificaciones', 'notifications'),
  ('messages.read', 'Leer mensajes', 'messages'),
  ('messages.send', 'Enviar mensajes', 'messages'),
  ('message_posts.read', 'Leer publicaciones internas', 'messages'),
  ('message_posts.create', 'Crear publicaciones internas', 'messages'),
  ('message_posts.comment', 'Comentar publicaciones internas', 'messages'),
  ('reports.read', 'Leer reportes', 'reports'),
  ('reports.export', 'Exportar reportes', 'reports'),
  ('calendar.read', 'Leer calendario', 'calendar'),
  ('calendar.manage', 'Gestionar actividades del calendario', 'calendar'),
  ('routes.read', 'Leer rutas', 'routes'),
  ('routes.manage', 'Administrar rutas', 'routes'),
  ('maps.read', 'Leer mapas', 'maps'),
  ('profile.update', 'Actualizar perfil', 'profile'),
  ('settings.manage', 'Administrar configuracion', 'settings')
on conflict (key) do update
set description = excluded.description,
    module = excluded.module,
    active = true;

insert into public.units (code, name)
values ('LPA-DEMO', 'Base Aerea Las Palmas Demo')
on conflict (code) do update
set name = excluded.name,
    active = true;

insert into public.role_permissions (role, permission_id, enabled)
select 'leader'::public.app_role, id, true
from public.permissions
on conflict (role, permission_id) do update set enabled = excluded.enabled;

insert into public.role_permissions (role, permission_id, enabled)
select 'general_admin'::public.app_role, id, true
from public.permissions
where key in (
  'users.read',
  'roles.read',
  'permissions.read',
  'units.read',
  'aircraft.read',
  'crew.read',
  'routes.read',
  'routes.manage',
  'flight_orders.read',
  'flight_orders.review',
  'flights.read',
  'closures.review',
  'history.read',
  'audit.read',
  'notifications.read',
  'messages.read',
  'messages.send',
  'message_posts.read',
  'message_posts.create',
  'message_posts.comment',
  'reports.read',
  'reports.export',
  'calendar.read',
  'calendar.manage',
  'maps.read',
  'profile.update'
)
on conflict (role, permission_id) do update set enabled = excluded.enabled;

insert into public.role_permissions (role, permission_id, enabled)
select 'unit_command'::public.app_role, id, true
from public.permissions
where key in (
  'users.read',
  'units.read',
  'aircraft.read',
  'crew.read',
  'routes.read',
  'flight_orders.read',
  'flight_orders.review',
  'flight_orders.close',
  'flights.read',
  'closures.review',
  'audit.read',
  'history.read',
  'notifications.read',
  'messages.read',
  'messages.send',
  'message_posts.read',
  'message_posts.create',
  'message_posts.comment',
  'reports.read',
  'calendar.read',
  'maps.read',
  'profile.update'
)
on conflict (role, permission_id) do update set enabled = excluded.enabled;

insert into public.role_permissions (role, permission_id, enabled)
select 'unit_admin'::public.app_role, id, true
from public.permissions
where key in (
  'units.read',
  'aircraft.read',
  'aircraft.manage',
  'crew.read',
  'crew.manage',
  'routes.read',
  'flight_orders.read',
  'flight_orders.create',
  'flights.read',
  'flights.create',
  'flights.update',
  'flight_status.create',
  'closures.request',
  'history.read',
  'notifications.read',
  'messages.read',
  'messages.send',
  'message_posts.read',
  'message_posts.create',
  'message_posts.comment',
  'reports.read',
  'calendar.read',
  'maps.read',
  'profile.update'
)
on conflict (role, permission_id) do update set enabled = excluded.enabled;

insert into public.role_permissions (role, permission_id, enabled)
select 'ttaa'::public.app_role, id, true
from public.permissions
where key in (
  'flights.read',
  'flight_status.create',
  'notifications.read',
  'messages.read',
  'message_posts.read',
  'message_posts.comment',
  'calendar.read',
  'maps.read',
  'profile.update'
)
on conflict (role, permission_id) do update set enabled = excluded.enabled;
