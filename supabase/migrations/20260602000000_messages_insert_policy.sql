-- Messages: INSERT policy for authorized senders
create policy "messages_insert_authorized"
on public.messages
for insert
to authenticated
with check (public.has_permission('messages.send'));
