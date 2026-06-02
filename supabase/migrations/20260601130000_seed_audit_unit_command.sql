-- Seed: grant audit.read permission to unit_command
insert into public.role_permissions (role, permission_id, enabled)
select 'unit_command'::public.app_role, id, true
from public.permissions
where key = 'audit.read'
on conflict (role, permission_id) do update set enabled = excluded.enabled;
