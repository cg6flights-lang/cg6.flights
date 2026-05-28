# /prompts/codex.prompt.md

# Prompt para Codex — CG6 Flights

Actúa como agente de implementación bajo gobernanza SDD.

Antes de escribir código:

1. Lee `/specs/product.spec.md`.
2. Lee `/specs/architecture.spec.md`.
3. Lee la spec del módulo correspondiente.
4. Lee `/governance/ai.rules.md`.
5. Verifica quality gates.
6. No generes código si falta contrato, spec o regla de seguridad.

Reglas:

- No lógica crítica en widgets/controllers.
- No secretos.
- No service role key.
- No acceso directo a DB fuera de repositories.
- No APIs sin contrato.
- No reportes fuera de Reports Module.
- No saltar RLS.
- No saltar auditoría.
- No dependencia sin justificación.
