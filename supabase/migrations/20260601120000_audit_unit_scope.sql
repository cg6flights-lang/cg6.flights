-- Audit logs: unit-scoped RLS + automatic 2-month retention cleanup

-- Update RLS to restrict unitCommand to their own unit
drop policy if exists "audit_read_authorized" on public.audit_logs;
create policy "audit_read_authorized"
on public.audit_logs
for select
to authenticated
using (
  public.has_permission('audit.read')
  and (
    public.is_global_role()
    or (actor_unit_id is not null and public.same_unit(actor_unit_id))
  )
);

-- Cleanup function: delete audit logs older than 2 months
create or replace function public.cleanup_old_audit_logs()
returns void as $$
begin
  delete from public.audit_logs
  where created_at < now() - interval '2 months';
end;
$$ language plpgsql security definer;

-- Enable pg_cron extension (required for scheduled jobs)
create extension if not exists pg_cron with schema extensions;

-- Schedule cleanup every day at 03:00 UTC
select cron.schedule(
  'cleanup-audit-logs',
  '0 3 * * *',
  'select public.cleanup_old_audit_logs();'
);
