import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const actions = new Set(["create", "update", "deactivate"]);
const globalRoles = new Set(["leader", "general_admin"]);
const validCategories = ["internacional", "nacional", "aerodromo", "helipuerto"];

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

  if (!actorProfile) {
    return errorResponse(
      403,
      "AUTHORIZATION_ROLE_REQUIRED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  if (actorProfile.status !== "active") {
    return errorResponse(
      403,
      actorProfile.status === "pending" ? "AUTH_PROFILE_PENDING" : "AUTH_USER_INACTIVE",
      "Usuario no habilitado para operar.",
      "AUTH",
    );
  }

  if (!globalRoles.has(actorProfile.role)) {
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile.role ?? null,
      actor_unit_id: actorProfile.unit_id ?? null,
      action: "route.manage",
      resource_type: "route",
      result: "denied",
      metadata: { reason: "role_not_global" },
    });
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const { data: hasPermission, error: permissionError } = await userClient.rpc(
    "has_permission",
    { permission_key: "routes.manage" },
  );
  if (permissionError || hasPermission !== true) {
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const payload = await req.json().catch(() => ({}));
  const action = String(payload.action ?? "");
  const routeId = payload.route_id === null ? null : String(payload.route_id ?? "");
  const airportName = String(payload.airport_name ?? "").trim();
  const category = String(payload.category ?? "internacional");
  const icaoCode = payload.icao_code ? String(payload.icao_code).trim().toUpperCase() : null;
  const iataCode = payload.iata_code ? String(payload.iata_code).trim().toUpperCase() : null;
  const country = String(payload.country ?? "").trim();
  const city = String(payload.city ?? "").trim();
  const latitude = payload.latitude === null || payload.latitude === undefined || payload.latitude === ""
    ? null
    : Number(payload.latitude);
  const longitude = payload.longitude === null || payload.longitude === undefined || payload.longitude === ""
    ? null
    : Number(payload.longitude);

  if (!actions.has(action)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Accion de ruta invalida.",
      "VALIDATION",
      "medium",
    );
  }

  if (action === "create" && (!airportName || !country || !city)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Nombre del aeropuerto, pais y ciudad son obligatorios.",
      "VALIDATION",
      "medium",
    );
  }

  if ((action === "update" || action === "deactivate") && !routeId) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "La ruta es obligatoria.",
      "VALIDATION",
      "medium",
    );
  }

  if (!validCategories.includes(category)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Categoria de ruta invalida.",
      "VALIDATION",
      "medium",
    );
  }

  if (icaoCode && !/^[A-Z]{4}$/.test(icaoCode)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "El codigo OACI debe tener 4 letras.",
      "VALIDATION",
      "medium",
    );
  }

  if (iataCode && !/^[A-Z]{3}$/.test(iataCode)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "El codigo IATA debe tener 3 letras.",
      "VALIDATION",
      "medium",
    );
  }

  if (latitude !== null && (isNaN(latitude) || latitude < -90 || latitude > 90)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Latitud invalida.",
      "VALIDATION",
      "medium",
    );
  }

  if (longitude !== null && (isNaN(longitude) || longitude < -180 || longitude > 180)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Longitud invalida.",
      "VALIDATION",
      "medium",
    );
  }

  let existingRoute: { id: string; active: boolean } | null = null;
  if (action === "update" || action === "deactivate") {
    const { data } = await adminClient
      .from("routes")
      .select("id,active")
      .eq("id", routeId)
      .maybeSingle();
    existingRoute = data;
    if (!existingRoute) {
      return errorResponse(
        404,
        "DATA_NOT_FOUND",
        "Ruta no encontrada.",
        "DATA",
        "medium",
      );
    }
  }

  let route;
  let routeError;

  if (action === "create") {
    const result = await adminClient
      .from("routes")
      .insert({
        airport_name: airportName,
        category,
        icao_code: icaoCode,
        iata_code: iataCode,
        country,
        city,
        latitude,
        longitude,
      })
      .select("id,airport_name,category,icao_code,iata_code,country,city,latitude,longitude")
      .single();
    route = result.data;
    routeError = result.error;
  }

  if (action === "update") {
    const updateData: Record<string, unknown> = {
      airport_name: airportName || undefined,
      category: category || undefined,
      icao_code: icaoCode,
      iata_code: iataCode,
      country: country || undefined,
      city: city || undefined,
      latitude,
      longitude,
    };
    Object.keys(updateData).forEach((k) => {
      if (updateData[k] === undefined) delete updateData[k];
    });
    const result = await adminClient
      .from("routes")
      .update(updateData)
      .eq("id", routeId)
      .select("id,airport_name,category,icao_code,iata_code,country,city,latitude,longitude")
      .single();
    route = result.data;
    routeError = result.error;
  }

  if (action === "deactivate") {
    const result = await adminClient
      .from("routes")
      .update({ active: false, deleted_at: new Date().toISOString() })
      .eq("id", routeId)
      .select("id,airport_name,category")
      .single();
    route = result.data;
    routeError = result.error;
  }

  if (routeError || !route) {
    const conflict = routeError?.code === "23505";
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile?.role ?? null,
      actor_unit_id: actorProfile?.unit_id ?? null,
      action: `route.${action}`,
      resource_type: "route",
      resource_id: routeId || null,
      result: "failed",
      metadata: {
        reason: conflict ? "conflict" : "save_failed",
        error_code: routeError?.code ?? null,
      },
    });
    return errorResponse(
      conflict ? 409 : 500,
      conflict ? "DATA_CONFLICT" : "SYSTEM_UNEXPECTED",
      conflict ? "Ya existe una ruta con esos datos." : "No se pudo guardar la ruta.",
      conflict ? "DATA" : "SYSTEM",
      conflict ? "medium" : "high",
    );
  }

  await adminClient.from("audit_logs").insert({
    actor_id: userData.user.id,
    actor_role: actorProfile?.role ?? null,
    actor_unit_id: actorProfile?.unit_id ?? null,
    action: `route.${action}`,
    resource_type: "route",
    resource_id: route.id,
    result: "success",
    metadata: {
      airport_name: route.airport_name,
      category: route.category,
    },
  });

  return jsonResponse({ ok: true, data: { route }, meta: {} });
});
