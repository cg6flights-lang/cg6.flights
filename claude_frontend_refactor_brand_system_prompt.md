# Prompt Para Claude Code — Refactor Frontend CG6 Flights Con Branding Oficial

Actúa como agente senior de frontend para CG6 Flights bajo gobernanza SDD.

## Contexto Del Proyecto

Proyecto: `/Users/franciscobances1997/Documents/CG6_Flights`

Stack:

- Flutter Web
- Riverpod
- GoRouter
- Supabase
- Material 3

SDD:

- `cg6_flights_sdd/specs/frontend.spec.md`
- `cg6_flights_sdd/specs/product.spec.md`
- `cg6_flights_sdd/governance/ai.rules.md`
- `cg6_flights_sdd/governance/quality-gates.md`
- `cg6_flights_sdd/memory/project-context.md`

Antes de modificar, lee el SDD relevante y respeta sus capas, estructura visual y reglas de calidad.

## Objetivo

Refactorizar la apariencia general del frontend para que CG6 Flights tenga una identidad visual tecnológica, moderna, operacional y coherente con el logo oficial, tanto en modo claro como en modo oscuro.

El resultado debe sentirse como una plataforma militar/aeronáutica moderna de control operacional, no como una app genérica de Flutter.

## Assets Oficiales

Logo general:

- `cg6_logo/logo_cg6.png`

Favicon fuente:

- `cg6_logo/favicon_cg6.png`

El logo ya fue integrado en:

- Login
- Header interno
- Favicon/PWA icons

No reemplaces estos assets salvo que detectes un problema real.

## Paleta Base Del Logo

Se extrajeron colores reales desde `cg6_logo/logo_cg6.png`.

Colores principales detectados:

- Brand Blue Average: `#0E5DCB`
- Brand Blue Dominant 1: `#005AD2`
- Brand Blue Dominant 2: `#005BD3`
- Brand Blue Deep: `#0846B4`
- Brand Slate/Grey: `#4E6082`

Usa estos colores como base de marca.

### Paleta Recomendada

Usa esta paleta como punto de partida y valida contraste WCAG visualmente:

#### Light Mode

- Primary: `#0E5DCB`
- Primary Strong: `#0846B4`
- Primary Soft Container: `#DCEAFF`
- Accent Cyan: `#22B8E6`
- Accent Gold: `#D9A441`
- Background: `#F5F8FC`
- Surface: `#FFFFFF`
- Surface Muted: `#EEF3F8`
- Border: `#C9D6E5`
- Text Primary: `#101820`
- Text Secondary: `#4E6082`

#### Dark Mode

- Primary: `#4D8DFF`
- Primary Strong: `#7AADFF`
- Primary Container: `#0E2A55`
- Accent Cyan: `#27C7F2`
- Accent Gold: `#E2B354`
- Background: `#070B10`
- Surface: `#0F1720`
- Surface Elevated: `#152232`
- Surface Muted: `#1B2A3D`
- Border: `#2A3B50`
- Text Primary: `#F4F8FF`
- Text Secondary: `#A9B8CB`

Regla importante: evita que el tema se vuelva monocromático azul. El azul del logo debe dominar como identidad, pero usa cian, oro operacional, slate y superficies neutras para jerarquía y contraste.

## Requisitos De Diseño

### 1. Tema Global

Refactoriza primero el sistema global de tema en:

- `lib/app/theme/app_theme.dart`

Objetivos:

- Reemplazar el seed teal actual por una paleta basada en el logo.
- Mantener Material 3.
- Definir `ColorScheme` claro/oscuro con colores explícitos cuando sea necesario.
- Mejorar cards, inputs, botones, chips, dialogs, data tables, navigation rail, app bar, snackbars y popups.
- Mantener radios moderados: preferir `8px` o menos salvo componentes grandes.
- Evitar gradientes excesivos o decorativos.
- Evitar orbes, blobs o decoración sin función.
- Mantener buena densidad operacional: interfaces escaneables, no estilo landing page.

### 2. Galería Moderna De Contenedores Y Widgets

