-- Leader role needs routes permissions explicitly because seed.sql only runs once
-- and leader's "all permissions" grant via seed doesn't auto-update for new permissions
INSERT INTO public.role_permissions (role, permission_id, enabled)
SELECT 'leader'::public.app_role, id, true
FROM public.permissions
WHERE key IN ('routes.read', 'routes.manage')
  AND NOT EXISTS (
    SELECT 1 FROM public.role_permissions rp
    WHERE rp.role = 'leader' AND rp.permission_id = public.permissions.id
  );
