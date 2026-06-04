-- Mensajeria dual: chat privado + publicaciones institucionales.
-- Chat privado deja de ser visible para roles globales si no son participantes.

insert into public.permissions (key, description, module)
values
  ('message_posts.read', 'Leer publicaciones internas', 'messages'),
  ('message_posts.create', 'Crear publicaciones internas', 'messages'),
  ('message_posts.comment', 'Comentar publicaciones internas', 'messages')
on conflict (key) do update
set description = excluded.description,
    module = excluded.module,
    active = true;

insert into public.role_permissions (role, permission_id, enabled)
select role_name::public.app_role, p.id, true
from public.permissions p
cross join (
  values
    ('leader'),
    ('general_admin'),
    ('unit_command'),
    ('unit_admin'),
    ('ttaa')
) as roles(role_name)
where p.key in ('message_posts.read', 'message_posts.comment')
on conflict (role, permission_id) do update set enabled = excluded.enabled;

insert into public.role_permissions (role, permission_id, enabled)
select role_name::public.app_role, p.id, true
from public.permissions p
cross join (
  values
    ('leader'),
    ('general_admin'),
    ('unit_command'),
    ('unit_admin')
) as roles(role_name)
where p.key = 'message_posts.create'
on conflict (role, permission_id) do update set enabled = excluded.enabled;

create table if not exists public.message_reads (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (message_id, profile_id)
);

create table if not exists public.message_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id),
  scope text not null check (scope in ('global', 'unit')),
  unit_id uuid references public.units(id),
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint message_posts_scope_unit_check check (
    (scope = 'global' and unit_id is null)
    or (scope = 'unit' and unit_id is not null)
  )
);

create table if not exists public.message_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.message_posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id),
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.message_post_reads (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.message_posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (post_id, profile_id)
);

create index if not exists messages_private_participants_idx
on public.messages(sender_id, recipient_id, created_at desc);

create index if not exists message_reads_message_profile_idx
on public.message_reads(message_id, profile_id);

create index if not exists message_posts_scope_created_idx
on public.message_posts(scope, unit_id, created_at desc)
where deleted_at is null;

create index if not exists message_post_comments_post_created_idx
on public.message_post_comments(post_id, created_at)
where deleted_at is null;

create index if not exists message_post_reads_post_profile_idx
on public.message_post_reads(post_id, profile_id);

alter table public.message_reads enable row level security;
alter table public.message_posts enable row level security;
alter table public.message_post_comments enable row level security;
alter table public.message_post_reads enable row level security;

drop policy if exists "messages_read_own_or_unit" on public.messages;
create policy "messages_read_private_participants"
on public.messages
for select
to authenticated
using (
  public.has_permission('messages.read')
  and (
    sender_id = auth.uid()
    or recipient_id = auth.uid()
  )
);

drop policy if exists "messages_insert_authorized" on public.messages;
create policy "messages_insert_private_authorized"
on public.messages
for insert
to authenticated
with check (
  public.has_permission('messages.send')
  and sender_id = auth.uid()
  and recipient_id is not null
  and recipient_id <> auth.uid()
  and unit_id is null
);

drop policy if exists "message_reads_select_visible" on public.message_reads;
create policy "message_reads_select_visible"
on public.message_reads
for select
to authenticated
using (
  public.has_permission('messages.read')
  and (
    profile_id = auth.uid()
    or exists (
      select 1
      from public.messages m
      where m.id = message_reads.message_id
        and m.sender_id = auth.uid()
    )
  )
);

drop policy if exists "message_reads_upsert_own_inbound" on public.message_reads;
create policy "message_reads_upsert_own_inbound"
on public.message_reads
for insert
to authenticated
with check (
  public.has_permission('messages.read')
  and profile_id = auth.uid()
  and exists (
    select 1
    from public.messages m
    where m.id = message_reads.message_id
      and m.recipient_id = auth.uid()
  )
);

drop policy if exists "message_reads_update_own" on public.message_reads;
create policy "message_reads_update_own"
on public.message_reads
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "message_posts_read_by_scope" on public.message_posts;
create policy "message_posts_read_by_scope"
on public.message_posts
for select
to authenticated
using (
  deleted_at is null
  and public.has_permission('message_posts.read')
  and (
    scope = 'global'
    or public.is_global_role()
    or (scope = 'unit' and public.same_unit(unit_id))
  )
);

