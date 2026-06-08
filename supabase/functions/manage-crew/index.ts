import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const actions = new Set(["create", "update", "deactivate", "move_squadron"]);
const globalRoles = new Set(["leader", "general_admin"]);
const unitRoles = new Set(["unit_command", "unit_admin", "ttaa"]);
const validCategories = ["pilot", "mechanic"];
const validQualifications = ["IP", "PS", "CO", "PM", "CP", "OB"];

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

  const auditDenied = async (reason: string, resourceId: string | null = null) => {
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile?.role ?? null,
      actor_unit_id: actorProfile?.unit_id ?? null,
      action: "crew.manage",
      resource_type: "crew_member",
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
    { permission_key: "crew.manage" },
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
  const crewMemberId = payload.crew_member_id === null ? null : String(payload.crew_member_id ?? "");
  const unitId = String(payload.unit_id ?? "");
  const grade = String(payload.grade ?? "").trim();
  const firstName = String(payload.first_name ?? "").trim();
  const lastName = String(payload.last_name ?? "").trim();
  const nsa = String(payload.nsa ?? "").trim();
  const crewCategory = String(payload.crew_category ?? "").trim();
  const appointmentDate = String(payload.appointment_date ?? "").trim();
  const qualifications: string[] =
    Array.isArray(payload.qualifications) ? payload.qualifications : [];
  const assignmentType = String(payload.assignment_type ?? "nato").trim();
  const callsign = String(payload.callsign ?? "").trim().toUpperCase() || null;
  const squadronId = payload.squadron_id ? String(payload.squadron_id) : null;

  if (!actions.has(action)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Accion de tripulante invalida.",
      "VALIDATION",
      "medium",
    );
  }

  if (!validCategories.includes(crewCategory)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Categoria de tripulante invalida. Use 'pilot' o 'mechanic'.",
      "VALIDATION",
      "medium",
    );
  }

  if (!["nato", "foraneo"].includes(assignmentType)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Tipo de asignacion invalido. Use 'nato' o 'foraneo'.",
      "VALIDATION",
      "medium",
    );
  }

  if (action !== "deactivate" && (!grade || !firstName || !lastName || !nsa || !unitId || !appointmentDate)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Grado, nombres, apellidos, NSA, unidad y fecha de nombramiento son obligatorios.",
      "VALIDATION",
      "medium",
    );
  }

  if ((action === "update" || action === "deactivate" || action === "move_squadron") && !crewMemberId) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "El tripulante es obligatorio.",
      "VALIDATION",
      "medium",
    );
  }

  if (action === "move_squadron" && !squadronId) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "El escuadron de destino es obligatorio.",
      "VALIDATION",
      "medium",
    );
  }

  if (nsa && nsa.length < 3) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "El NSA debe tener al menos 3 caracteres.",
      "VALIDATION",
      "medium",
    );
  }

  if (appointmentDate && isNaN(Date.parse(appointmentDate))) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "La fecha de nombramiento es invalida.",
      "VALIDATION",
      "medium",
    );
  }

  if (action !== "deactivate" && grade) {
    const { data: gradeRecord } = await adminClient
      .from("grades")
      .select("code,category")
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

    if (gradeRecord.category !== crewCategory) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        `El grado "${grade}" no corresponde a la categoria ${crewCategory}.`,
        "VALIDATION",
        "medium",
      );
    }
  }

  if (crewCategory === "pilot") {
    const invalidQuals = qualifications.filter(
      (q) => !validQualifications.includes(q),
    );
    if (invalidQuals.length > 0) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        `Calificaciones invalidas: ${invalidQuals.join(", ")}.`,
        "VALIDATION",
        "medium",
      );
    }
  }

  if (crewCategory === "mechanic" && qualifications.length > 0) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Los mecanicos no pueden tener calificaciones de vuelo.",
      "VALIDATION",
      "medium",
    );
  }

  const isGlobal = globalRoles.has(actorProfile.role);
  const actorUnitId = actorProfile.unit_id as string | null;
  const scopedUnitId = unitId || actorUnitId || "";

  if ((action === "create" || (action === "update" && unitId)) && !isGlobal && unitId !== actorUnitId) {
    await auditDenied("unit_scope_denied");
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  if (scopedUnitId && (action === "create" || (action === "update" && unitId))) {
    const { data: targetUnit } = await adminClient
      .from("units")
      .select("id")
      .eq("id", scopedUnitId)
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
  }

  let existingMember: { id: string; unit_id: string; active: boolean } | null = null;
  if (action === "update" || action === "deactivate") {
    const { data } = await adminClient
      .from("crew_members")
      .select("id,unit_id,active")
      .eq("id", crewMemberId)
      .maybeSingle();

    existingMember = data;
    if (!existingMember) {
      return errorResponse(
        404,
        "DATA_NOT_FOUND",
        "Tripulante no encontrado.",
        "DATA",
        "medium",
      );
    }

    if (!isGlobal && existingMember.unit_id !== actorUnitId) {
      await auditDenied("resource_scope_denied", crewMemberId);
      return errorResponse(
        403,
        "AUTHORIZATION_PERMISSION_DENIED",
        "Operacion no autorizada.",
        "AUTHORIZATION",
      );
    }

    if (!isGlobal && unitId && unitId !== actorUnitId) {
      await auditDenied("target_unit_scope_denied", crewMemberId);
      return errorResponse(
        403,
        "AUTHORIZATION_PERMISSION_DENIED",
        "Operacion no autorizada.",
        "AUTHORIZATION",
      );
    }
  }

  let member;
  let memberError;

  if (action === "create") {
    const insertData: Record<string, unknown> = {
      unit_id: unitId,
      grade,
      first_name: firstName,
      last_name: lastName,
      nsa,
      crew_category: crewCategory,
      appointment_date: appointmentDate,
      qualifications,
      assignment_type: assignmentType,
      ...(callsign ? { callsign } : {}),
      ...(squadronId ? { squadron_id: squadronId } : {}),
    };
    const result = await adminClient
      .from("crew_members")
      .insert(insertData)
      .select(
        "id,unit_id,grade,first_name,last_name,nsa,callsign,crew_category,assignment_type,appointment_date,active,qualifications,squadron_id",
      )
      .single();
    member = result.data;
    memberError = result.error;
  }

  if (action === "update") {
    const updateData: Record<string, unknown> = {};
    if (unitId) updateData.unit_id = unitId;
    if (grade) updateData.grade = grade;
    if (firstName) updateData.first_name = firstName;
    if (lastName) updateData.last_name = lastName;
    if (nsa) updateData.nsa = nsa;
    if (crewCategory) updateData.crew_category = crewCategory;
    if (appointmentDate) updateData.appointment_date = appointmentDate;
    if (assignmentType) updateData.assignment_type = assignmentType;
    if (callsign) updateData.callsign = callsign;
    if (squadronId !== undefined) updateData.squadron_id = squadronId;
    updateData.qualifications = qualifications;

    const result = await adminClient
      .from("crew_members")
      .update(updateData)
      .eq("id", crewMemberId)
      .select(
        "id,unit_id,grade,first_name,last_name,nsa,callsign,crew_category,assignment_type,appointment_date,active,qualifications,squadron_id",
      )
      .single();
    member = result.data;
    memberError = result.error;
  }

  if (action === "move_squadron") {
    const result = await adminClient
      .from("crew_members")
      .update({ squadron_id: squadronId, updated_at: new Date().toISOString() })
      .eq("id", crewMemberId)
      .select("id,squadron_id")
      .single();
    member = result.data;
    memberError = result.error;
  }

  if (action === "deactivate") {
    const result = await adminClient
      .from("crew_members")
      .update({ active: false, deleted_at: new Date().toISOString() })
      .eq("id", crewMemberId)
      .select(
        "id,unit_id,grade,first_name,last_name,nsa,callsign,crew_category,assignment_type,appointment_date,active,qualifications",
      )
      .single();
    member = result.data;
    memberError = result.error;
  }

  if (memberError || !member) {
    const conflict = memberError?.code === "23505";
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile?.role ?? null,
      actor_unit_id: actorProfile?.unit_id ?? null,
      action: `crew.${action}`,
      resource_type: "crew_member",
      resource_id: crewMemberId || null,
      result: "failed",
      metadata: {
        reason: conflict ? "conflict" : "save_failed",
        error_code: memberError?.code ?? null,
      },
    });
    return errorResponse(
      conflict ? 409 : 500,
      conflict ? "DATA_CONFLICT" : "SYSTEM_UNEXPECTED",
      conflict ? "Ya existe un tripulante con ese NSA." : "No se pudo guardar el tripulante.",
      conflict ? "DATA" : "SYSTEM",
      conflict ? "medium" : "high",
    );
  }

  await adminClient.from("audit_logs").insert({
    actor_id: userData.user.id,
    actor_role: actorProfile?.role ?? null,
    actor_unit_id: actorProfile?.unit_id ?? null,
    action: `crew.${action}`,
    resource_type: "crew_member",
    resource_id: member.id,
    result: "success",
    metadata: {
      nsa: member.nsa,
      grade: member.grade,
      first_name: member.first_name,
      last_name: member.last_name,
      crew_category: member.crew_category,
    },
  });

  return jsonResponse({ ok: true, data: { member }, meta: {} });
});
