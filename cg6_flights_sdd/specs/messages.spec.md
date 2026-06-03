# Modulo: Mensajes

## Estado
Implementado v1.1 — Mensajería dual realtime.

## Responsabilidad
La ruta `/messages` concentra dos experiencias internas:

- **Chat privado realtime**: conversaciones 1:1 estilo WhatsApp/Telegram entre usuarios activos, con mensajes alineados por remitente y confirmación de visto por mensaje.
- **Publicaciones operacionales**: muro tipo Twitter/X para avisos globales o por unidad, con comentarios y confirmación de lectura/recepción.

## No responsabilidad
- No maneja adjuntos en v1.1.
- No maneja indicador real de escritura en v1.1.
- No maneja presencia real; los indicadores visuales son informativos.
- No sustituye al módulo de Notificaciones ni a la auditoría.

## Entidades

### messages

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid | PK |
| sender_id | uuid → profiles | Remitente |
| recipient_id | uuid → profiles | Destinatario privado obligatorio en chat |
| unit_id | uuid → units | Debe ser null para chat privado v1.1 |
| subject | text | Asunto técnico, por defecto `Chat` |
| body | text | Cuerpo del mensaje |
| created_at | timestamptz | Fecha de envío |

### message_reads

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid | PK |
| message_id | uuid → messages | Mensaje visto |
| profile_id | uuid → profiles | Usuario que leyó |
| read_at | timestamptz | Fecha de lectura |
| created_at | timestamptz | Fecha de registro |

Unique: `(message_id, profile_id)`.

### message_posts

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid | PK |
| author_id | uuid → profiles | Autor |
| scope | text | `global` o `unit` |
| unit_id | uuid → units | Unidad destino cuando scope=`unit` |
| body | text | Contenido de la publicación |
| created_at | timestamptz | Fecha de creación |
| updated_at | timestamptz | Fecha de actualización |
| deleted_at | timestamptz | Soft delete futuro |

### message_post_comments

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid | PK |
| post_id | uuid → message_posts | Publicación |
| author_id | uuid → profiles | Autor del comentario |
| body | text | Comentario |
| created_at | timestamptz | Fecha |
| deleted_at | timestamptz | Soft delete futuro |

### message_post_reads

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid | PK |
| post_id | uuid → message_posts | Publicación confirmada |
| profile_id | uuid → profiles | Usuario que confirmó lectura |
| read_at | timestamptz | Fecha de confirmación |
| created_at | timestamptz | Fecha de registro |

Unique: `(post_id, profile_id)`.

## Casos de uso

| ID | Nombre | Actor | Permiso | Descripción |
|---|---|---|---|---|
| UC-MSG01 | Enviar chat privado | Usuario autorizado | messages.send | Envía un mensaje a otro usuario activo |
| UC-MSG02 | Ver conversaciones privadas | Usuario autorizado | messages.read | Lista solo chats donde participa |
| UC-MSG03 | Recibir chat realtime | Usuario autorizado | messages.read | Recibe inserts visibles por RLS sin refrescar |
| UC-MSG04 | Marcar mensaje visto | Destinatario | messages.read | Al abrir el chat registra `message_reads` |
| UC-MSG05 | Crear publicación | leader, generalAdmin, unitCommand, unitAdmin | message_posts.create | Publica aviso global o de unidad según alcance |
| UC-MSG06 | Leer publicaciones | Usuario activo | message_posts.read | Ve publicaciones globales y/o de su unidad |
| UC-MSG07 | Comentar publicación | Usuario activo | message_posts.comment | Comenta una publicación visible |
| UC-MSG08 | Confirmar lectura de publicación | Usuario activo | message_posts.read | Registra recepción en `message_post_reads` |

## Permisos

| Permiso | Roles |
|---|---|
| messages.read | leader, generalAdmin, unitCommand, unitAdmin, ttaa |
| messages.send | leader, generalAdmin, unitCommand, unitAdmin |
| message_posts.read | leader, generalAdmin, unitCommand, unitAdmin, ttaa |
| message_posts.create | leader, generalAdmin, unitCommand, unitAdmin |
| message_posts.comment | leader, generalAdmin, unitCommand, unitAdmin, ttaa |