drop policy if exists "message_posts_insert_authorized" on public.message_posts;
create policy "message_posts_insert_authorized"
on public.message_posts
for insert
to authenticated
with check (
  public.has_permission('message_posts.create')
  and author_id = auth.uid()
  and (
    (scope = 'global' and unit_id is null and public.is_global_role())
    or (
      scope = 'unit'
      and unit_id is not null
      and (public.is_global_role() or public.same_unit(unit_id))
    )
  )
);

drop policy if exists "message_post_comments_read_by_post_scope" on public.message_post_comments;
create policy "message_post_comments_read_by_post_scope"
on public.message_post_comments
for select
to authenticated
using (
  deleted_at is null
  and public.has_permission('message_posts.read')
  and exists (
    select 1
    from public.message_posts p
    where p.id = message_post_comments.post_id
      and p.deleted_at is null
      and (
        p.scope = 'global'
        or public.is_global_role()
        or (p.scope = 'unit' and public.same_unit(p.unit_id))
      )
  )
);

drop policy if exists "message_post_comments_insert_authorized" on public.message_post_comments;
create policy "message_post_comments_insert_authorized"
on public.message_post_comments
for insert
to authenticated
with check (
  public.has_permission('message_posts.comment')
  and author_id = auth.uid()
  and exists (
    select 1
    from public.message_posts p
    where p.id = message_post_comments.post_id
      and p.deleted_at is null
      and (
        p.scope = 'global'
        or public.is_global_role()
        or (p.scope = 'unit' and public.same_unit(p.unit_id))
      )
  )
);

drop policy if exists "message_post_reads_select_by_post_scope" on public.message_post_reads;
create policy "message_post_reads_select_by_post_scope"
on public.message_post_reads
for select
to authenticated
using (
  public.has_permission('message_posts.read')
  and exists (
    select 1
    from public.message_posts p
    where p.id = message_post_reads.post_id
      and p.deleted_at is null
      and (
        p.scope = 'global'
        or public.is_global_role()
        or (p.scope = 'unit' and public.same_unit(p.unit_id))
      )
  )
);

drop policy if exists "message_post_reads_upsert_own_visible" on public.message_post_reads;
create policy "message_post_reads_upsert_own_visible"
on public.message_post_reads
for insert
to authenticated
with check (
  public.has_permission('message_posts.read')
  and profile_id = auth.uid()
  and exists (
    select 1
    from public.message_posts p
    where p.id = message_post_reads.post_id
      and p.deleted_at is null
      and (
        p.scope = 'global'
        or public.is_global_role()
        or (p.scope = 'unit' and public.same_unit(p.unit_id))
      )
  )
);

drop policy if exists "message_post_reads_update_own" on public.message_post_reads;
create policy "message_post_reads_update_own"
on public.message_post_reads
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "profiles_read_messaging_directory" on public.profiles;
create policy "profiles_read_messaging_directory"
on public.profiles
for select
to authenticated
using (
  public.has_permission('messages.send')
  and status = 'active'
  and (
    id = auth.uid()
    or public.is_global_role()
    or public.same_unit(unit_id)
  )
);

drop policy if exists "profiles_read_message_post_authors" on public.profiles;
create policy "profiles_read_message_post_authors"
on public.profiles
for select
to authenticated
using (
  public.has_permission('message_posts.read')
  and status = 'active'
  and (
    id = auth.uid()
    or role in ('leader', 'general_admin')
    or public.same_unit(unit_id)
  )
);

alter table public.message_reads replica identity full;
alter table public.message_posts replica identity full;
alter table public.message_post_comments replica identity full;
alter table public.message_post_reads replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;

  if not exists (
    select 1
    from pg_publication p
    join pg_publication_rel pr on pr.prpubid = p.oid
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'message_reads'
  ) then
    alter publication supabase_realtime add table public.message_reads;
  end if;

  if not exists (
    select 1
    from pg_publication p
    join pg_publication_rel pr on pr.prpubid = p.oid
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'message_posts'
  ) then
    alter publication supabase_realtime add table public.message_posts;
  end if;

  if not exists (
    select 1
    from pg_publication p
    join pg_publication_rel pr on pr.prpubid = p.oid
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'message_post_comments'
  ) then
    alter publication supabase_realtime add table public.message_post_comments;
  end if;

  if not exists (
    select 1
    from pg_publication p
    join pg_publication_rel pr on pr.prpubid = p.oid
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'message_post_reads'
  ) then
    alter publication supabase_realtime add table public.message_post_reads;
  end if;
end $$;
