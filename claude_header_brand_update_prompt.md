# Prompt Para Claude Code — Header Branding CG6 Flights v1.0

Actúa como agente de implementación Flutter para CG6 Flights bajo gobernanza SDD.

## Objetivo

Actualizar el header principal de la aplicación para que ya no use el logo completo `logo_cg6.png`, sino el isotipo usado para favicon (`favicon_cg6.png`) y, a su derecha, el texto:

`CG6 Flights v1.0`

El resultado debe verse alineado con el branding del login/logo oficial.

## Contexto

Proyecto: `/Users/franciscobances1997/Documents/CG6_Flights`

Assets oficiales:

- Logo completo actual: `cg6_logo/logo_cg6.png`
- Isotipo/favicon fuente: `cg6_logo/favicon_cg6.png`

Actualmente el header se define en:

- `lib/shared/widgets/app_shell.dart`

El logo completo ya está registrado como asset en:

- `pubspec.yaml`

## Información Del Estilo Del Logo

Las letras del logo tienen un estilo:

- Techno/aeronáutico
- Sans geométrica extendida
- Muy bold
- Oblicua/italic
- Cortes angulares

No parece existir una fuente exacta registrada en el repo. Por eso, la aproximación Flutter debe hacerse sin agregar dependencias nuevas.

Colores muestreados desde `cg6_logo/logo_cg6.png`:

- Azul dominante letras CG6: `#005AD2`
- Azul alternativo: `#005BD3`
- Azul profundo para sombra/acento: `#0846B4`
- Promedio letras CG6: `#0D5DCF`
- Gris azulado del texto FLIGHTS: `#596F97` / `#4E6082`

Para el header respetar la separación cromática del logo:

- `CG6`: azul dominante `#005AD2`
- `Flights`: gris azulado `#596F97`
- `v1.0`: gris azulado secundario `#4E6082`, con menor peso visual que `CG6 Flights`

## Requisitos

### 1. Registrar El Isotipo Como Asset

Registrar también el isotipo/favicon como asset Flutter en `pubspec.yaml`:

```yaml
assets:
  - cg6_logo/logo_cg6.png
  - cg6_logo/favicon_cg6.png
```

### 2. Cambiar Header En AppShell

En `lib/shared/widgets/app_shell.dart`, reemplazar el logo completo del `AppBar.title` por una marca horizontal compuesta:

- Izquierda: `Image.asset('cg6_logo/favicon_cg6.png')`
- Derecha: texto `CG6 Flights v1.0`

### 3. Estilo Visual Del Isotipo

Usar:

- Altura desktop: `34`
- Ancho máximo desktop aproximado: `58`
- Altura móvil: `28`
- Ancho máximo móvil aproximado: `48`
- `fit: BoxFit.contain`
- `semanticLabel: 'CG6 Flights'`

### 4. Estilo Visual Del Texto

El texto debe replicar la lógica cromática del logo:

- `CG6` debe ir en azul.
- `Flights` debe ir en gris azulado.
- `v1.0` debe ir en gris azulado más discreto.

No pintar toda la frase con el mismo color.

Usar `RichText` o `Text.rich` para separar estilos por segmento.

Usar aproximación Flutter sin agregar dependencias:

```dart
const cg6Style = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w900,
  fontStyle: FontStyle.italic,
  color: Color(0xFF005AD2),
);

const flightsStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w800,
  fontStyle: FontStyle.italic,
  color: Color(0xFF596F97),
);

const versionStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  fontStyle: FontStyle.italic,
  color: Color(0xFF4E6082),
);
```

Opcionalmente usar una sombra muy sutil sólo en `CG6` para imitar el acabado del logo:

```dart
shadows: [
  Shadow(
    color: Color(0xFF0846B4).withValues(alpha: 0.22),
    offset: Offset(0.8, 0.8),
    blurRadius: 1.2,
  ),
]
```

No usar efectos fuertes, glow excesivo ni gradientes en el texto del header.

### 5. Responsive

En desktop:

  - Mostrar isotipo + `CG6 Flights v1.0`, respetando colores por palabra

En móvil:

- Mantener isotipo visible.
- Mostrar texto compacto si el ancho no alcanza.
- Si hay riesgo de overflow, usar `CG6 v1.0` sólo para ancho muy compacto, manteniendo `CG6` azul y `v1.0` gris azulado.
- No solapar acciones existentes.

Acciones existentes que deben mantenerse:

- Calendario
- Notificaciones
- Modo claro/oscuro
- Idioma
- Avatar/sesión

## Implementación Sugerida

Crear un widget privado dentro de `app_shell.dart`, por ejemplo:

```dart
class _HeaderBrand extends StatelessWidget {
  const _HeaderBrand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'cg6_logo/favicon_cg6.png',
          height: compact ? 28 : 34,
          width: compact ? 48 : 58,
          fit: BoxFit.contain,
          semanticLabel: 'CG6 Flights',
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'CG6',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF005AD2),
                    shadows: [
                      Shadow(
                        color: Color(0x380846B4),
                        offset: Offset(0.8, 0.8),
                        blurRadius: 1.2,
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  const TextSpan(
                    text: ' Flights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF596F97),
                    ),
                  ),
                const TextSpan(
                  text: ' v1.0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF4E6082),
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
```

Luego usarlo en `AppBar.title`, aprovechando el `compact` que ya calcula el `LayoutBuilder`:

```dart
title: _HeaderBrand(compact: compact),
```

Si el `AppBar.title` necesita ancho estable, envolver en `SizedBox` o `ConstrainedBox` para evitar que empuje las acciones.

## No Modificar

No modificar:

- Login
- Favicon web ya generado
- Manifest
- Edge Functions
- Backend
- Rutas
- Permisos
- Lógica de sesión

No agregar dependencias nuevas.

No revertir cambios no relacionados.

## Validación

Ejecutar:

```bash
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run --dart-define-from-file=.env.json
```

Prueba visual:

1. Header desktop:
   - Isotipo/favicon visible.
   - Texto `CG6 Flights v1.0` a la derecha.
   - `CG6` en azul `#005AD2`.
   - `Flights` en gris azulado `#596F97`.
   - `v1.0` en gris azulado secundario `#4E6082`.
   - No hay solapamiento con acciones.

2. Header móvil:
   - Isotipo visible.
   - Texto compacto si es necesario.
   - Colores por segmento preservados.
   - Acciones siguen accesibles.

3. Login:
   - No debe cambiar.

4. Consola navegador:
   - Sin errores.

## Reporte Final Esperado

Indica:

- Archivos modificados.
- Si agregaste el asset en `pubspec.yaml`.
- Resultado de `flutter analyze`.
- Resultado de `flutter test`.
- Resultado de `flutter build web`.
- Confirmación visual desktop/móvil.
