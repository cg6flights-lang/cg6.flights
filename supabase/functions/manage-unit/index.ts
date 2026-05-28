import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const actions = new Set(["create", "update", "deactivate"]);

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse(
      405,
      "VALIDATION_METHOD_NOT_ALLOWED",
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
      "SYSTEM_MISSING_ENV",
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

  const { data: hasPermission, error: permissionError } = await userClient.rpc(
    "has_permission",
    { permission_key: "units.manage" },
  );
  if (permissionError || hasPermission !== true) {
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      action: "units.manage",
      resource_type: "units",
      result: "denied",
      metadata: { reason: "missing_permission" },
    });
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const payload = await req.json().catch(() => ({}));
  const action = String(payload.action ?? "");
  const unitId = payload.unit_id === null ? null : String(payload.unit_id ?? "");
  const code = String(payload.code ?? "").trim().toUpperCase();
  const name = String(payload.name ?? "").trim();
  const active = payload.active === undefined ? true : payload.active === true;

  if (!actions.has(action)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Accion de unidad invalida.",
      "VALIDATION",
      "medium",
    );
  }

  if ((action === "create" || action === "update") && (!code || !name)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Codigo y nombre son obligatorios.",
      "VALIDATION",
      "medium",
    );
  }

  if ((action === "update" || action === "deactivate") && !unitId) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "La unidad es obligatoria.",
      "VALIDATION",
      "medium",
    );
  }

  const { data: actorProfile } = await adminClient
    .from("profiles")
    .select("role,unit_id")
    .eq("id", userData.user.id)
    .maybeSingle();

  let unit;
  let unitError;

  if (action === "create") {
    const result = await adminClient
      .from("units")
      .insert({ code, name, active })
      .select("id,code,name,active")
      .single();
    unit = result.data;
    unitError = result.error;
  }

  if (action === "update") {
    const result = await adminClient
      .from("units")
      .update({ code, name, active })
      .eq("id", unitId)
      .select("id,code,name,active")
      .single();
    unit = result.data;
    unitError = result.error;
  }

  if (action === "deactivate") {
    const result = await adminClient
      .from("units")
      .update({ active: false, deleted_at: new Date().toISOString() })
      .eq("id", unitId)
      .select("id,code,name,active")
      .single();
    unit = result.data;
    unitError = result.error;
  }

  if (unitError || !unit) {
    const conflict = unitError?.code === "23505";
    return errorResponse(
      conflict ? 409 : 500,
      conflict ? "DATA_CONFLICT" : "DATA_UNIT_SAVE_FAILED",
      conflict ? "Ya existe una unidad con ese codigo." : "No se pudo guardar la unidad.",
      conflict ? "DATA" : "SYSTEM",
      conflict ? "medium" : "high",
    );
  }

  await adminClient.from("audit_logs").insert({
    actor_id: userData.user.id,
    actor_role: actorProfile?.role ?? null,
    actor_unit_id: actorProfile?.unit_id ?? null,
    action: `units.${action}`,
    resource_type: "units",
    resource_id: unit.id,
    result: "success",
    metadata: { code: unit.code, name: unit.name, active: unit.active },
  });

  return jsonResponse({ ok: true, data: { unit }, meta: {} });
});
