import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const actions = new Set(["create", "deactivate"]);
const globalRoles = new Set(["leader", "general_admin"]);
const unitRoles = new Set(["unit_command", "unit_admin", "ttaa"]);
const roles = new Set(["leader", "general_admin", "unit_command", "unit_admin", "ttaa"]);
const statuses = new Set(["pending", "active", "inactive", "rejected"]);

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

  const { data: actorProfile } = await adminClient
    .from("profiles")
    .select("role,unit_id,status")
    .eq("id", userData.user.id)
    .maybeSingle();

  const auditDenied = async (reason: string, resourceId: string | null = null) => {
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile?.role ?? null,
      actor_unit_id: actorProfile?.unit_id ?? null,
      action: "users.manage",
      resource_type: "profiles",
      resource_id: resourceId,
      result: "denied",
      metadata: { reason },
    });
  };

  if (!actorProfile) {
    await auditDenied("profile_missing");
    return errorResponse(
      403,
      "AUTHORIZATION_ROLE_REQUIRED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  if (actorProfile.status !== "active") {
    await auditDenied("profile_not_active");
    return errorResponse(
      403,
      actorProfile.status === "pending" ? "AUTH_PROFILE_PENDING" : "AUTH_USER_INACTIVE",
      "Usuario no habilitado para operar.",
      "AUTH",
    );
  }

  if (!actorProfile.role) {
    await auditDenied("role_missing");
    return errorResponse(
      403,
      "AUTHORIZATION_ROLE_REQUIRED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  if (unitRoles.has(actorProfile.role) && !actorProfile.unit_id) {
    await auditDenied("unit_missing");
    return errorResponse(
      403,
      "AUTHORIZATION_UNIT_REQUIRED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const { data: hasPermission, error: permissionError } = await userClient.rpc(
    "has_permission",
    { permission_key: "users.manage" },
  );
  if (permissionError || hasPermission !== true) {
    await auditDenied("missing_permission");
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const payload = await req.json().catch(() => ({}));
  const action = String(payload.action ?? "");
  const email = String(payload.email ?? "").trim().toLowerCase();
  const password = String(payload.password ?? "");
  const displayName = String(payload.display_name ?? "").trim();
  const role = payload.role === null ? null : String(payload.role ?? "");
  const unitId = payload.unit_id === null ? null : String(payload.unit_id ?? "");
  const status = String(payload.status ?? "");

  // Extended profile fields
  const firstName = typeof payload.first_name === "string" ? payload.first_name.trim() : null;
  const lastName = typeof payload.last_name === "string" ? payload.last_name.trim() : null;
  const documentType = typeof payload.document_type === "string" ? payload.document_type.trim() : null;
  const documentId = typeof payload.document_id === "string" ? payload.document_id.trim() : null;
  const phoneCountryCode = typeof payload.phone_country_code === "string" ? payload.phone_country_code.trim() : null;
  const phone = typeof payload.phone === "string" ? payload.phone.trim() : null;
  const birthDate = typeof payload.birth_date === "string" ? payload.birth_date.trim() : null;
  const grade = typeof payload.grade === "string" ? payload.grade.trim() : null;

  if (!actions.has(action)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Accion de usuario invalida.",
      "VALIDATION",
      "medium",
    );
  }

  if (action === "create") {
    if (!email || !password || !displayName || !statuses.has(status)) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        "Email, contraseña, nombre y estado son obligatorios.",
        "VALIDATION",
        "medium",
      );
    }

    if (password.length < 6) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        "La contraseña debe tener al menos 6 caracteres.",
        "VALIDATION",
        "medium",
      );
    }

    if (role !== null && !roles.has(role)) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        "Rol invalido.",
        "VALIDATION",
        "medium",
      );
    }

    if (role !== null && unitRoles.has(role) && !unitId) {
      return errorResponse(
        409,
        "AUTHORIZATION_UNIT_REQUIRED",
        "Los roles de unidad requieren una unidad.",
        "AUTHORIZATION",
      );
    }

    // Validate document_type
    if (documentType && !["dni", "passport"].includes(documentType)) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        "Tipo de documento invalido. Use 'dni' o 'passport'.",
        "VALIDATION",
        "medium",
      );
    }

    // Validate grade references a valid active grade
    if (grade) {
      const { data: gradeRecord } = await adminClient
        .from("grades")
        .select("code")
        .eq("code", grade)
        .eq("active", true)
        .maybeSingle();
      if (!gradeRecord) {
        return errorResponse(
          400,
          "VALIDATION_INVALID_INPUT",
          `El grado "${grade}" no es valido.`,
          "VALIDATION",
          "medium",
        );
      }
    }

    // Validate unit exists and is active
    if (unitId) {
      const { data: targetUnit } = await adminClient
        .from("units")
        .select("id")
        .eq("id", unitId)
        .eq("active", true)
        .maybeSingle();

      if (!targetUnit) {
        return errorResponse(
          404,
          "DATA_NOT_FOUND",
          "Unidad no encontrada o inactiva.",
          "DATA",
          "medium",
        );
      }

      // Unit-scoped roles can only create users in their own unit
      const isGlobal = globalRoles.has(actorProfile.role);
      if (!isGlobal && unitId !== actorProfile.unit_id) {
        await auditDenied("unit_scope_denied");
        return errorResponse(
          403,
          "AUTHORIZATION_PERMISSION_DENIED",
          "Operacion no autorizada.",
          "AUTHORIZATION",
        );
      }
    }

    // Business rule: max 1 active leader
    if (role === "leader" && status === "active") {
      const { count } = await adminClient
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "leader")
        .eq("status", "active");
      if ((count ?? 0) > 0) {
        return errorResponse(
          409,
          "BUSINESS_LEADER_LIMIT_REACHED",
          "Solo puede existir un Lider activo.",
          "BUSINESS_RULE",
        );
      }
    }

    // Business rule: max 5 active general admins
    if (role === "general_admin" && status === "active") {
      const { count } = await adminClient
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "general_admin")
        .eq("status", "active");
      if ((count ?? 0) >= 5) {
        return errorResponse(
          409,
          "BUSINESS_GENERAL_ADMIN_LIMIT_REACHED",
          "Solo puede haber cinco Administradores Generales activos.",
          "BUSINESS_RULE",
        );
      }
    }

    // Check if email already exists in auth
    const { data: existingUsers } = await adminClient.auth.admin.listUsers({
      page: 1,
      perPage: 1,
    });

    // Create auth user via admin API
    const { data: newUser, error: createError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: displayName },
    });

    if (createError || !newUser.user) {
      const conflict = createError?.message?.includes("already") ?? false;
      await adminClient.from("audit_logs").insert({
        actor_id: userData.user.id,
        actor_role: actorProfile?.role ?? null,
        actor_unit_id: actorProfile?.unit_id ?? null,
        action: "users.create",
        resource_type: "profiles",
        result: "failed",
        metadata: {
          reason: conflict ? "email_conflict" : "auth_create_failed",
          error_code: createError?.code ?? null,
        },
      });
      return errorResponse(
        conflict ? 409 : 500,
        conflict ? "DATA_CONFLICT" : "SYSTEM_UNEXPECTED",
        conflict ? "Ya existe un usuario con ese email." : "No se pudo crear el usuario.",
        conflict ? "DATA" : "SYSTEM",
        conflict ? "medium" : "high",
      );
    }

    const userId = newUser.user.id;

    // Create or update the profile
    const upsertData: Record<string, unknown> = {
      id: userId,
      email,
      display_name: displayName,
      status,
      role,
      unit_id: unitId,
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
      .upsert(upsertData, { onConflict: "id" })
      .select("id,email,display_name,status,role,unit_id,first_name,last_name,document_type,document_id,phone_country_code,phone,birth_date,grade,avatar_path,password_changed_at")
      .single();

    if (profileError) {
      await adminClient.from("audit_logs").insert({
        actor_id: userData.user.id,
        actor_role: actorProfile?.role ?? null,
        actor_unit_id: actorProfile?.unit_id ?? null,
        action: "users.create",
        resource_type: "profiles",
        resource_id: userId,
        result: "failed",
        metadata: {
          reason: "profile_save_failed",
          error_code: profileError.code ?? null,
        },
      });
      return errorResponse(
        500,
        "DATA_PROFILE_SAVE_FAILED",
        "Usuario creado pero no se pudo guardar el perfil.",
        "DATA",
      );
    }

    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile?.role ?? null,
      actor_unit_id: actorProfile?.unit_id ?? null,
      action: "users.create",
      resource_type: "profiles",
      resource_id: userId,
      result: "success",
      metadata: { email, display_name: displayName, role, unit_id: unitId, status },
    });

    return jsonResponse({ ok: true, data: { profile }, meta: {} });
  }

  // ── Deactivate ────────────────────────────────────────────────────────
  if (action === "deactivate") {
    const targetUserId = String(payload.user_id ?? "");
    if (!targetUserId) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        "ID de usuario obligatorio.",
        "VALIDATION",
        "medium",
      );
    }

    const isGlobal = globalRoles.has(actorProfile.role);

    // Check target profile exists and scope
    const { data: targetProfile } = await adminClient
      .from("profiles")
      .select("id,role,unit_id,status")
      .eq("id", targetUserId)
      .maybeSingle();

    if (!targetProfile) {
      return errorResponse(
        404,
        "DATA_NOT_FOUND",
        "Usuario no encontrado.",
        "DATA",
        "medium",
      );
    }

    if (!isGlobal && targetProfile.unit_id !== actorProfile.unit_id) {
      await auditDenied("resource_scope_denied", targetUserId);
      return errorResponse(
        403,
        "AUTHORIZATION_PERMISSION_DENIED",
        "Operacion no autorizada.",
        "AUTHORIZATION",
      );
    }

    // Cannot deactivate yourself
    if (targetUserId === userData.user.id) {
      return errorResponse(
        409,
        "BUSINESS_SELF_DEACTIVATE",
        "No puedes desactivar tu propio usuario.",
        "BUSINESS_RULE",
        "medium",
      );
    }

    const { error: updateError } = await adminClient
      .from("profiles")
      .update({ status: "inactive" })
      .eq("id", targetUserId);

    if (updateError) {
      await adminClient.from("audit_logs").insert({
        actor_id: userData.user.id,
        actor_role: actorProfile?.role ?? null,
        actor_unit_id: actorProfile?.unit_id ?? null,
        action: "users.deactivate",
        resource_type: "profiles",
        resource_id: targetUserId,
        result: "failed",
        metadata: { reason: "update_failed", error_code: updateError.code ?? null },
      });
      return errorResponse(
        500,
        "DATA_USER_UPDATE_FAILED",
        "No se pudo desactivar el usuario.",
        "DATA",
      );
    }

    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile?.role ?? null,
      actor_unit_id: actorProfile?.unit_id ?? null,
      action: "users.deactivate",
      resource_type: "profiles",
      resource_id: targetUserId,
      result: "success",
      metadata: { previous_status: targetProfile.status },
    });

    return jsonResponse({ ok: true, data: { id: targetUserId, status: "inactive" }, meta: {} });
  }

  return errorResponse(
    400,
    "VALIDATION_INVALID_INPUT",
    "Accion no soportada.",
    "VALIDATION",
    "medium",
  );
});
