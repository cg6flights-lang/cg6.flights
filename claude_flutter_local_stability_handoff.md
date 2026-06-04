# Handoff Para Claude Code — Estabilidad Flutter Local CG6 Flights

Actúa como agente de implementación para CG6 Flights bajo gobernanza SDD.

## Contexto

Proyecto: `/Users/franciscobances1997/Documents/CG6_Flights`

Se investigó un problema donde `flutter test` se quedaba colgado y los deploys locales con Claude Code ponían lenta la app o no cargaban.

## Diagnóstico Encontrado

El problema no era un fallo funcional único de Flutter ni de Supabase.

Se encontraron estas causas:

1. Había procesos `flutter run -d chrome` vivos de ejecuciones anteriores de Claude Code.
2. Había instancias Chrome temporales en `/tmp/claude-501/.../flutter_tools_chrome_device...`.
3. Un proceso `flutter run` seguía escuchando en `--web-port=43210` y no respondió a `SIGTERM`.
4. Había mezcla de SDK roots Flutter:
   - `/Users/franciscobances1997/flutter/bin/flutter`
   - `/Users/franciscobances1997/flutter/flutter/bin/flutter`
5. VS Code ya usa puerto `8080`, pero Claude había usado `43210`, generando sesiones locales inconsistentes.
6. `widget_test.dart` usaba `pumpAndSettle()`, que es frágil cuando hay animaciones, timers o overlays con `AnimationController.repeat()`.

## Correcciones Ya Aplicadas

### 1. SDK Flutter Unificado En VS Code

Se agregó:

- `.vscode/settings.json`

Con:

```json
{
  "dart.flutterSdkPath": "/Users/franciscobances1997/flutter/flutter",
  "dart.sdkPath": "/Users/franciscobances1997/flutter/flutter/bin/cache/dart-sdk"
}
```

Claude Code debe usar ese mismo SDK:

```bash
/Users/franciscobances1997/flutter/flutter/bin/flutter
```

No uses:

```bash
/Users/franciscobances1997/flutter/bin/flutter
```

### 2. Puerto Local Estandarizado

El puerto local oficial para desarrollo web queda en:

```txt
8080
```

Usar:

```bash
flutter run -d chrome --web-port=8080 --dart-define-from-file=.env.json
```

No usar `43210` para nuevas sesiones locales.

### 3. Script De Limpieza Local

Se agregó:

- `scripts/cleanup_flutter_local.sh`

Uso obligatorio antes de iniciar un nuevo deploy local:

```bash
scripts/cleanup_flutter_local.sh
```

Qué limpia:

- Listeners en puertos `43210`, `8080`, `8082`
- Instancias Chrome temporales de Claude asociadas a `flutter_tools_chrome_device`
- Procesos colgados que no liberan puertos locales

No mata Chrome normal del usuario.

### 4. README Actualizado

Se actualizó:

- `README.md`

Ahora el flujo local recomendado es:

```bash
scripts/cleanup_flutter_local.sh
flutter run -d chrome --web-port=8080 --dart-define-from-file=.env.json
```

### 5. Tests Widget Menos Frágiles

Se actualizó:

- `test/widget_test.dart`

Cambio:

- Se reemplazaron `pumpAndSettle()` por bombeos acotados.
- Se agregaron helpers:
  - `_pumpApp`
  - `_pumpRouteChange`

Motivo:

`pumpAndSettle()` puede colgarse si hay animaciones o timers activos, especialmente con overlays/global shell animations.

## Reglas Para Claude Code A Partir De Ahora

### Antes De Cualquier Deploy Local

Ejecutar:

```bash
scripts/cleanup_flutter_local.sh
```

Después iniciar una sola sesión:

```bash
/Users/franciscobances1997/flutter/flutter/bin/flutter run \
  -d chrome \
  --web-port=8080 \
  --dart-define-from-file=.env.json
```

No abras múltiples `flutter run` en paralelo.

No mezcles `web-server`, `chrome`, `43210`, `8080` y `8082` sin limpiar antes.

### Después De Validar

Si abriste un `flutter run`, ciérralo correctamente.

Antes de entregar, confirma:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
lsof -nP -iTCP:43210 -sTCP:LISTEN
```

Si no necesitas dejar servidor activo, deben quedar sin listeners.

### Para Tests

Usar:

```bash
flutter analyze
flutter test
```

Si `flutter test` tarda demasiado:

1. Revisa procesos:

```bash
ps -axo pid,ppid,etime,%cpu,%mem,command | rg 'flutter|dart|frontend_server|chrome_device'
```

2. Ejecuta limpieza:

```bash
scripts/cleanup_flutter_local.sh
```

3. Reintenta tests.

No asumas que un timeout de test es fallo de lógica hasta confirmar que no hay procesos Flutter/Chrome colgados.

## Validaciones Esperadas Tras Cambios

Ejecutar:

```bash
flutter analyze
flutter test test/widget_test.dart
flutter test
```

Si `flutter test` vuelve a colgar:

- No sigas lanzando nuevas sesiones.
- Inspecciona procesos y puertos.
- Reporta PID, puerto y comando exacto.
- Evita dejar procesos vivos.

## Archivos Relevantes

- `.vscode/settings.json`
- `.vscode/launch.json`
- `README.md`
- `scripts/cleanup_flutter_local.sh`
- `test/widget_test.dart`
- `lib/shared/widgets/app_shell.dart`

## No Hacer

- No volver a usar `--web-port=43210` para CG6 Flights.
- No usar otro Flutter SDK root.
- No dejar `flutter run` vivo después de terminar validaciones.
- No reemplazar tests por esperas infinitas.
- No agregar `pumpAndSettle()` sin timeout/justificación.
- No matar Chrome normal del usuario.
- No tocar backend, Supabase o Edge Functions por este tema.

## Reporte Que Debes Dar Al Final

Incluye:

- Si ejecutaste `scripts/cleanup_flutter_local.sh`.
- Qué puerto usaste.
- Qué SDK Flutter usaste.
- Resultado de `flutter analyze`.
- Resultado de `flutter test`.
- Si dejaste o no servidor local activo.
- Si hay procesos Flutter/Chrome residuales.
