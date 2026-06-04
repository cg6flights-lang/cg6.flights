import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const actions = new Set(["create", "update", "delete", "status"]);
const managerRoles = new Set(["leader", "general_admin"]);
const eventTypes = new Set([
  "operations",
  "training",
  "maintenance",
  "briefing",
  "administrative",
  "other",
]);
const statuses = new Set(["scheduled", "in_progress", "completed", "cancelled"]);

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorResponse(
  status: number,
  code: string,
  message: string,
  category: string,
  severity = "high",
) {
  return jsonResponse(
    { ok: false, error: { code, message, category, severity } },
    status,
  );
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function parseDate(value: unknown) {
  const raw = stringValue(value);
  if (!raw) return null;
  const date = new Date(raw);
  return Number.isNaN(date.getTime()) ? null : date;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse(
      405,
      "VALIDATION_INVALID_INPUT",
      "Metodo no permitido.",
      "VALIDATION",
      "medium",
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return errorResponse(
      500,
      "SYSTEM_UNEXPECTED",
      "Configuracion backend incompleta.",
      "SYSTEM",
      "critical",
    );
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return errorResponse(
      401,
      "AUTH_SESSION_MISSING",
      "Sesion ausente o invalida.",
      "AUTH",
    );
  }

  const { data: actorProfile } = await adminClient
    .from("profiles")
    .select("role,unit_id,status")
    .eq("id", userData.user.id)
    .maybeSingle();

  const audit = async (
    action: string,
    result: "success" | "denied" | "failed",
    resourceId: string | null,
    metadata: Record<string, unknown>,
  ) => {
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile?.role ?? null,
      actor_unit_id: actorProfile?.unit_id ?? null,
      action,
      resource_type: "calendar_event",
      resource_id: resourceId,
      result,
      metadata,
    });
  };

  if (!actorProfile || actorProfile.status !== "active" || !actorProfile.role) {
    await audit("calendar_events.access", "denied", null, {
      reason: "profile_not_operational",
    });
    return errorResponse(
      403,
      "AUTHORIZATION_ROLE_REQUIRED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const { data: hasPermission, error: permissionError } = await userClient.rpc(
    "has_permission",
    { permission_key: "calendar.manage" },
  );

  if (
    permissionError ||
    hasPermission !== true ||
    !managerRoles.has(actorProfile.role)
  ) {
    await audit("calendar_events.manage", "denied", null, {
      reason: "missing_permission",
    });
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const payload = await req.json().catch(() => ({}));
  const action = stringValue(payload.action);
  if (!actions.has(action)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Accion de calendario invalida.",
      "VALIDATION",
      "medium",
    );
  }

  const eventId = payload.event_id ? String(payload.event_id) : "";
  if ((action === "update" || action === "delete" || action === "status") && !eventId) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "La actividad es obligatoria.",
      "VALIDATION",
      "medium",
    );
  }

  if (action === "status") {
    const status = stringValue(payload.status);
    if (!statuses.has(status)) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        "Estado de actividad invalido.",
        "VALIDATION",
        "medium",
      );
    }

    const { data: event, error: statusError } = await adminClient
      .from("calendar_events")
      .update({ status })
      .eq("id", eventId)
      .is("deleted_at", null)
      .select("id")
      .maybeSingle();

    if (statusError || !event) {
      await audit("calendar_events.status", "failed", eventId, {
        reason: statusError?.message ?? "not_found",
        status,
      });
      return errorResponse(
        statusError ? 500 : 404,
        statusError ? "CALENDAR_EVENT_SAVE_FAILED" : "DATA_NOT_FOUND",
        statusError
          ? "No se pudo actualizar la actividad."
          : "Actividad no encontrada.",
        statusError ? "SYSTEM" : "DATA",
        statusError ? "high" : "medium",
      );
    }

    await audit("calendar_events.status", "success", event.id, { status });
    return jsonResponse({ ok: true, data: { event_id: event.id }, meta: {} });
  }

  if (action === "delete") {
    const { data: event, error: deleteError } = await adminClient
      .from("calendar_events")
      .update({ deleted_at: new Date().toISOString() })
      .eq("id", eventId)
      .is("deleted_at", null)
      .select("id")
      .maybeSingle();

    if (deleteError || !event) {
      await audit("calendar_events.delete", "failed", eventId, {
        reason: deleteError?.message ?? "not_found",
      });
      return errorResponse(
        deleteError ? 500 : 404,
        deleteError ? "CALENDAR_EVENT_SAVE_FAILED" : "DATA_NOT_FOUND",
        deleteError
          ? "No se pudo eliminar la actividad."
          : "Actividad no encontrada.",
        deleteError ? "SYSTEM" : "DATA",
        deleteError ? "high" : "medium",
      );
    }

    await audit("calendar_events.delete", "success", event.id, {});
    return jsonResponse({ ok: true, data: { event_id: event.id }, meta: {} });
  }

  const title = stringValue(payload.title);
  const description = stringValue(payload.description);
  const location = stringValue(payload.location);
  const eventType = stringValue(payload.event_type) || "operations";
  const status = stringValue(payload.status) || "scheduled";
  const startsAt = parseDate(payload.starts_at);
  const endsAt = parseDate(payload.ends_at);

  if (!title || !startsAt || !endsAt) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Titulo, inicio y fin son obligatorios.",
      "VALIDATION",
      "medium",
    );
  }

  if (endsAt.getTime() < startsAt.getTime()) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "La fecha de fin no puede ser anterior al inicio.",
      "VALIDATION",
      "medium",
    );
  }

  if (!eventTypes.has(eventType) || !statuses.has(status)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Tipo o estado de actividad invalido.",
      "VALIDATION",
      "medium",
    );
  }

  const values = {
    title,
    description: description || null,
    location: location || null,
    event_type: eventType,
    status,
    starts_at: startsAt.toISOString(),
    ends_at: endsAt.toISOString(),
  };

  if (action === "create") {
    const { data: event, error: eventError } = await adminClient
      .from("calendar_events")
      .insert({
        ...values,
        created_by: userData.user.id,
      })
      .select("id")
      .single();

    if (eventError || !event) {
      await audit("calendar_events.create", "failed", null, {
        reason: eventError?.message ?? "insert_failed",
      });
      return errorResponse(
        500,
        "CALENDAR_EVENT_SAVE_FAILED",
        "No se pudo crear la actividad.",
        "SYSTEM",
      );
    }

    await audit("calendar_events.create", "success", event.id, {
      event_type: eventType,
      status,
    });
    return jsonResponse({ ok: true, data: { event_id: event.id }, meta: {} });
  }

  const { data: event, error: eventError } = await adminClient
    .from("calendar_events")
    .update(values)
    .eq("id", eventId)
    .is("deleted_at", null)
    .select("id")
    .maybeSingle();

  if (eventError || !event) {
    await audit("calendar_events.update", "failed", eventId, {
      reason: eventError?.message ?? "not_found",
    });
    return errorResponse(
      eventError ? 500 : 404,
      eventError ? "CALENDAR_EVENT_SAVE_FAILED" : "DATA_NOT_FOUND",
      eventError ? "No se pudo guardar la actividad." : "Actividad no encontrada.",
      eventError ? "SYSTEM" : "DATA",
      eventError ? "high" : "medium",
    );
  }

  await audit("calendar_events.update", "success", event.id, {
    event_type: eventType,
    status,
  });
  return jsonResponse({ ok: true, data: { event_id: event.id }, meta: {} });
});
