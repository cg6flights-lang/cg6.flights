# Prompt para Codex — Análisis de Pantalla LED de Aeropuerto

## Contexto

Estamos construyendo una pantalla LED de control de vuelos para la plataforma **CG6 Flights** (Base Aérea Las Palmas). Queremos replicar el estilo visual de la imagen de referencia que te pasamos a continuación.

## Imagen de referencia

**URL**: https://www.pinterest.com/pin/259731103502872658/
**Descripción en Pinterest**: "Arrivals and Departures airport sign art print photo"

## Lo que necesitamos que analices

Por favor, describe en detalle cada uno de los siguientes aspectos de la imagen:

### 1. Estética general
- ¿Es una pantalla LED real, LCD, o una recreación artística?
- ¿Qué sensación transmite? (retro, moderno, industrial, etc.)

### 2. Paleta de colores
- Color de fondo del panel
- Color del texto principal
- Colores de acento o secundarios
- ¿Hay diferentes colores para diferentes tipos de información? (ej: salidas vs llegadas)

### 3. Tipografía
- ¿Qué tipo de fuente usa? (monoespaciada, sans-serif, con serifa)
- Tamaños relativos (títulos vs datos)
- ¿Hay variaciones de peso (bold, regular)?
- ¿Las letras tienen efecto de glow, sombra, o algún tratamiento visual?

### 4. Layout y columnas
- ¿Cómo están organizadas las columnas de información?
- Orden de las columnas (de izquierda a derecha)
- ¿Qué información muestra cada columna?
- Anchos relativos de las columnas
- Encabezados: ¿están en mayúsculas? ¿tienen algún formato especial?

### 5. Elementos visuales
- ¿Hay líneas divisorias, bordes, o marcos?
- ¿Hay iconos, símbolos o indicadores visuales? (flechas, puntos, etc.)
- ¿Cómo se indica el estado de cada vuelo?
- ¿Hay algún elemento animado o parpadeante?

### 6. Distribución espacial
- ¿Es una tabla continua o hay secciones separadas?
- ¿Hay encabezados de sección?
- Espaciado entre filas y columnas
- ¿La información está densamente empaquetada o hay espacio generoso?

### 7. Para nuestra implementación

Con esta referencia visual, vamos a construir una pantalla LED en **Flutter Web** con las siguientes características:
- Fondo oscuro simulando un display LED
- Texto en fuente monoespaciada con efecto glow
- Columnas: HORA, UNIDAD·COLA, DESTINO, ETA, OBSERVACIÓN (estado)
- Botón ON/OFF para encender/apagar la pantalla
- Auto-refresh cada 60 segundos
- Scroll vertical si hay más vuelos de los que caben

Basado en la imagen de referencia, ¿qué ajustes específicos recomendarías para:
- Los colores exactos (hex)?
- El tamaño y peso de fuente?
- El efecto visual del texto (glow, sombra)?
- Los bordes o marcos del display?
- El espaciado entre columnas?
- Cualquier detalle que haga que se vea más auténtico?
