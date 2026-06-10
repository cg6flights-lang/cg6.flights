# Prompt para Codex: Rediseño Tripulaciones — Header fijo + Hoja de Vida

## Contexto

CG6 Flights es una plataforma Flutter Web + Supabase para gestión de vuelos militares. Stack: Flutter 3.44, Riverpod 3.x, GoRouter, Supabase.

## Objetivo

Reescribir la página de Tripulaciones (`crew_page.dart`, 850+ líneas) con layout de header fijo + scroll independiente. Además, crear un modal "Hoja de Vida" al hacer clic en un tripulante.

---

## 1. Reescribir `lib/features/crew/presentation/crew_page.dart`

### Layout

```
┌─────────────────────────────────────────┐
│ 👥 Tripulaciones          [+ Agregar]   │ ← Fijo (NO scrollea)
│ [EDACI] [GRU51] [GRU31]                │ ← Fijo (chips de unidad)
│ [EA 510] [EA 511] [EA 512] [EA 513]   │ ← Fijo (chips escuadrón, solo GRU51)
├─────────────────────────────────────────┤
│ ┌─ Pilotos (5) ────────────────────┐   │
│ │ Grado│Nombres│Apellidos│NSA      │   │ ← DataTable (solo columnas esenciales)
│ │ MAY  │Juan   │Pérez    │NSA-001  │   │ ← Solo esto scrollea ↑↓
│ │ CAP  │María  │López    │NSA-002  │   │ ← Clic en fila → abre modal
│ └──────────────────────────────────┘   │
│ ┌─ Mecánicos (2) ──────────────────┐   │
│ │ TCO  │Pedro  │Ríos     │NSA-003  │   │
│ └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Requisitos técnicos

- **Estructura**: `Column` → header fijo + filtros fijos + `Expanded` → `SingleChildScrollView` con las secciones Pilotos/Mecánicos
- Cada sección: Card con título + DataTable. El DataTable tiene su propio header sticky (comportamiento nativo de Flutter)
- **Columnas de la tabla**: solo Grado, Nombres, Apellidos, NSA (eliminar Tipo Asignación, Calificaciones, Fecha Nombramiento, etc.)
- Mantener la funcionalidad existente de filtros (unidad por chips, escuadrón por chips GRU51)
- Mantener el botón "+" para agregar tripulante (abre el form dialog actual)
- Al hacer clic en una fila → abrir `showCrewDetailModal(context, member, ref)`
- Los filtros de unidad y escuadrón deben seguir funcionando igual
- La lista de tripulantes debe filtrarse por unidad/escuadrón seleccionados

### Dependencias ya existentes que se deben mantener

- `_crewListProvider` (FutureProvider que carga tripulantes)
- `_unitsProvider` y `_gradesProvider`
- `sessionControllerProvider` para permisos
- `squadronRepositoryProvider` para cargar escuadrones
- Chips de unidad con `ChoiceChip` y escuadrón con `FilterChip` + divisor animado
- Lógica de auto-selección de primera unidad por defecto

---

## 2. Crear `lib/features/crew/presentation/crew_detail_modal.dart`

Modal grande (90% ancho, 85% alto) con **TabBar** de 4 tabs:

### Tab "Perfil"

- Foto del tripulante (subir con FileUploadInputElement + resize a 5MB como el avatar de perfil en `profile_modal.dart`)
- Formulario editable: Grado (dropdown), Nombres, Apellidos, NSA, Unidad, Escuadrón
- Botón "Guardar Cambios" y botón "Eliminar" (con confirmación)
- Usar `crew_repository.saveCrewMember()` para guardar y `crew_repository.deactivateCrewMember()` para eliminar

### Tab "Horas"

- KPIs: horas de vuelo (semana, mes, año) — usar RPC `get_aircraft_flight_hours` o consultar `flights` + `flight_status_events`
- DataTable con últimos vuelos: Fecha, Aeronave, Misión, ETE, Calificación
- Los datos vienen de `flights` donde el tripulante aparece en `flight_crew`

### Tab "Aeronaves"

- Lista de modelos de aeronave en los que el tripulante ha volado (obtener de `flights` JOIN `aircraft`)
- Mostrar como chips: ✓ habilitado / ☐ no habilitado

### Tab "Calificaciones"

- Mostrar las calificaciones del tripulante (`qualifications` array en `crew_members`): IP, PS, CO, PM, CP, OB
- Chips toggle para activar/desactivar (guardar al cambiar)

---

## 3. Foto del tripulante

- Columna `photo_path` ya existe en `crew_members` (migración 20260611000000)
- Campo `photoPath` en `CrewMember` (domain model)
- Mismo sistema de upload que `profile_modal.dart`:
  - `html.FileUploadInputElement` → `readAsDataUrl` → `base64Decode`
  - `_resizeToMaxSize` con Canvas API para limitar a 5MB
  - Subir a Supabase Storage bucket `crew-photos`
- Mostrar la foto en el modal (circular, 120x120)

---

## Archivos a modificar/crear

| Archivo | Acción |
|---|---|
| `lib/features/crew/presentation/crew_page.dart` | Reescribir layout |
| `lib/features/crew/presentation/crew_detail_modal.dart` | Crear |
| `lib/features/crew/data/crew_repository.dart` | Agregar `uploadCrewPhoto()` si no existe |

## Verificación

- `flutter analyze` 0 errores
- Header y filtros NO se mueven al hacer scroll
- Solo la lista de tripulantes scrollea
- Clic en tripulante abre modal con 4 tabs
- Foto upload funciona (mismo sistema que avatar)
- Editar y guardar cambios funciona
- Eliminar tripulante funciona
