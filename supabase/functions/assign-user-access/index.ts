import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const roles = new Set([
  "leader",
  "general_admin",
  "unit_command",
  "unit_admin",
  "ttaa",
]);
const statuses = new Set(["pending", "active", "inactive", "rejected"]);
const unitRoles = new Set(["unit_command", "unit_admin", "ttaa"]);

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
    { permission_key: "users.assign_access" },
  );
  if (permissionError || hasPermission !== true) {
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      action: "users.assign_access",
      resource_type: "profiles",
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
  const targetUserId = typeof payload.user_id === "string" ? payload.user_id : "";
  const role = payload.role === null ? null : String(payload.role ?? "");
  const unitId = payload.unit_id === null ? null : String(payload.unit_id ?? "");
  const status = String(payload.status ?? "");

  if (!targetUserId || !statuses.has(status) || (role !== null && !roles.has(role))) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Payload invalido.",
      "VALIDATION",
      "medium",
    );
  }

  if (role !== null && unitRoles.has(role) && !unitId) {
    return errorResponse(
      409,
      "AUTHORIZATION_UNIT_REQUIRED",
      "Los roles de unidad requieren unidad.",
      "AUTHORIZATION",
    );
  }

  if (role === "leader" && status === "active") {
    const { count } = await adminClient
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", "leader")
      .eq("status", "active")
      .neq("id", targetUserId);
    if ((count ?? 0) > 0) {
      return errorResponse(
        409,
        "BUSINESS_LEADER_LIMIT_REACHED",
        "Solo puede existir un Lider activo.",
        "BUSINESS_RULE",
      );
    }
  }

  if (role === "general_admin" && status === "active") {
    const { count } = await adminClient
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", "general_admin")
      .eq("status", "active")
      .neq("id", targetUserId);
    if ((count ?? 0) >= 5) {
      return errorResponse(
        409,
        "BUSINESS_GENERAL_ADMIN_LIMIT_REACHED",
        "Solo puede haber cinco Administradores Generales activos.",
        "BUSINESS_RULE",
      );
    }
  }

  const { data: actorProfile } = await adminClient
    .from("profiles")
    .select("role,unit_id")
    .eq("id", userData.user.id)
    .maybeSingle();

  const { data: profile, error: updateError } = await adminClient
    .from("profiles")
    .update({ role, unit_id: unitId, status })
    .eq("id", targetUserId)
    .select("id,email,display_name,status,role,unit_id")
    .single();

  if (updateError) {
    return errorResponse(
      500,
      "DATA_USER_ACCESS_UPDATE_FAILED",
      "No se pudo actualizar el acceso del usuario.",
      "DATA",
    );
  }

  await adminClient.from("audit_logs").insert({
    actor_id: userData.user.id,
    actor_role: actorProfile?.role ?? null,
    actor_unit_id: actorProfile?.unit_id ?? null,
    action: "users.assign_access",
    resource_type: "profiles",
    resource_id: targetUserId,
    result: "success",
    metadata: { role, unit_id: unitId, status },
  });

  return jsonResponse({ ok: true, data: { profile }, meta: {} });
});
