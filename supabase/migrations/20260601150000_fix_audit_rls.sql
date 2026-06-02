-- Fix audit RLS: use existing unit-scoping functions instead of JWT claims
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
