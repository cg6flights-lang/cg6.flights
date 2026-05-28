DO $$
DECLARE
  perm_id uuid;
BEGIN
  -- Insert routes.read if missing
  IF NOT EXISTS (SELECT 1 FROM public.permissions WHERE key = 'routes.read') THEN
    INSERT INTO public.permissions (key, description, module)
    VALUES ('routes.read', 'Leer rutas', 'routes')
    RETURNING id INTO perm_id;
  ELSE
    SELECT id INTO perm_id FROM public.permissions WHERE key = 'routes.read';
  END IF;

  -- Assign to roles that don't have it yet
  INSERT INTO public.role_permissions (role, permission_id, enabled)
  SELECT r.role, perm_id, true
  FROM (VALUES
    ('general_admin'::public.app_role),
    ('unit_command'::public.app_role),
    ('unit_admin'::public.app_role),
    ('ttaa'::public.app_role)
  ) AS r(role)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.role_permissions rp
    WHERE rp.role = r.role AND rp.permission_id = perm_id
  );

  -- Insert routes.manage if missing
  IF NOT EXISTS (SELECT 1 FROM public.permissions WHERE key = 'routes.manage') THEN
    INSERT INTO public.permissions (key, description, module)
    VALUES ('routes.manage', 'Administrar rutas', 'routes')
    RETURNING id INTO perm_id;
  ELSE
    SELECT id INTO perm_id FROM public.permissions WHERE key = 'routes.manage';
  END IF;

  -- Leader gets ALL permissions (handled by existing seed logic that gives leader everything)
  -- Assign routes.manage to general_admin
  INSERT INTO public.role_permissions (role, permission_id, enabled)
  SELECT 'general_admin'::public.app_role, perm_id, true
  WHERE NOT EXISTS (
    SELECT 1 FROM public.role_permissions rp
    WHERE rp.role = 'general_admin' AND rp.permission_id = perm_id
  );
END $$;
