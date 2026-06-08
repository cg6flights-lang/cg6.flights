import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const actions = new Set(["create", "update", "deactivate"]);
const globalRoles = new Set(["leader", "general_admin"]);
const unitRoles = new Set(["unit_command", "unit_admin", "ttaa"]);
const validStatuses = ["operational", "inoperative", "maintenance"];

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
      action: "aircraft.manage",
      resource_type: "aircraft",
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
    { permission_key: "aircraft.manage" },
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
  const aircraftId = payload.aircraft_id === null ? null : String(payload.aircraft_id ?? "");
  const unitId = String(payload.unit_id ?? "");
  const tailNumber = String(payload.tail_number ?? "").trim().toUpperCase();
  const model = String(payload.model ?? "").trim();
  const manufacturer = String(payload.manufacturer ?? "").trim();
  const serialNumber = payload.serial_number ? String(payload.serial_number).trim() : null;
  const year = payload.year === null || payload.year === undefined || payload.year === ""
    ? null
    : Number(payload.year);
  const status = String(payload.status ?? "operational");
  const inoperativeReason = payload.inoperative_reason
    ? String(payload.inoperative_reason).trim()
    : null;
  const obTailNumber = payload.ob_tail_number
    ? String(payload.ob_tail_number).trim().toUpperCase()
    : null;
  const displayRegistration = String(payload.display_registration ?? "FAP");
  const validRegistrations = ["FAP", "OB"];
  const squadronId = payload.squadron_id ? String(payload.squadron_id) : null;
  const hasSquadronIds = Array.isArray(payload.squadron_ids);
  const squadronIds: string[] = hasSquadronIds
    ? [...new Set(payload.squadron_ids.map((id: unknown) => String(id)).filter((id: string) => id.length > 0))]
    : [];

  if (!actions.has(action)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Accion de aeronave invalida.",
      "VALIDATION",
      "medium",
    );
  }

  if (action === "create" && (!tailNumber || !model || !manufacturer || !unitId)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Matricula, modelo, fabricante y unidad son obligatorios.",
      "VALIDATION",
      "medium",
    );
  }

  if (action === "create" && !status) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "El estado de aeronave es obligatorio.",
      "VALIDATION",
      "medium",
    );
  }

  if ((action === "update" || action === "deactivate") && !aircraftId) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "La aeronave es obligatoria.",
      "VALIDATION",
      "medium",
    );
  }

  if (!validStatuses.includes(status)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Estado de aeronave invalido.",
      "VALIDATION",
      "medium",
    );
  }

  if (status === "inoperative" && action !== "deactivate" && !inoperativeReason) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "El motivo de inoperatividad es obligatorio cuando la aeronave esta inoperativa.",
      "VALIDATION",
      "medium",
    );
  }

  if (year !== null && (!Number.isInteger(year) || year < 1900 || year > 2100)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "El año de aeronave es invalido.",
      "VALIDATION",
      "medium",
    );
  }

  if (!validRegistrations.includes(displayRegistration)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Tipo de matricula a mostrar invalido.",
      "VALIDATION",
      "medium",
    );
  }

  const isGlobal = globalRoles.has(actorProfile.role);
  const actorUnitId = actorProfile.unit_id as string | null;
  const scopedUnitId = unitId || actorUnitId || "";

  if (action === "create" && !isGlobal && unitId !== actorUnitId) {
    await auditDenied("unit_scope_denied");
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  if ((action === "create" || (action === "update" && unitId)) && scopedUnitId) {
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

  let existingAircraft: { id: string; unit_id: string; active: boolean; status: string } | null = null;
  let previousStatus: string | undefined;
  if (action === "update" || action === "deactivate") {
    const { data } = await adminClient
      .from("aircraft")
      .select("id,unit_id,active,status")
      .eq("id", aircraftId)
      .maybeSingle();

    existingAircraft = data;
    previousStatus = existingAircraft?.status;
    if (!existingAircraft) {
      return errorResponse(
        404,
        "DATA_NOT_FOUND",
        "Aeronave no encontrada.",
        "DATA",
        "medium",
      );
    }

    if (!isGlobal && existingAircraft.unit_id !== actorUnitId) {
      await auditDenied("resource_scope_denied", aircraftId);
      return errorResponse(
        403,
        "AUTHORIZATION_PERMISSION_DENIED",
        "Operacion no autorizada.",
        "AUTHORIZATION",
      );
    }

    if (!isGlobal && unitId && unitId !== actorUnitId) {
      await auditDenied("target_unit_scope_denied", aircraftId);
      return errorResponse(
        403,
        "AUTHORIZATION_PERMISSION_DENIED",
        "Operacion no autorizada.",
        "AUTHORIZATION",
      );
    }
  }

  let aircraft;
  let aircraftError;

  if (action === "create") {
    const insertData: Record<string, unknown> = {
      unit_id: unitId,
      tail_number: tailNumber,
      model,
      manufacturer,
      serial_number: serialNumber,
      year,
      status,
      inoperative_reason: inoperativeReason,
      ob_tail_number: obTailNumber,
      display_registration: displayRegistration,
      squadron_id: squadronId,
    };
    const result = await adminClient
      .from("aircraft")
      .insert(insertData)
      .select(
        "id,tail_number,ob_tail_number,display_registration,model,manufacturer,serial_number,year,status,unit_id,inoperative_reason,squadron_id",
      )
      .single();
    aircraft = result.data;
    aircraftError = result.error;

    if (aircraft && !aircraftError) {
      await adminClient.from("aircraft_status_history").insert({
        aircraft_id: aircraft.id,
        unit_id: aircraft.unit_id,
        status: aircraft.status,
      });
    }
  }

  if (action === "update") {
    const updateData: Record<string, unknown> = {
      tail_number: tailNumber || undefined,
      model: model || undefined,
      manufacturer: manufacturer || undefined,
      serial_number: serialNumber,
      year,
      status,
      inoperative_reason: inoperativeReason,
      ob_tail_number: obTailNumber,
      display_registration: displayRegistration,
      squadron_id: squadronId,
    };
    if (unitId) updateData.unit_id = unitId;

    Object.keys(updateData).forEach((k) => {
      if (updateData[k] === undefined) delete updateData[k];
    });

    const result = await adminClient
      .from("aircraft")
      .update(updateData)
      .eq("id", aircraftId)
      .select(
        "id,tail_number,ob_tail_number,display_registration,model,manufacturer,serial_number,year,status,unit_id,inoperative_reason,squadron_id",
      )
      .single();
    aircraft = result.data;
    aircraftError = result.error;

    if (aircraft && !aircraftError && previousStatus && previousStatus !== status) {
      await adminClient.from("aircraft_status_history").insert({
        aircraft_id: aircraft.id,
        unit_id: aircraft.unit_id,
        status: aircraft.status,
      });
    }
  }

  if (action === "deactivate") {
    const result = await adminClient
      .from("aircraft")
      .update({ active: false, deleted_at: new Date().toISOString() })
      .eq("id", aircraftId)
      .select(
        "id,tail_number,model,manufacturer,serial_number,year,status,unit_id,inoperative_reason",
      )
      .single();
    aircraft = result.data;
    aircraftError = result.error;
  }

  // Sync aircraft_squadrons junction table (M:N) when caller sends the field.
  let squadronSyncError = null;
  if (!aircraftError && aircraft && (action === "create" || action === "update") && hasSquadronIds) {
    const deleteResult = await adminClient
      .from("aircraft_squadrons")
      .delete()
      .eq("aircraft_id", aircraft.id);
    squadronSyncError = deleteResult.error;

    if (!squadronSyncError && squadronIds.length > 0) {
      const rows = squadronIds.map((sid: string) => ({
        aircraft_id: aircraft.id,
        squadron_id: sid,
      }));
      const insertResult = await adminClient
        .from("aircraft_squadrons")
        .insert(rows);
      squadronSyncError = insertResult.error;
    }
  }

  if (!aircraftError && squadronSyncError) {
    aircraftError = squadronSyncError;
  }

  if (aircraftError || !aircraft) {
    const conflict = aircraftError?.code === "23505";
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile?.role ?? null,
      actor_unit_id: actorProfile?.unit_id ?? null,
      action: `aircraft.${action}`,
      resource_type: "aircraft",
      resource_id: aircraftId || null,
      result: "failed",
      metadata: {
        reason: conflict ? "conflict" : "save_failed",
        error_code: aircraftError?.code ?? null,
      },
    });
    return errorResponse(
      conflict ? 409 : 500,
      conflict ? "DATA_CONFLICT" : "SYSTEM_UNEXPECTED",
      conflict ? "Ya existe una aeronave con esa matricula." : "No se pudo guardar la aeronave.",
      conflict ? "DATA" : "SYSTEM",
      conflict ? "medium" : "high",
    );
  }

  await adminClient.from("audit_logs").insert({
    actor_id: userData.user.id,
    actor_role: actorProfile?.role ?? null,
    actor_unit_id: actorProfile?.unit_id ?? null,
    action: `aircraft.${action}`,
    resource_type: "aircraft",
    resource_id: aircraft.id,
    result: "success",
    metadata: {
      tail_number: aircraft.tail_number,
      model: aircraft.model,
      manufacturer: aircraft.manufacturer,
      status: aircraft.status,
    },
  });

  return jsonResponse({ ok: true, data: { aircraft }, meta: {} });
});