Crear o consolidar una pequeña librería visual compartida, sin sobrediseñar.

Ubicación sugerida:

- `lib/shared/widgets/`

Componentes candidatos:

- `OperationalCard`
- `MetricTile`
- `StatusChip`
- `SectionHeader`
- `ActionToolbar`
- `GlassPanel` o `TacticalPanel` sólo si encaja con el estilo existente

Reglas:

- No crear componentes si sólo se usan una vez.
- No crear una abstracción enorme.
- Usar Material 3 y `Theme.of(context).colorScheme`.
- Todos los componentes deben funcionar en claro/oscuro.
- Deben respetar responsive y evitar overflow.

### 3. Login

El login debe ser parte del mismo sistema visual.

Requisitos:

- Mantener el logo oficial en lugar de textos duplicados.
- No volver a mostrar `CG6 Flights` ni `Centro de Gestion...` como texto visible en login.
- Añadir botón de modo claro/oscuro en login.
- El botón de modo claro/oscuro debe usar el mismo provider actual:
  - `themeModeProvider`
  - `ThemeModeController`
- El botón debe estar visible y accesible sin competir con el formulario.
- El login debe verse bien en modo claro y oscuro.
- El logo debe conservar proporción y no quedar dentro de un contenedor visual pesado.
- El formulario debe tener una estética tecnológica, clara y confiable.

### 4. Header Y Navegación

El header interno ya usa el logo.

Requisitos:

- Mantener el logo como identidad global.
- Asegurar que no se solape con acciones en desktop ni móvil.
- Modernizar AppBar/NavRail/Drawer si aplica, usando la nueva paleta.
- Mantener navegación funcional y permisos existentes.
- No cambiar rutas ni lógica de autorización.

### 5. Pantallas Principales

Aplicar la nueva identidad visual de forma consistente en las pantallas ya existentes:

- Dashboard
- Users/Roles/Permissions
- Units
- Aircraft
- Crew
- Routes
- Flight Orders
- Flights
- LED Board
- METAR widget
- History/Audit/Settings si existen o están visibles

Prioridad:

1. Theme global
2. Shell/header/nav
3. Login
4. Cards/tables/chips compartidos
5. Pantallas con mayor tráfico: Dashboard, Flights, Flight Orders, Aircraft/Crew/Routes

No hagas una reescritura destructiva de todas las pantallas si el tema global y componentes compartidos ya elevan la calidad visual.

### 6. METAR Y LED Board

Preserva lo ya implementado:

- METAR usa patrón visual `Radar Compacto`.
- Loader METAR usa 3 puntos animados sin texto.
- Modal METAR muestra raw METAR, métricas y TAF.
- LED Board mantiene estilo de pantalla operacional.

Puedes ajustar colores para integrarlos con la nueva paleta, pero no cambies lógica, provider ni Edge Function.

### 7. Accesibilidad Y Contraste

Obligatorio:

- Verificar contraste claro/oscuro para texto, botones, chips y estados.
- Evitar textos grises demasiado bajos en dark mode.
- No usar azul sobre azul si reduce legibilidad.
- Estados críticos deben seguir siendo distinguibles:
  - éxito
  - advertencia
  - error
  - información
  - inactivo
- Mantener `semanticLabel` del logo.
- Botones icónicos deben tener tooltip si no son obvios.

## Restricciones

- No agregar dependencias nuevas salvo que sea estrictamente necesario y esté justificado.
- No modificar backend Supabase.
- No modificar Edge Functions.
- No cambiar contratos API.
- No exponer secretos.
- No mover assets oficiales fuera de `cg6_logo/`.
- No revertir cambios no relacionados.
- No romper i18n: cualquier texto visible nuevo debe tener claves ES/EN en `app_localizations.dart`.
- No introducir lógica de negocio en widgets.
- No tocar rutas, permisos ni RBAC salvo que encuentres una falla real.

## Archivos Clave A Revisar

