import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const actions = new Set([
  "create", "update", "add_item", "update_item", "add_profile", "remove_profile",
  "submit", "approve", "observe",
  "close", "reopen", "cancel_item", "advance_state", "delete", "list_items",
]);

const globalRoles = new Set(["leader", "general_admin"]);
const stateSequence = ["waiting", "taxi", "takeoff", "landing", "engine_off"];

const statusLabels: Record<string, string> = {
  draft: "Borrador",
  submitted: "Enviado",
  observed: "Observado",
  approved: "Aprobado",
  closed: "Cerrado",
  reopened: "Reabierto",
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
    return errorResponse(405, "VALIDATION_INVALID_INPUT", "Metodo no permitido.", "VALIDATION", "medium");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return errorResponse(500, "SYSTEM_UNEXPECTED", "Configuracion backend incompleta.", "SYSTEM", "critical");
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return errorResponse(401, "AUTH_SESSION_MISSING", "Sesion ausente o invalida.", "AUTH");
  }
  const userId = userData.user.id;

  const { data: actorProfile } = await adminClient
    .from("profiles")
    .select("role,unit_id,status")
    .eq("id", userId)
    .maybeSingle();

  if (!actorProfile) {
    return errorResponse(403, "AUTH_PROFILE_MISSING", "Perfil no encontrado.", "AUTHORIZATION");
  }
  if (actorProfile.status !== "active") {
    const reason = actorProfile.status === "pending" ? "Perfil pendiente de activacion." : "Perfil inactivo.";
    return errorResponse(403, "AUTH_PROFILE_INACTIVE", reason, "AUTHORIZATION");
  }

  async function checkPermission(key: string): Promise<boolean> {
    const { data } = await userClient.rpc("has_permission", { permission_key: key });
    return data === true;
  }

  async function auditLog(
    result: string,
    resourceType: string,
    resourceId: string | null,
    metadata: Record<string, unknown>,
  ) {
    try {
      await adminClient.from("audit_logs").insert({
        actor_id: userId,
        actor_role: actorProfile.role,
        actor_unit_id: actorProfile.unit_id,
        action: `flight_order.${action}`,
        resource_type: resourceType,
        resource_id: resourceId,
        result,
        metadata,
      });
    } catch {
      // audit log is non-blocking
    }
  }

  let rawPayload: Record<string, unknown>;
  try {
    rawPayload = await req.json();
  } catch {
    return errorResponse(400, "VALIDATION_INVALID_INPUT", "Cuerpo JSON invalido.", "VALIDATION");
  }

  const payload = rawPayload ?? {};
  const action = String(payload.action ?? "").trim();
  const flightOrderId = payload.flight_order_id ? String(payload.flight_order_id).trim() : null;

  if (!actions.has(action)) {
    return errorResponse(400, "VALIDATION_INVALID_ACTION", `Accion desconocida: ${action}`, "VALIDATION");
  }

  // ── Permission mapping ──
  const needsReview = new Set(["approve", "observe", "close", "reopen"]);
  const needsCreate = new Set(["create", "update", "add_item", "update_item", "add_profile", "remove_profile"]);
  const needsCancel = new Set(["cancel_item"]);
  const needsDelete = new Set(["delete"]);

  if (needsCreate.has(action)) {
    if (!(await checkPermission("flight_orders.create"))) {
      await auditLog("denied", "flight_order", null, { reason: "no_permission", required: "flight_orders.create" });
      return errorResponse(403, "AUTH_PERMISSION_DENIED", "Operacion no autorizada.", "AUTHORIZATION");
    }
  } else if (needsReview.has(action)) {
    if (!(await checkPermission("flight_orders.review"))) {
      await auditLog("denied", "flight_order", null, { reason: "no_permission", required: "flight_orders.review" });
      return errorResponse(403, "AUTH_PERMISSION_DENIED", "Operacion no autorizada.", "AUTHORIZATION");
    }
  } else if (needsCancel.has(action)) {
    const hasCancel = globalRoles.has(actorProfile.role) || (await checkPermission("flight_orders.close"));
    if (!hasCancel) {
      await auditLog("denied", "flight_order", null, { reason: "no_permission", required: "global_or_close" });
      return errorResponse(403, "AUTH_PERMISSION_DENIED", "Solo roles globales o Comando de Unidad pueden cancelar vuelos.", "AUTHORIZATION");
    }
  } else if (needsDelete.has(action)) {
    const hasDelete = globalRoles.has(actorProfile.role) || (await checkPermission("flight_orders.close"));
    if (!hasDelete) {
      await auditLog("denied", "flight_order", null, { reason: "no_permission", required: "global_or_close" });
      return errorResponse(403, "AUTH_PERMISSION_DENIED", "Solo roles globales o Comando de Unidad pueden borrar ordenes.", "AUTHORIZATION");
    }
  } else if (action === "advance_state" || action === "list_items") {
    if (!(await checkPermission("flight_orders.read"))) {
      return errorResponse(403, "AUTH_PERMISSION_DENIED", "Operacion no autorizada.", "AUTHORIZATION");
    }
  }

  // ── Helper: compute next order number for a unit ──
  async function nextOrderNumber(unitId: string): Promise<string> {
    const { data: unit } = await adminClient
      .from("units")
      .select("acronym, code")
      .eq("id", unitId)
      .maybeSingle();

    const acronym = (unit?.acronym || unit?.code || "XX").toUpperCase().slice(0, 10);

    const { data: last } = await adminClient
      .from("flight_orders")
      .select("order_number")
      .eq("unit_id", unitId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    let seq = 1;
    if (last?.order_number) {
      const parts = String(last.order_number).split("-");
      if (parts.length > 1) {
        seq = parseInt(parts[parts.length - 1], 10) || 0;
        seq += 1;
      }
    }
    return `${acronym}-${String(seq).padStart(3, "0")}`;
  }

  // ── Helper: create a flight order item with nested routes, crew, profiles ──
  async function createFlightOrderItem(
    flightOrderId: string,
    item: Record<string, unknown>,
  ) {
    const aircraftId = String(item.aircraft_id ?? "").trim();
    if (!aircraftId) return null;

    const mission = item.mission ? String(item.mission).trim() : null;
    const flightLevelMin = item.flight_level_min ? parseInt(String(item.flight_level_min), 10) || null : null;
    const flightLevelMax = item.flight_level_max ? parseInt(String(item.flight_level_max), 10) || null : null;
    const eteMinutes = item.ete_minutes ? parseInt(String(item.ete_minutes), 10) || null : null;
    const fuelType = item.fuel_type ? String(item.fuel_type).trim() : null;
    const fuelAmount = item.fuel_amount ? parseFloat(String(item.fuel_amount)) || null : null;
    const scheduledDeparture = item.scheduled_departure ? String(item.scheduled_departure).trim() : null;

    const { data: createdItem, error: itemError } = await adminClient
      .from("flight_order_items")
      .insert({
        flight_order_id: flightOrderId,
        aircraft_id: aircraftId,
        mission,
        flight_level_min: flightLevelMin,
        flight_level_max: flightLevelMax,
        ete_minutes: eteMinutes,
        fuel_type: fuelType,
        fuel_amount: fuelAmount,
        scheduled_departure: scheduledDeparture,
        status: "waiting",
      })
      .select("id")
      .single();

    if (itemError || !createdItem) return null;
    const itemId = createdItem.id;

    // Routes
    const routes = Array.isArray(item.routes) ? (item.routes as Record<string, unknown>[]) : [];
    for (const route of routes) {
      await adminClient.from("flight_order_routes").insert({
        flight_order_item_id: itemId,
        segment_order: parseInt(String(route.segment_order ?? 1), 10) || 1,
        segment_type: String(route.segment_type ?? "outbound"),
        origin_type: String(route.origin_type ?? "airport"),
        origin_route_id: route.origin_route_id ? String(route.origin_route_id) : null,
        origin_label: route.origin_label ? String(route.origin_label) : null,
        origin_lat: route.origin_lat ? parseFloat(String(route.origin_lat)) || null : null,
        origin_lng: route.origin_lng ? parseFloat(String(route.origin_lng)) || null : null,
        destination_type: String(route.destination_type ?? "airport"),
        destination_route_id: route.destination_route_id ? String(route.destination_route_id) : null,
        destination_label: route.destination_label ? String(route.destination_label) : null,
        destination_lat: route.destination_lat ? parseFloat(String(route.destination_lat)) || null : null,
        destination_lng: route.destination_lng ? parseFloat(String(route.destination_lng)) || null : null,
      });
    }

    // Crew
    const crewList = Array.isArray(item.crew) ? (item.crew as Record<string, unknown>[]) : [];
    for (const c of crewList) {
      const cmId = String(c.crew_member_id ?? "").trim();
      const roleCode = String(c.role_code ?? "PC").trim();
      const functionCode = c.function_code ? String(c.function_code).trim() : null;
      if (!cmId) continue;
      await adminClient.from("flight_order_crew").insert({
        flight_order_item_id: itemId,
        crew_member_id: cmId,
        role_code: roleCode,
        function_code: functionCode,
      });
    }

    // Profiles (junction table)
    const profileIds = Array.isArray(item.profile_ids) ? (item.profile_ids as string[]) : [];
    for (const profileId of profileIds) {
      await adminClient.from("flight_order_item_profiles").insert({
        flight_order_item_id: itemId,
        profile_id: profileId,
      });
    }

    // Re-fetch full item with all joins
    const { data: fullItem, error: fetchError } = await adminClient
      .from("flight_order_items")
      .select("*, aircraft:aircraft_id(tail_number, model), routes:flight_order_routes(*, origin_route:origin_route_id(airport_name), destination_route:destination_route_id(airport_name)), crew:flight_order_crew(*, crew_member:crew_member_id(grade,first_name,last_name,callsign)), profiles:flight_order_item_profiles(profile:profile_id(*))")
      .eq("id", itemId)
      .single();

    if (fullItem && !fetchError) return fullItem;

    // Re-fetch failed — return basic object so frontend doesn't get a false error
    console.error("Re-fetch of flight_order_item failed, returning fallback:", fetchError);
    const { data: aircraft } = await adminClient
      .from("aircraft")
      .select("tail_number, model")
      .eq("id", aircraftId)
      .maybeSingle();

    return {
      id: itemId,
      flight_order_id: flightOrderId,
      aircraft_id: aircraftId,
      mission,
      flight_level_min: flightLevelMin,
      flight_level_max: flightLevelMax,
      ete_minutes: eteMinutes,
      fuel_type: fuelType,
      fuel_amount: fuelAmount,
      scheduled_departure: scheduledDeparture,
      status: "waiting",
      cancelled: false,
      aircraft: aircraft ?? null,
      routes: [],
      crew: [],
      profiles: [],
    };
  }

  // ── ACTION: create ──
  if (action === "create") {
    const unitId = String(payload.unit_id ?? "").trim();
    const operationDate = String(payload.operation_date ?? "").trim();

    if (!unitId) return errorResponse(400, "VALIDATION_REQUIRED", "Unidad requerida.", "VALIDATION");
    if (!operationDate) return errorResponse(400, "VALIDATION_REQUIRED", "Fecha de operacion requerida.", "VALIDATION");

    // Unit scope check for non-global roles
    if (!globalRoles.has(actorProfile.role)) {
      if (actorProfile.unit_id !== unitId) {
        return errorResponse(403, "AUTH_UNIT_MISMATCH", "Solo puedes crear ordenes para tu unidad.", "AUTHORIZATION");
      }
    }

    // Check unique constraint
    const { data: existing } = await adminClient
      .from("flight_orders")
      .select("id")
      .eq("unit_id", unitId)
      .eq("operation_date", operationDate)
      .maybeSingle();

    if (existing) {
      return errorResponse(409, "BUSINESS_DUPLICATE_ORDER", "Ya existe una Orden de Vuelo para esta unidad y fecha.", "BUSINESS_RULE");
    }

    const orderNumber = await nextOrderNumber(unitId);

    const { data: order, error: insertError } = await adminClient
      .from("flight_orders")
      .insert({
        unit_id: unitId,
        operation_date: operationDate,
        order_number: orderNumber,
        status: "draft",
        created_by: userId,
      })
      .select("*, units(name)")
      .single();

    if (insertError || !order) {
      const reason = insertError?.code === "23505" ? "conflict" : "save_failed";
      await auditLog("failed", "flight_order", null, { reason, error_code: insertError?.code });
      if (insertError?.code === "23505") {
        return errorResponse(409, "BUSINESS_DUPLICATE_ORDER", "Ya existe una Orden de Vuelo para esta unidad y fecha.", "BUSINESS_RULE");
      }
      return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudo crear la orden.", "SYSTEM");
    }

    // Create items if provided
    const items = Array.isArray(payload.items) ? (payload.items as Record<string, unknown>[]) : [];
    for (const item of items) {
      await createFlightOrderItem(order.id, item);
    }

    await auditLog("success", "flight_order", order.id, {
      order_number: orderNumber,
      operation_date: operationDate,
    });

    return jsonResponse({ ok: true, data: order, meta: {} });
  }

  // ── ACTION: add_item ──
  if (action === "add_item") {
    if (!flightOrderId) {
      return errorResponse(400, "VALIDATION_REQUIRED", "flight_order_id requerido.", "VALIDATION");
    }

    const { data: order, error: orderError } = await adminClient
      .from("flight_orders")
      .select("id,unit_id,status")
      .eq("id", flightOrderId)
      .maybeSingle();

    if (orderError || !order) {
      return errorResponse(404, "DATA_NOT_FOUND", "Orden de Vuelo no encontrada.", "DATA");
    }

    if (order.status !== "draft") {
      return errorResponse(400, "BUSINESS_ORDER_NOT_DRAFT", "Solo se pueden agregar vuelos a ordenes en borrador.", "BUSINESS_RULE");
    }

    // Unit scope check
    if (!globalRoles.has(actorProfile.role)) {
      if (actorProfile.unit_id !== order.unit_id) {
        return errorResponse(403, "AUTH_UNIT_MISMATCH", "No puedes agregar vuelos a ordenes de otra unidad.", "AUTHORIZATION");
      }
    }

    const itemPayload = (payload.item as Record<string, unknown>) ?? {};
    const fullItem = await createFlightOrderItem(flightOrderId, itemPayload);

    if (!fullItem) {
      return errorResponse(400, "VALIDATION_INVALID_INPUT", "Debe seleccionar una aeronave.", "VALIDATION", "medium");
    }

    await auditLog("success", "flight_order_item", fullItem.id, {
      flight_order_id: flightOrderId,
    });

    return jsonResponse({ ok: true, data: fullItem, meta: {} });
  }

  // ── ACTION: submit / approve / observe / close / reopen ──
  if (action === "submit" || action === "approve" || action === "observe" || action === "close" || action === "reopen") {
    if (!flightOrderId) {
      return errorResponse(400, "VALIDATION_REQUIRED", "flight_order_id requerido.", "VALIDATION");
    }

    const { data: order, error: orderError } = await adminClient
      .from("flight_orders")
      .select("*")
      .eq("id", flightOrderId)
      .maybeSingle();

    if (orderError || !order) {
      return errorResponse(404, "DATA_NOT_FOUND", "Orden de Vuelo no encontrada.", "DATA");
    }

    const validTransitions: Record<string, string[]> = {
      draft: ["submit"],
      submitted: ["approve", "observe"],
      approved: ["close"],
      closed: ["reopen"],
      reopened: ["close"],
    };

    const allowed = validTransitions[order.status] ?? [];
    if (!allowed.includes(action)) {
      return errorResponse(400, "BUSINESS_INVALID_TRANSITION",
        `No se puede pasar de ${statusLabels[order.status] ?? order.status} a ${statusLabels[action] ?? action}.`,
        "BUSINESS_RULE");
    }

    // Scope check
    if (!globalRoles.has(actorProfile.role)) {
      if (actorProfile.unit_id !== order.unit_id) {
        return errorResponse(403, "AUTH_UNIT_MISMATCH", "No puedes gestionar ordenes de otra unidad.", "AUTHORIZATION");
      }
    }

    const update: Record<string, unknown> = {};
    if (action === "submit") {
      update.status = "submitted";
      update.submitted_at = new Date().toISOString();
    } else if (action === "approve") {
      update.status = "approved";
      update.approved_at = new Date().toISOString();
      update.approved_by = userId;
    } else if (action === "observe") {
      update.status = "draft";
    } else if (action === "close") {
      update.status = "closed";
      update.closed_at = new Date().toISOString();
      update.closed_by = userId;
    } else if (action === "reopen") {
      update.status = "reopened";
    }

    const { error: updateError } = await adminClient
      .from("flight_orders")
      .update(update)
      .eq("id", flightOrderId);

    if (updateError) {
      await auditLog("failed", "flight_order", flightOrderId, { reason: "update_failed", error_code: updateError.code });
      return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudo actualizar la orden.", "SYSTEM");
    }

    await auditLog("success", "flight_order", flightOrderId, { from_status: order.status, to_status: update.status });

    const { data: updatedOrder } = await adminClient
      .from("flight_orders")
      .select("*, units(name)")
      .eq("id", flightOrderId)
      .single();

    return jsonResponse({ ok: true, data: updatedOrder, meta: {} });
  }

  // ── ACTION: delete ──
  if (action === "delete") {
    if (!flightOrderId) {
      return errorResponse(400, "VALIDATION_REQUIRED", "flight_order_id requerido.", "VALIDATION");
    }

    const { data: order, error: orderError } = await adminClient
      .from("flight_orders")
      .select("id,unit_id,status,order_number")
      .eq("id", flightOrderId)
      .maybeSingle();

    if (orderError || !order) {
      return errorResponse(404, "DATA_NOT_FOUND", "Orden de Vuelo no encontrada.", "DATA");
    }

    if (order.status !== "draft") {
      return errorResponse(400, "BUSINESS_ORDER_NOT_DRAFT", "Solo se pueden borrar ordenes en borrador.", "BUSINESS_RULE");
    }

    if (!globalRoles.has(actorProfile.role)) {
      if (actorProfile.unit_id !== order.unit_id) {
        return errorResponse(403, "AUTH_UNIT_MISMATCH", "No puedes borrar ordenes de otra unidad.", "AUTHORIZATION");
      }
    }

    const { error: deleteError } = await adminClient
      .from("flight_orders")
      .delete()
      .eq("id", flightOrderId);

    if (deleteError) {
      await auditLog("failed", "flight_order", flightOrderId, { reason: "delete_failed", error_code: deleteError.code });
      return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudo borrar la orden.", "SYSTEM");
    }

    await auditLog("success", "flight_order", flightOrderId, { order_number: order.order_number });

    return jsonResponse({ ok: true, data: null, meta: {} });
  }

  // ── ACTION: update_item ──
  if (action === "update_item") {
    if (!flightOrderId) {
      return errorResponse(400, "VALIDATION_REQUIRED", "flight_order_id requerido.", "VALIDATION");
    }
    const itemId = String(payload.item_id ?? "").trim();
    if (!itemId) {
      return errorResponse(400, "VALIDATION_REQUIRED", "item_id requerido.", "VALIDATION");
    }

    const { data: order, error: orderError } = await adminClient
      .from("flight_orders")
      .select("id,unit_id,status")
      .eq("id", flightOrderId)
      .maybeSingle();

    if (orderError || !order) {
      return errorResponse(404, "DATA_NOT_FOUND", "Orden de Vuelo no encontrada.", "DATA");
    }

    if (order.status !== "draft") {
      return errorResponse(400, "BUSINESS_ORDER_NOT_EDITABLE", "Solo se pueden editar vuelos en ordenes en borrador.", "BUSINESS_RULE");
    }

    if (!globalRoles.has(actorProfile.role)) {
      if (actorProfile.unit_id !== order.unit_id) {
        return errorResponse(403, "AUTH_UNIT_MISMATCH", "No puedes editar vuelos de otra unidad.", "AUTHORIZATION");
      }
    }

    // Verify item belongs to this order
    const { data: existingItem, error: itemCheckError } = await adminClient
      .from("flight_order_items")
      .select("id")
      .eq("id", itemId)
      .eq("flight_order_id", flightOrderId)
      .maybeSingle();

    if (itemCheckError || !existingItem) {
      return errorResponse(404, "DATA_NOT_FOUND", "Vuelo no encontrado en esta orden.", "DATA");
    }

    const itemPayload = (payload.item as Record<string, unknown>) ?? {};
    const aircraftId = String(itemPayload.aircraft_id ?? "").trim();
    if (!aircraftId) {
      return errorResponse(400, "VALIDATION_INVALID_INPUT", "Debe seleccionar una aeronave.", "VALIDATION", "medium");
    }

    // Delete existing routes, crew, and profiles for this item
    await adminClient.from("flight_order_routes").delete().eq("flight_order_item_id", itemId);
    await adminClient.from("flight_order_crew").delete().eq("flight_order_item_id", itemId);
    await adminClient.from("flight_order_item_profiles").delete().eq("flight_order_item_id", itemId);

    // Update the item record
    const mission = itemPayload.mission ? String(itemPayload.mission).trim() : null;
    const flightLevelMin = itemPayload.flight_level_min ? parseInt(String(itemPayload.flight_level_min), 10) || null : null;
    const flightLevelMax = itemPayload.flight_level_max ? parseInt(String(itemPayload.flight_level_max), 10) || null : null;
    const eteMinutes = itemPayload.ete_minutes ? parseInt(String(itemPayload.ete_minutes), 10) || null : null;
    const fuelType = itemPayload.fuel_type ? String(itemPayload.fuel_type).trim() : null;
    const fuelAmount = itemPayload.fuel_amount ? parseFloat(String(itemPayload.fuel_amount)) || null : null;
    const scheduledDeparture = itemPayload.scheduled_departure ? String(itemPayload.scheduled_departure).trim() : null;

    const { error: updateError } = await adminClient
      .from("flight_order_items")
      .update({
        aircraft_id: aircraftId,
        mission,
        flight_level_min: flightLevelMin,
        flight_level_max: flightLevelMax,
        ete_minutes: eteMinutes,
        fuel_type: fuelType,
        fuel_amount: fuelAmount,
        scheduled_departure: scheduledDeparture,
      })
      .eq("id", itemId);

    if (updateError) {
      await auditLog("failed", "flight_order_item", itemId, { reason: "update_failed", error_code: updateError.code });
      return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudo actualizar el vuelo.", "SYSTEM");
    }

    // Recreate routes
    const routes = Array.isArray(itemPayload.routes) ? (itemPayload.routes as Record<string, unknown>[]) : [];
    for (const route of routes) {
      await adminClient.from("flight_order_routes").insert({
        flight_order_item_id: itemId,
        segment_order: parseInt(String(route.segment_order ?? 1), 10) || 1,
        segment_type: String(route.segment_type ?? "outbound"),
        origin_type: String(route.origin_type ?? "airport"),
        origin_route_id: route.origin_route_id ? String(route.origin_route_id) : null,
        origin_label: route.origin_label ? String(route.origin_label) : null,
        origin_lat: route.origin_lat ? parseFloat(String(route.origin_lat)) : null,
        origin_lng: route.origin_lng ? parseFloat(String(route.origin_lng)) : null,
        destination_type: String(route.destination_type ?? "airport"),
        destination_route_id: route.destination_route_id ? String(route.destination_route_id) : null,
        destination_label: route.destination_label ? String(route.destination_label) : null,
        destination_lat: route.destination_lat ? parseFloat(String(route.destination_lat)) : null,
        destination_lng: route.destination_lng ? parseFloat(String(route.destination_lng)) : null,
      });
    }

    // Recreate crew
    const crewList = Array.isArray(itemPayload.crew) ? (itemPayload.crew as Record<string, unknown>[]) : [];
    for (const member of crewList) {
      await adminClient.from("flight_order_crew").insert({
        flight_order_item_id: itemId,
        crew_member_id: String(member.crew_member_id ?? ""),
        role_code: String(member.role_code ?? ""),
        function_code: member.function_code ? String(member.function_code) : null,
      });
    }

    // Recreate profile links
    const profileIds = Array.isArray(itemPayload.profile_ids) ? (itemPayload.profile_ids as string[]) : [];
    for (const profileId of profileIds) {
      await adminClient.from("flight_order_item_profiles").insert({
        flight_order_item_id: itemId,
        profile_id: profileId,
      });
    }

    // Re-fetch full item with all joins
    const { data: updatedItem } = await adminClient
      .from("flight_order_items")
      .select("*, aircraft:aircraft_id(tail_number, model), routes:flight_order_routes(*, origin_route:origin_route_id(airport_name), destination_route:destination_route_id(airport_name)), crew:flight_order_crew(*, crew_member:crew_member_id(grade,first_name,last_name,callsign)), profiles:flight_order_item_profiles(profile:profile_id(*))")
      .eq("id", itemId)
      .single();

    await auditLog("success", "flight_order_item", itemId, { action: "update_item" });

    return jsonResponse({ ok: true, data: updatedItem, meta: {} });
  }

  // ── ACTION: cancel_item ──
  if (action === "cancel_item") {
    const itemId = String(payload.item_id ?? "").trim();
    const cancelReason = String(payload.cancel_reason ?? "").trim();

    if (!itemId) return errorResponse(400, "VALIDATION_REQUIRED", "item_id requerido.", "VALIDATION");
    if (!cancelReason) return errorResponse(400, "VALIDATION_REQUIRED", "Motivo de cancelacion requerido.", "VALIDATION");

    const { data: item, error: itemError } = await adminClient
      .from("flight_order_items")
      .select("id,status,flight_order_id")
      .eq("id", itemId)
      .maybeSingle();

    if (itemError || !item) {
      return errorResponse(404, "DATA_NOT_FOUND", "Item no encontrado.", "DATA");
    }

    if (item.status === "cancelled") {
      return errorResponse(400, "BUSINESS_ALREADY_CANCELLED", "El vuelo ya esta cancelado.", "BUSINESS_RULE");
    }

    const { error: cancelError } = await adminClient
      .from("flight_order_items")
      .update({
        status: "cancelled",
        cancelled: true,
        cancelled_at: new Date().toISOString(),
        cancelled_by: userId,
        cancel_reason: cancelReason,
      })
      .eq("id", itemId);

    if (cancelError) {
      await auditLog("failed", "flight_order_item", itemId, { reason: "cancel_failed", error_code: cancelError.code });
      return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudo cancelar el vuelo.", "SYSTEM");
    }

    await auditLog("success", "flight_order_item", itemId, { cancel_reason: cancelReason });
    return jsonResponse({ ok: true, data: null, meta: {} });
  }

  // ── ACTION: advance_state ──
  if (action === "advance_state") {
    const itemId = String(payload.item_id ?? "").trim();
    const nextStatus = String(payload.next_status ?? "").trim();

    if (!itemId) return errorResponse(400, "VALIDATION_REQUIRED", "item_id requerido.", "VALIDATION");
    if (!nextStatus) return errorResponse(400, "VALIDATION_REQUIRED", "next_status requerido.", "VALIDATION");

    const { data: item, error: itemError } = await adminClient
      .from("flight_order_items")
      .select("id,status,flight_order_id")
      .eq("id", itemId)
      .maybeSingle();

    if (itemError || !item) {
      return errorResponse(404, "DATA_NOT_FOUND", "Item no encontrado.", "DATA");
    }

    if (item.status === "cancelled") {
      return errorResponse(400, "BUSINESS_CANCELLED", "No se puede avanzar un vuelo cancelado.", "BUSINESS_RULE");
    }

    // Validate state sequence
    const currentIdx = stateSequence.indexOf(item.status);
    const nextIdx = stateSequence.indexOf(nextStatus);
    if (nextIdx < 0 || nextIdx !== currentIdx + 1) {
      return errorResponse(400, "BUSINESS_INVALID_STATE_SEQUENCE",
        `Secuencia invalida: ${item.status} -> ${nextStatus}.`,
        "BUSINESS_RULE");
    }

    // Check unit scope
    const { data: fo } = await adminClient
      .from("flight_orders")
      .select("unit_id")
      .eq("id", item.flight_order_id)
      .maybeSingle();

    if (fo && !globalRoles.has(actorProfile.role)) {
      if (actorProfile.unit_id !== fo.unit_id) {
        return errorResponse(403, "AUTH_UNIT_MISMATCH", "No puedes gestionar vuelos de otra unidad.", "AUTHORIZATION");
      }
    }

    const occurredAt = new Date().toISOString();

    // Insert state event
    const { error: eventError } = await adminClient
      .from("flight_order_state_events")
      .insert({
        flight_order_item_id: itemId,
        status: nextStatus,
        occurred_at: occurredAt,
        recorded_by: userId,
      });

    if (eventError) {
      // If duplicate (same status already recorded), ignore
      if (eventError.code !== "23505") {
        return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudo registrar el evento.", "SYSTEM");
      }
    }

    // Update item status
    const { error: updateError } = await adminClient
      .from("flight_order_items")
      .update({ status: nextStatus })
      .eq("id", itemId);

    if (updateError) {
      return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudo actualizar el estado.", "SYSTEM");
    }

    return jsonResponse({
      ok: true,
      data: { item_id: itemId, status: nextStatus, occurred_at: occurredAt },
      meta: {},
    });
  }

  // ── ACTION: add_profile ──
  if (action === "add_profile") {
    if (!flightOrderId) {
      return errorResponse(400, "VALIDATION_REQUIRED", "flight_order_id requerido.", "VALIDATION");
    }

    const description = String(payload.description ?? "").trim();
    if (!description) {
      return errorResponse(400, "VALIDATION_REQUIRED", "Descripcion del perfil requerida.", "VALIDATION");
    }

    const { data: order, error: orderError } = await adminClient
      .from("flight_orders")
      .select("id,unit_id,status")
      .eq("id", flightOrderId)
      .maybeSingle();

    if (orderError || !order) {
      return errorResponse(404, "DATA_NOT_FOUND", "Orden de Vuelo no encontrada.", "DATA");
    }

    if (order.status !== "draft") {
      return errorResponse(400, "BUSINESS_ORDER_NOT_DRAFT", "Solo se pueden agregar perfiles a ordenes en borrador.", "BUSINESS_RULE");
    }

    if (!globalRoles.has(actorProfile.role)) {
      if (actorProfile.unit_id !== order.unit_id) {
        return errorResponse(403, "AUTH_UNIT_MISMATCH", "No puedes agregar perfiles a ordenes de otra unidad.", "AUTHORIZATION");
      }
    }

    // Auto-number: find max profile_number for this order
    const { data: lastProfile } = await adminClient
      .from("flight_order_profiles")
      .select("profile_number")
      .eq("flight_order_id", flightOrderId)
      .order("profile_number", { ascending: false })
      .limit(1)
      .maybeSingle();

    const nextNumber = (lastProfile?.profile_number ?? 0) + 1;

    const { data: profile, error: insertError } = await adminClient
      .from("flight_order_profiles")
      .insert({
        flight_order_id: flightOrderId,
        profile_number: nextNumber,
        description,
      })
      .select("*")
      .single();

    if (insertError || !profile) {
      return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudo crear el perfil.", "SYSTEM");
    }

    await auditLog("success", "flight_order_profile", profile.id, { flight_order_id: flightOrderId });

    return jsonResponse({ ok: true, data: profile, meta: {} });
  }

  // ── ACTION: remove_profile ──
  if (action === "remove_profile") {
    const profileId = String(payload.profile_id ?? "").trim();
    if (!profileId) {
      return errorResponse(400, "VALIDATION_REQUIRED", "profile_id requerido.", "VALIDATION");
    }

    const { data: profile, error: profileError } = await adminClient
      .from("flight_order_profiles")
      .select("id,flight_order_id")
      .eq("id", profileId)
      .maybeSingle();

    if (profileError || !profile) {
      return errorResponse(404, "DATA_NOT_FOUND", "Perfil no encontrado.", "DATA");
    }

    // Verify order is draft
    const { data: order } = await adminClient
      .from("flight_orders")
      .select("id,unit_id,status")
      .eq("id", profile.flight_order_id)
      .maybeSingle();

    if (!order) {
      return errorResponse(404, "DATA_NOT_FOUND", "Orden de Vuelo no encontrada.", "DATA");
    }

    if (order.status !== "draft") {
      return errorResponse(400, "BUSINESS_ORDER_NOT_DRAFT", "Solo se pueden eliminar perfiles de ordenes en borrador.", "BUSINESS_RULE");
    }

    if (!globalRoles.has(actorProfile.role)) {
      if (actorProfile.unit_id !== order.unit_id) {
        return errorResponse(403, "AUTH_UNIT_MISMATCH", "No puedes eliminar perfiles de otra unidad.", "AUTHORIZATION");
      }
    }

    // Junction table rows are cascade-deleted, but delete profiles explicitly
    const { error: deleteError } = await adminClient
      .from("flight_order_profiles")
      .delete()
      .eq("id", profileId);

    if (deleteError) {
      return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudo eliminar el perfil.", "SYSTEM");
    }

    await auditLog("success", "flight_order_profile", profileId, { flight_order_id: profile.flight_order_id });

    return jsonResponse({ ok: true, data: null, meta: {} });
  }

  // ── ACTION: list_items ──
  if (action === "list_items") {
    if (!flightOrderId) {
      return errorResponse(400, "VALIDATION_REQUIRED", "flight_order_id requerido.", "VALIDATION");
    }

    const { data: rows, error: queryError } = await adminClient
      .from("flight_order_items")
      .select("*, aircraft:aircraft_id(tail_number, model), routes:flight_order_routes(*, origin_route:origin_route_id(airport_name), destination_route:destination_route_id(airport_name)), crew:flight_order_crew(*, crew_member:crew_member_id(grade,first_name,last_name,callsign)), profiles:flight_order_item_profiles(profile:profile_id(*)), state_events:flight_order_state_events(*)")
      .eq("flight_order_id", flightOrderId)
      .order("created_at");

    if (queryError) {
      return errorResponse(500, "SYSTEM_UNEXPECTED", "No se pudieron cargar los items.", "SYSTEM");
    }

    return jsonResponse({ ok: true, data: rows, meta: {} });
  }

  return errorResponse(400, "VALIDATION_INVALID_ACTION", `Accion no implementada: ${action}`, "VALIDATION");
});
