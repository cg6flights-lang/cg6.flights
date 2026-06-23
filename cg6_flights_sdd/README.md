# CG6 Flights — SDD Repository

Centro de Gestión y Control de Vuelos Diarios.

Este repositorio contiene la estructura base de Spec-Driven Development para gobernar el desarrollo asistido por IA de CG6 Flights.

## Estado general

- Proyecto: CG6 Flights
- Visión: Centro de Gestión y Control de Vuelos Diarios
- Fecha de generación: 2026-05-24 · Última actualización: 2026-06-23
- Estado SDD: as-built, sincronizado con la implementación (v1.3)
- Implementación: en producción (v1.0 desplegada en Vercel; desarrollo en branch `cg6_flights_v1.3`)
- Fuente de verdad: especificaciones en `/specs`, contratos en `/contracts`, reglas en `/governance`

## Regla principal

Ningún código productivo debe generarse fuera de las especificaciones aprobadas.

## Estructura

```txt
/project
/specs
/contracts
/governance
/adr
/inspections
/prompts
/memory
/templates
```

## Uso recomendado

1. Revisar `/project/intake.md`
2. Revisar specs en `/specs`
3. Revisar reglas IA en `/governance/ai.rules.md`
4. Revisar quality gates antes de implementar
5. Generar ADRs para cambios estructurales
