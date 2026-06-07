import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type ErrorCategory =
  | "AUTH"
  | "AUTHORIZATION"
  | "VALIDATION"
  | "BUSINESS_RULE"
  | "DATA"
  | "NETWORK"
  | "STORAGE"
  | "REALTIME"
  | "EXPORT"
  | "SYSTEM";

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
  category: ErrorCategory,
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
  const displayName = typeof payload.display_name === "string"
    ? payload.display_name.trim()
    : "";
  const user = userData.user;
  const fallbackName =
    displayName || String(user.user_metadata?.display_name ?? user.email ?? "Usuario");

  // New extended fields
  const firstName = typeof payload.first_name === "string" ? payload.first_name.trim() : null;
  const lastName = typeof payload.last_name === "string" ? payload.last_name.trim() : null;
  const documentType = typeof payload.document_type === "string" ? payload.document_type.trim() : null;
  const documentId = typeof payload.document_id === "string" ? payload.document_id.trim() : null;
  const phoneCountryCode = typeof payload.phone_country_code === "string" ? payload.phone_country_code.trim() : null;
  const phone = typeof payload.phone === "string" ? payload.phone.trim() : null;
  const birthDate = typeof payload.birth_date === "string" ? payload.birth_date.trim() : null;
  const grade = typeof payload.grade === "string" ? payload.grade.trim() : null;

  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const upsertData: Record<string, unknown> = {
    id: user.id,
    email: user.email ?? "",
    display_name: fallbackName,
    status: "pending",
  };
  if (firstName) upsertData.first_name = firstName;
  if (lastName) upsertData.last_name = lastName;
  if (documentType) upsertData.document_type = documentType;
  if (documentId) upsertData.document_id = documentId;
  if (phoneCountryCode) upsertData.phone_country_code = phoneCountryCode;
  if (phone) upsertData.phone = phone;
  if (birthDate) upsertData.birth_date = birthDate;
  if (grade) upsertData.grade = grade;

  const { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .upsert(upsertData, { onConflict: "id", ignoreDuplicates: true })
    .select("id,email,display_name,status,role,unit_id,first_name,last_name,document_type,document_id,phone_country_code,phone,birth_date,grade,avatar_path,password_changed_at")
    .single();

  if (profileError) {
    return errorResponse(
      500,
      "DATA_PROFILE_BOOTSTRAP_FAILED",
      "No se pudo preparar el perfil.",
      "DATA",
    );
  }

  return jsonResponse({
    ok: true,
    data: { profile },
    meta: { request_id: req.headers.get("X-CG6-Request-Id") },
  });
});
