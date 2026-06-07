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

// Password strength validation
function checkStrength(password: string): { valid: boolean; missing: string[] } {
  const missing: string[] = [];
  if (password.length < 6) missing.push("min_length");
  if (!/[A-Z]/.test(password)) missing.push("uppercase");
  if (!/[a-z]/.test(password)) missing.push("lowercase");
  if (!/[0-9]/.test(password)) missing.push("digit");
  if (!/[^A-Za-z0-9]/.test(password)) missing.push("special_char");
  return { valid: missing.length === 0, missing };
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

  const payload = await req.json().catch(() => ({}));
  const currentPassword = String(payload.current_password ?? "");
  const newPassword = String(payload.new_password ?? "");

  if (!currentPassword || !newPassword) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Contraseña actual y nueva son obligatorias.",
      "VALIDATION",
      "medium",
    );
  }

  // Verify current password
  const userEmail = userData.user.email;
  if (!userEmail) {
    return errorResponse(
      500,
      "AUTH_EMAIL_MISSING",
      "No se pudo verificar la identidad.",
      "AUTH",
    );
  }

  const { error: signInError } = await userClient.auth.signInWithPassword({
    email: userEmail,
    password: currentPassword,
  });

  if (signInError) {
    return errorResponse(
      401,
      "AUTH_INVALID_CURRENT_PASSWORD",
      "La contraseña actual es incorrecta.",
      "AUTH",
      "medium",
    );
  }

  // Validate new password strength
  const strength = checkStrength(newPassword);
  if (!strength.valid) {
    return errorResponse(
      400,
      "VALIDATION_WEAK_PASSWORD",
      `La nueva contraseña no cumple los requisitos: ${strength.missing.join(", ")}.`,
      "VALIDATION",
      "medium",
    );
  }

  // Change password via admin API
  const { error: updateError } = await adminClient.auth.admin.updateUserById(
    userData.user.id,
    { password: newPassword },
  );

  if (updateError) {
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      action: "profile.change_password",
      resource_type: "profiles",
      resource_id: userData.user.id,
      result: "failed",
      metadata: { reason: "update_failed", error_code: updateError.code ?? null },
    });
    return errorResponse(
      500,
      "SYSTEM_PASSWORD_UPDATE_FAILED",
      "No se pudo cambiar la contraseña.",
      "SYSTEM",
    );
  }

  // Update password_changed_at in profile
  const now = new Date().toISOString();
  const { error: profileError } = await adminClient
    .from("profiles")
    .update({ password_changed_at: now })
    .eq("id", userData.user.id);

  if (profileError) {
    // Non-fatal — password was changed successfully
    console.error("Failed to update password_changed_at:", profileError.message);
  }

  await adminClient.from("audit_logs").insert({
    actor_id: userData.user.id,
    action: "profile.change_password",
    resource_type: "profiles",
    resource_id: userData.user.id,
    result: "success",
    metadata: { changed_at: now },
  });

  return jsonResponse({ ok: true, data: { password_changed_at: now }, meta: {} });
});
