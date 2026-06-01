# Prompt para CODEX — Arreglar METAR "Sin datos"

## Contexto

Estamos construyendo CG6 Flights (Flutter Web + Supabase). Tenemos un widget METAR en `lib/features/flights/presentation/metar_widget.dart` que obtiene datos meteorológicos de `aviationweather.gov/api/data/metar`. El widget ya tiene un selector de aeródromo funcional (extrae ICAOs de las rutas de vuelo), pero al seleccionar un aeropuerto muestra **"Sin datos"**.

El provider está en `lib/features/flights/application/metar_provider.dart` y usa el paquete `http` para hacer la llamada REST:

```dart
final url = 'https://aviationweather.gov/api/data/metar?ids=$icao&format=json';
final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));
```

## Síntoma

- El dropdown del METAR muestra los ICAO correctamente (extraídos de las rutas de vuelo)
- Al seleccionar un aeropuerto, muestra "Sin datos"
- No hay errores visibles en la consola del navegador

## Causa probable

**CORS (Cross-Origin Resource Sharing)**: Flutter Web ejecuta las peticiones HTTP en el contexto del navegador. Si `aviationweather.gov` no envía headers CORS que permitan solicitudes desde `localhost:43210`, el navegador bloquea la respuesta y el provider recibe un error o respuesta vacía. El `catch (_) {}` en el provider silencia el error.

## Tarea

Diagnosticar y arreglar el problema para que el METAR funcione en Flutter Web.

### Restricciones
- NO agregar dependencias nuevas si se puede evitar
- NO modificar el backend Supabase (no crear Edge Functions nuevas a menos que sea estrictamente necesario)
- Mantener la estructura actual: provider separado, widget con selector ICAO
- NO usar `dart:io` (no compatible con Web)
- El auto-refresh de 1 hora debe seguir funcionando

### Archivos clave
- `lib/features/flights/application/metar_provider.dart` — Provider HTTP
- `lib/features/flights/presentation/metar_widget.dart` — Widget + modal
- `lib/features/flights/domain/metar_data.dart` — Modelo
- `lib/features/flights/presentation/flights_page.dart` — `_extractIcaos()` en línea 499

### Posibles soluciones a evaluar
1. Verificar si aviationweather.gov soporta CORS (posiblemente no)
2. Usar la API con `format=raw` y `Accept: text/plain` que a veces evita CORS
3. Si el problema es CORS, crear una Edge Function mínima en Supabase que actúe como proxy (recomendado)
4. Usar `dart:html` HttpRequest directamente con `mode: 'cors'`
5. Verificar errores de red en DevTools → Network tab

### Validación
- `flutter analyze` limpio
- `flutter test` pasa
- Probar en Chrome: seleccionar aeródromo → debe mostrar METAR real
