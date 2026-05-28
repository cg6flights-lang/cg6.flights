-- Insert routes permissions
INSERT INTO public.permissions (key, description, module)
VALUES
  ('routes.read', 'Leer rutas', 'routes'),
  ('routes.manage', 'Administrar rutas', 'routes')
ON CONFLICT (key) DO UPDATE
SET description = excluded.description,
    module = excluded.module,
    active = true;

-- Leader already gets ALL permissions (seed.sql line 50-53)

-- Grant routes.manage + routes.read to general_admin
INSERT INTO public.role_permissions (role, permission_id, enabled)
SELECT 'general_admin'::public.app_role, id, true
FROM public.permissions
WHERE key IN ('routes.read', 'routes.manage')
ON CONFLICT (role, permission_id) DO UPDATE SET enabled = excluded.enabled;

-- Grant routes.read to unit_command
INSERT INTO public.role_permissions (role, permission_id, enabled)
SELECT 'unit_command'::public.app_role, id, true
FROM public.permissions
WHERE key IN ('routes.read')
ON CONFLICT (role, permission_id) DO UPDATE SET enabled = excluded.enabled;

-- Grant routes.read to unit_admin
INSERT INTO public.role_permissions (role, permission_id, enabled)
SELECT 'unit_admin'::public.app_role, id, true
FROM public.permissions
WHERE key IN ('routes.read')
ON CONFLICT (role, permission_id) DO UPDATE SET enabled = excluded.enabled;

-- Grant routes.read to ttaa
INSERT INTO public.role_permissions (role, permission_id, enabled)
SELECT 'ttaa'::public.app_role, id, true
FROM public.permissions
WHERE key IN ('routes.read')
ON CONFLICT (role, permission_id) DO UPDATE SET enabled = excluded.enabled;