- `lib/app/theme/app_theme.dart`
- `lib/core/state/theme_mode_controller.dart`
- `lib/shared/widgets/app_shell.dart`
- `lib/features/auth/presentation/login_page.dart`
- `lib/app/i18n/app_localizations.dart`
- `lib/features/flights/presentation/metar_widget.dart`
- `lib/features/flights/presentation/flight_led_board.dart`
- `lib/features/flight_orders/presentation/flight_orders_page.dart`
- `lib/features/flight_orders/presentation/flight_order_detail_panel.dart`
- `lib/features/aircraft/presentation/aircraft_page.dart`
- `lib/features/crew/presentation/crew_page.dart`
- `lib/features/routes/presentation/routes_page.dart`

## Implementación Esperada

### Paso 1 — Auditoría Visual Y Técnica

Antes de cambiar:

- Revisa el tema actual.
- Identifica pantallas que dependen directamente de colores hardcodeados.
- Identifica widgets repetidos que conviene consolidar.
- Verifica cómo se usa el modo claro/oscuro actualmente.

### Paso 2 — Refactor Del Theme

Actualizar `AppTheme` con la paleta basada en el logo.

Debe incluir:

- ColorScheme claro/oscuro coherente.
- AppBar modernizada.
- CardTheme modernizado.
- InputDecorationTheme consistente.
- Button themes consistentes.
- ChipTheme moderno.
- DataTableTheme legible.
- DialogTheme coherente.
- Popup/Snackbar/Divider themes alineados.

### Paso 3 — Login

Actualizar login para:

- Integrar el toggle claro/oscuro.
- Usar nueva estética del tema.
- Mantener logo centrado y sin texto duplicado.
- Validar desktop y móvil.

### Paso 4 — Shell Y Navegación

Actualizar shell/nav para:

- Usar el nuevo lenguaje visual.
- Mantener logo en header.
- Garantizar responsive.
- Mantener acciones existentes.

### Paso 5 — Componentes Compartidos

Crear sólo los componentes compartidos que reduzcan duplicación real.

No hacer una librería ornamental.

### Paso 6 — Pantallas Principales

Aplicar componentes/tema a pantallas prioritarias sin romper lógica.

En tablas:

- Mejorar encabezados.
- Mejorar selección.
- Mejorar chips de estado.
- Mejorar empty/loading/error states.

En paneles:

- Usar contenedores modernos.
- Mejorar jerarquía visual.
- Evitar cards anidadas.

## Validación Obligatoria

Ejecutar:

```bash
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run --dart-define-from-file=.env.json
```

Prueba manual en navegador:

1. `/login`
   - modo claro
   - modo oscuro
   - toggle visible y funcional
   - logo sin desbordes
   - no aparecen textos duplicados del logo

2. Dashboard
   - header con logo
   - nav sin solapamientos
   - cards legibles

3. `/flights`
   - METAR se integra con la nueva paleta
   - LED Board conserva estética operacional

4. `/flight-orders`
   - tablas y panel de detalle legibles
   - botones y estados claros

5. Responsive
   - desktop ancho
   - tablet
   - móvil `390x844`

6. Consola del navegador
   - sin errores

## Actualización SDD

Después de implementar, revisa si corresponde actualizar:

- `cg6_flights_sdd/specs/frontend.spec.md`
- `cg6_flights_sdd/specs/product.spec.md`
- `cg6_flights_sdd/governance/quality-gates.md`
- `cg6_flights_sdd/memory/project-context.md`

No inventes reglas innecesarias. Si documentas, registra:

- Paleta oficial derivada del logo.
- Uso del logo en login/header.
- Login debe tener toggle claro/oscuro.
- Los componentes visuales compartidos se basan en Material 3.
- Todo texto nuevo debe ir en i18n ES/EN.
- Contraste claro/oscuro es parte del quality gate visual.

## Resultado Esperado

Entrega:

- Resumen de cambios.
- Archivos modificados.
- Decisiones de paleta.
- Validaciones ejecutadas.
- Capturas o descripción de verificación visual.
- Cualquier SDD actualizado.

No cierres con cambios parciales: si algo queda pendiente, decláralo explícitamente con razón y siguiente acción.
