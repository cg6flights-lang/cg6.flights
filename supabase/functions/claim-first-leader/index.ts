import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

  const user = userData.user;
  const { count: leaderCount, error: countError } = await adminClient
    .from("profiles")
    .select("id", { count: "exact", head: true })
    .eq("role", "leader")
    .eq("status", "active");

  if (countError) {
    return errorResponse(
      500,
      "DATA_LEADER_COUNT_FAILED",
      "No se pudo validar el Lider existente.",
      "DATA",
    );
  }

  if ((leaderCount ?? 0) > 0) {
    await adminClient.from("audit_logs").insert({
      actor_id: user.id,
      action: "leader.claim_first",
      resource_type: "profiles",
      resource_id: user.id,
      result: "denied",
      metadata: { reason: "leader_already_exists" },
    });
    return errorResponse(
      409,
      "BUSINESS_LEADER_ALREADY_EXISTS",
      "Ya existe un Lider activo.",
      "BUSINESS_RULE",
    );
  }

  const fallbackName = String(
    user.user_metadata?.display_name ?? user.email ?? "Lider",
  );

  const { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .upsert({
      id: user.id,
      email: user.email ?? "",
      display_name: fallbackName,
      status: "active",
      role: "leader",
      unit_id: null,
    }, { onConflict: "id" })
    .select("id,email,display_name,status,role,unit_id")
    .single();

  if (profileError) {
    return errorResponse(
      500,
      "DATA_LEADER_CLAIM_FAILED",
      "No se pudo activar el primer Lider.",
      "DATA",
    );
  }

  await adminClient.from("audit_logs").insert({
    actor_id: user.id,
    actor_role: "leader",
    action: "leader.claim_first",
    resource_type: "profiles",
    resource_id: user.id,
    result: "success",
    metadata: { bootstrap: true },
  });

  return jsonResponse({ ok: true, data: { profile }, meta: {} });
});
