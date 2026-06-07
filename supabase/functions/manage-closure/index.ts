import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const actions = new Set(["close", "reopen"]);
const reviewRoles = new Set(["leader", "general_admin", "unit_command"]);

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorResponse(
  status: number, code: string, message: string, category: string, severity = "high"
) {
  return jsonResponse({ ok: false, error: { code, message, category, severity } }, status);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return errorResponse(405, "VALIDATION_METHOD_NOT_ALLOWED", "Metodo no permitido.", "VALIDATION", "medium");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return errorResponse(401, "AUTH_SESSION_MISSING", "Sesion ausente.", "AUTH");
  }

  const { data: actor } = await adminClient.from("profiles")
    .select("role,unit_id,status").eq("id", userData.user.id).maybeSingle();
  if (!actor || actor.status !== "active" || !actor.role) {
    return errorResponse(403, "AUTHORIZATION_ROLE_REQUIRED", "Operacion no autorizada.", "AUTHORIZATION");
  }
  if (!reviewRoles.has(actor.role)) {
    return errorResponse(403, "AUTHORIZATION_PERMISSION_DENIED", "Solo Lider, General Admin y Comando de Unidad.", "AUTHORIZATION");
  }

  const payload = await req.json().catch(() => ({}));
  const action = String(payload.action ?? "");
  const flightOrderId = String(payload.flight_order_id ?? "");
  const reason = String(payload.reason ?? "");

  if (!actions.has(action) || !flightOrderId) {
    return errorResponse(400, "VALIDATION_INVALID_INPUT", "Datos invalidos.", "VALIDATION", "medium");
  }

  // Check flight order exists and scope
  const { data: order } = await adminClient.from("flight_orders")
    .select("id,unit_id,status").eq("id", flightOrderId).maybeSingle();
  if (!order) {
    return errorResponse(404, "DATA_NOT_FOUND", "Orden de vuelo no encontrada.", "DATA", "medium");
  }

  const isGlobal = actor.role === "leader" || actor.role === "general_admin";
  if (!isGlobal && order.unit_id !== actor.unit_id) {
    return errorResponse(403, "AUTHORIZATION_PERMISSION_DENIED", "Operacion no autorizada.", "AUTHORIZATION");
  }

  if (action === "close") {
    if (order.status !== "approved") {
      return errorResponse(409, "BUSINESS_INVALID_STATUS", "Solo se pueden cerrar OVs aprobadas.", "BUSINESS_RULE", "medium");
    }

    // Verify all flights are engine_shutdown
    const { data: flights } = await adminClient.from("flights")
      .select("id").eq("flight_order_id", flightOrderId).eq("closed", false);

    if (!flights || flights.length === 0) {
      return errorResponse(400, "VALIDATION_NO_FLIGHTS", "No hay vuelos activos en esta OV.", "VALIDATION", "medium");
    }

    for (const f of flights) {
      const { data: lastEvent } = await adminClient.from("flight_status_events")
        .select("status").eq("flight_id", f.id).order("occurred_at", { ascending: false }).limit(1).maybeSingle();
      if (!lastEvent || lastEvent.status !== "engine_shutdown") {
        return errorResponse(409, "BUSINESS_FLIGHTS_NOT_COMPLETE", "Todos los vuelos deben estar en motor apagado.", "BUSINESS_RULE", "medium");
      }
    }

    // Create closure request and close order
    const { error: closureError } = await adminClient.from("closure_requests").insert({
      flight_order_id: flightOrderId,
      status: "approved",
      requested_by: userData.user.id,
      reviewed_by: userData.user.id,
      notes: reason || "Cierre aprobado",
      requested_at: new Date().toISOString(),
      reviewed_at: new Date().toISOString(),
    });
    if (closureError) {
      return errorResponse(500, "DATA_CLOSURE_FAILED", "No se pudo crear el cierre.", "DATA");
    }

    const { error: updateError } = await adminClient.from("flight_orders")
      .update({ status: "closed", closed_at: new Date().toISOString(), closed_by: userData.user.id })
      .eq("id", flightOrderId);
    if (updateError) {
      return errorResponse(500, "DATA_ORDER_UPDATE_FAILED", "No se pudo cerrar la OV.", "DATA");
    }

    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id, actor_role: actor.role, actor_unit_id: actor.unit_id,
      action: "closure.approve", resource_type: "flight_orders", resource_id: flightOrderId,
      result: "success", metadata: { reason },
    });

    return jsonResponse({ ok: true, data: { status: "closed" }, meta: {} });
  }

  if (action === "reopen") {
    if (order.status !== "closed") {
      return errorResponse(409, "BUSINESS_INVALID_STATUS", "Solo se pueden reabrir OVs cerradas.", "BUSINESS_RULE", "medium");
    }
    if (!isGlobal) {
      return errorResponse(403, "AUTHORIZATION_PERMISSION_DENIED", "Solo Lider y General Admin pueden reabrir.", "AUTHORIZATION");
    }

    const { error: updateError } = await adminClient.from("flight_orders")
      .update({ status: "reopened", closed_at: null, closed_by: null })
      .eq("id", flightOrderId);
    if (updateError) {
      return errorResponse(500, "DATA_ORDER_UPDATE_FAILED", "No se pudo reabrir la OV.", "DATA");
    }

    await adminClient.from("closure_requests").insert({
      flight_order_id: flightOrderId,
      status: "reopened",
      requested_by: userData.user.id,
      notes: reason || "Reapertura solicitada",
      requested_at: new Date().toISOString(),
    });

    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id, actor_role: actor.role, actor_unit_id: actor.unit_id,
      action: "closure.reopen", resource_type: "flight_orders", resource_id: flightOrderId,
      result: "success", metadata: { reason },
    });

    return jsonResponse({ ok: true, data: { status: "reopened" }, meta: {} });
  }

  return errorResponse(400, "VALIDATION_INVALID_INPUT", "Accion no soportada.", "VALIDATION", "medium");
});
