insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'crew-photos',
  'crew-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "crew_photos_insert_auth" on storage.objects;
create policy "crew_photos_insert_auth" on storage.objects
for insert to authenticated
with check (bucket_id = 'crew-photos');

drop policy if exists "crew_photos_read_public" on storage.objects;
create policy "crew_photos_read_public" on storage.objects
for select to public
using (bucket_id = 'crew-photos');

drop policy if exists "crew_photos_update_auth" on storage.objects;
create policy "crew_photos_update_auth" on storage.objects
for update to authenticated
using (bucket_id = 'crew-photos')
with check (bucket_id = 'crew-photos');

drop policy if exists "crew_photos_delete_auth" on storage.objects;
create policy "crew_photos_delete_auth" on storage.objects
for delete to authenticated
using (bucket_id = 'crew-photos');
