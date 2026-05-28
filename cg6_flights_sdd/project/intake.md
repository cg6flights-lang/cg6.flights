# /project/intake.md

# Project Intake — CG6 Flights

## 1. Nombre del proyecto

CG6 Flights

## 2. Visión

Centro de Gestión y Control de Vuelos Diarios.

## 3. Problema

La Jefatura de Operaciones Aéreas no cuenta con una plataforma web centralizada para controlar en tiempo real las operaciones aéreas por unidad en la Base Aérea Las Palmas.

El sistema debe integrar la carga diaria de Orden de Vuelo por unidad y permitir al Jefe de Operaciones visualizar el registro general diario, estados de vuelo, tripulaciones, tipo de aeronave, ruta, históricos y auditoría.

## 4. Usuarios y roles

### Líder

Rol superior al Administrador General.

Responsabilidades:

- soporte técnico avanzado;
- auditoría global;
- control superior de permisos;
- activar/desactivar acciones;
- control máximo del sistema.

Restricción:

- máximo 1 usuario.

### Administrador General / Jefe de Operaciones

Responsabilidades:

- control operacional global;
- visualización de todas las unidades;
- auditoría;
- históricos;
- reportes;
- estados de vuelo.

Restricción:

- máximo 5 usuarios.

### Comando de Unidad

Responsabilidades:

- autoridad sobre su unidad;
- funciones de Administrador de Unidad;
- autorizar adición, anulación y cierre;
- revisar histórico de su unidad.

### Administrador de Unidad / Personal de Operaciones

Responsabilidades:

- cargar vuelos de su unidad;
- gestionar pilotos;
- gestionar aeronaves;
- gestionar mecánicos o Ingenieros de Vuelo opcionales;
- registrar rutas, horarios y estados.

### TTAA

Responsabilidades:

- acceso limitado;
- visualizar estado final del vuelo;
- confirmar aterrizaje en localidad autorizada cuando aplique.

Pendiente:

- confirmar significado institucional exacto de TTAA.

## 5. Funcionalidades principales

- Carga de Orden de Vuelo diaria por unidad.
- Gestión de unidades.
- Gestión de aeronaves.
- Gestión de tripulación.
- Estados de vuelo:
  - Arranque de Motor.
  - Inicio de Taxeo.
  - Despegue.
  - Aterrizaje.
  - Apagado de motor.
- Cálculo de tiempos:
  - total desde taxeo hasta apagado de motor;
  - parcial desde despegue hasta aterrizaje.
- Cierres protegidos.
- Históricos diarios, semanales, mensuales y anuales.
- Exportación PDF.
- Exportación Excel.
- Auditoría exhaustiva.
- Notificaciones.
- Mensajería interna.
- Calendario.
- Mapas.
- Perfil con foto máxima 5 MB.
- Interfaz bilingüe Español/Inglés.
- Diseño moderno aeronáutico militar.

## 6. Plataforma

- Web multiplataforma.
- Responsive.
- Compatible con laptop, escritorio, tablet, iOS y Android.
- Prioridad principal: laptop/escritorio.

## 7. Stack preliminar

- Flutter Web.
- Supabase.
- Vercel.

Estado:

- Stack sugerido y preliminar.
- Debe mantenerse gobernado por specs y ADRs.

## 8. Seguridad

Nivel: alto/confidencial.

El sistema manejará:

- datos personales;
- pilotos;
- tripulaciones;
- aeronaves;
- rutas;
- horarios;
- estados en tiempo real;
- históricos;
- auditoría;
- mensajes;
- reportes PDF/Excel.

## 9. Escala esperada

- Unidades sin límite funcional rígido.
- Vuelos diarios sin límite fijo.
- Usuarios por unidad: 10 miembros sin contar Admin y Comando.
- Líder: máximo 1.
- Administrador General: máximo 5.
- Retención histórica: 5 años.

## 10. Restricciones

- Preferencia por herramientas gratuitas o planes gratuitos.
- Sistema completo, no MVP recortado.
- Desarrollo asistido por IA bajo gobernanza SDD.