## RLS

- `messages` SELECT: solo `sender_id = auth.uid()` o `recipient_id = auth.uid()`. Ningún rol global puede leer chats privados ajenos.
- `messages` INSERT: requiere `messages.send`, `sender_id = auth.uid()`, `recipient_id` no nulo, destinatario distinto al remitente y `unit_id is null`.
- `message_reads` SELECT: el lector ve sus propios registros; el remitente ve lecturas sobre sus mensajes enviados.
- `message_reads` INSERT/UPDATE: solo el usuario autenticado puede registrar su propia lectura de mensajes entrantes.
- `message_posts` SELECT: requiere `message_posts.read`; scope global visible para todos los roles activos, scope unidad visible para roles globales o misma unidad.
- `message_posts` INSERT: requiere `message_posts.create`; global solo leader/generalAdmin; unidad para roles globales o roles de la misma unidad.
- `message_post_comments` SELECT/INSERT: permitido solo sobre publicaciones visibles; INSERT requiere `message_posts.comment`.
- `message_post_reads` SELECT/INSERT/UPDATE: permitido solo sobre publicaciones visibles; cada usuario confirma su propia lectura.

## Realtime

Tablas incluidas en `supabase_realtime` con RLS:

- `messages`
- `message_reads`
- `message_posts`
- `message_post_comments`
- `message_post_reads`

La UI debe usar streams filtrados por RLS. Realtime no reemplaza validaciones, permisos ni auditoría.

## Edge Functions

### manage-message-post

Acciones:

- `create_post`: crea publicación global o de unidad.
- `add_comment`: crea comentario sobre publicación visible.

Reglas:

- Valida JWT, perfil activo, rol, permiso y alcance.
- Usa service role solo dentro de Edge Function.
- Audita éxito, denegación y fallas relevantes.
- Responde con contrato normalizado `{ ok, data/error }`.

## UI

- Primera columna: selector de modo `Chat` / `Publicaciones`, indicador realtime, refresh y permisos visuales.
- Modo Chat:
  - segunda columna con conversaciones por usuario, nombre claro, último mensaje, hora, no leídos y estado activo visual;
  - tercera columna con header del contacto, burbujas izquierda/derecha, composer inferior y ticks de enviado/visto;
  - acción `Nuevo chat` visible solo con `messages.send`.
- Modo Publicaciones:
  - la segunda columna se oculta;
  - el timeline ocupa el espacio central;
  - composer superior visible solo con `message_posts.create`;
  - selector de alcance global/unidad según rol;
  - cards con autor, rol, unidad/scope, fecha, comentarios, vistos y confirmación de lectura.
- Responsive: desktop multipanel; móvil cambia entre lista/detalle para chat y timeline compacto para publicaciones.

## Errores

| Código | Categoría | Escenario |
|---|---|---|
| MESSAGES_LOAD_FAILED | data | Fallo al cargar mensajes o streams |
| MESSAGE_SEND_FAILED | data | Fallo al enviar chat |
| MESSAGE_READ_FAILED | data | Fallo al registrar visto de chat |
| MESSAGE_POST_SAVE_FAILED | system | Fallo general de publicación/comentario |
| MESSAGE_POST_READ_FAILED | data | Fallo al confirmar lectura de publicación |

## Tests requeridos

- Widget test: selector Chat/Publicaciones, estado vacío, `Nuevo chat` condicional.
- Unit test: modelos `Message`, `MessageRead`, `MessagePost`, `MessagePostComment`, `MessagePostRead`.
- RLS test: usuario C no puede ver chat privado A-B.
- RLS test: TTAA no puede crear publicación principal pero sí comentar y confirmar lectura.
- Realtime test manual: dos sesiones ven chat, vistos, publicaciones y comentarios sin refrescar.
