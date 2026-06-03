-- Enable Supabase Realtime for internal messages.
-- RLS remains the source of truth for row visibility.

alter table public.messages replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication p
    join pg_publication_rel pr on pr.prpubid = p.oid
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
exception
  when undefined_object then
    create publication supabase_realtime;
    alter publication supabase_realtime add table public.messages;
end $$;
