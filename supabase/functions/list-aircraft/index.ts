import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const globalRoles = new Set(["leader", "general_admin"]);

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

function uniqueStrings(values: unknown[]) {
  return [...new Set(values.map((v) => String(v)).filter((v) => v.length > 0))];
}

function startOfUtcDay(date: Date) {
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function daysWithoutFlyingSince(value: string) {
  const last = new Date(value);
  if (Number.isNaN(last.getTime())) return null;
  const todayStart = startOfUtcDay(new Date());
  const lastStart = startOfUtcDay(last);
  return Math.max(0, Math.floor((todayStart - lastStart) / 86_400_000));
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
      actorProfile.status === "pending"
        ? "AUTH_PROFILE_PENDING"
        : "AUTH_USER_INACTIVE",
      "Usuario no habilitado para operar.",
      "AUTH",
    );
  }

  const { data: hasPermission, error: permissionError } = await userClient.rpc(
    "has_permission",
    { permission_key: "aircraft.read" },
  );
  if (permissionError || hasPermission !== true) {
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const isGlobal = globalRoles.has(actorProfile.role);
  if (!isGlobal && !actorProfile.unit_id) {
    return errorResponse(
      403,
      "AUTHORIZATION_UNIT_REQUIRED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  let query = adminClient
    .from("aircraft")
    .select(
      "id,unit_id,tail_number,ob_tail_number,display_registration,model,manufacturer,serial_number,year,status,active,inoperative_reason,squadron_id",
    )
    .eq("active", true);

  if (!isGlobal) {
    query = query.eq("unit_id", actorProfile.unit_id);
  }

  const { data: aircraft, error } = await query.order("tail_number");
  if (error) {
    return errorResponse(
      500,
      "SYSTEM_UNEXPECTED",
      "No se pudo cargar aeronaves.",
      "SYSTEM",
    );
  }

  const aircraftIds = (aircraft ?? []).map((row) => row.id);
  const squadronIds = uniqueStrings(
    (aircraft ?? []).map((row) => row.squadron_id).filter(Boolean),
  );
  const junctionMap = new Map<string, string[]>();

  if (aircraftIds.length > 0) {
    const { data: junctionRows, error: junctionError } = await adminClient
      .from("aircraft_squadrons")
      .select("aircraft_id,squadron_id")
      .in("aircraft_id", aircraftIds);

    if (junctionError) {
      return errorResponse(
        500,
        "SYSTEM_UNEXPECTED",
        "No se pudo cargar escuadrones de aeronaves.",
        "SYSTEM",
      );
    }

    for (const row of junctionRows ?? []) {
      const aircraftId = String(row.aircraft_id ?? "");
      const squadronId = String(row.squadron_id ?? "");
      if (!aircraftId || !squadronId) continue;
      squadronIds.push(squadronId);
      const current = junctionMap.get(aircraftId) ?? [];
      current.push(squadronId);
      junctionMap.set(aircraftId, current);
    }
  }

  const lastFlightMap = new Map<
    string,
    { last_flight_at: string; last_flight_order_number: string | null }
  >();

  if (aircraftIds.length > 0) {
    const { data: flightItems, error: flightItemsError } = await adminClient
      .from("flight_order_items")
      .select("id,aircraft_id,flight_order_id,status,cancelled")
      .in("aircraft_id", aircraftIds)
      .eq("status", "engine_off")
      .eq("cancelled", false);

    if (flightItemsError) {
      return errorResponse(
        500,
        "SYSTEM_UNEXPECTED",
        "No se pudo cargar actividad de vuelo de aeronaves.",
        "SYSTEM",
      );
    }

    const itemIds = uniqueStrings((flightItems ?? []).map((row) => row.id));
    const orderIds = uniqueStrings(
      (flightItems ?? []).map((row) => row.flight_order_id),
    );
    const engineOffMap = new Map<string, string>();
    const orderMap = new Map<
      string,
      { operation_date: string | null; order_number: string | null }
    >();

    if (itemIds.length > 0) {
      const { data: eventRows, error: eventError } = await adminClient
        .from("flight_order_state_events")
        .select("flight_order_item_id,occurred_at")
        .in("flight_order_item_id", itemIds)
        .eq("status", "engine_off");

      if (eventError) {
        return errorResponse(
          500,
          "SYSTEM_UNEXPECTED",
          "No se pudo cargar eventos de vuelo de aeronaves.",
          "SYSTEM",
        );
      }

      for (const row of eventRows ?? []) {
        const itemId = String(row.flight_order_item_id ?? "");
        const occurredAt = String(row.occurred_at ?? "");
        if (!itemId || !occurredAt) continue;
        const current = engineOffMap.get(itemId);
        if (!current || new Date(occurredAt) > new Date(current)) {
          engineOffMap.set(itemId, occurredAt);
        }
      }
    }

    if (orderIds.length > 0) {
      const { data: orderRows, error: orderError } = await adminClient
        .from("flight_orders")
        .select("id,order_number,operation_date,deleted_at")
        .in("id", orderIds);

      if (orderError) {
        return errorResponse(
          500,
          "SYSTEM_UNEXPECTED",
          "No se pudo cargar ordenes de vuelo de aeronaves.",
          "SYSTEM",
        );
      }

      for (const row of orderRows ?? []) {
        if (row.deleted_at) continue;
        const orderId = String(row.id ?? "");
        if (!orderId) continue;
        orderMap.set(orderId, {
          operation_date: row.operation_date ? String(row.operation_date) : null,
          order_number: row.order_number ? String(row.order_number) : null,
        });
      }
    }

    for (const item of flightItems ?? []) {
      const aircraftId = String(item.aircraft_id ?? "");
      const itemId = String(item.id ?? "");
      const orderId = String(item.flight_order_id ?? "");
      const order = orderMap.get(orderId);
      if (!aircraftId || !itemId || !order) continue;

      const eventAt = engineOffMap.get(itemId);
      const fallbackAt = order.operation_date
        ? `${order.operation_date}T00:00:00.000Z`
        : null;
      const lastFlightAt = eventAt ?? fallbackAt;
      if (!lastFlightAt) continue;

      const current = lastFlightMap.get(aircraftId);
      if (
        !current ||
        new Date(lastFlightAt) > new Date(current.last_flight_at)
      ) {
        lastFlightMap.set(aircraftId, {
          last_flight_at: lastFlightAt,
          last_flight_order_number: order.order_number,
        });
      }
    }
  }

  const squadronNameMap = new Map<string, string>();
  const uniqueSquadronIds = uniqueStrings(squadronIds);
  if (uniqueSquadronIds.length > 0) {
    const { data: squadronRows } = await adminClient
      .from("flight_squadrons")
      .select("id,name")
      .in("id", uniqueSquadronIds);

    for (const row of squadronRows ?? []) {
      squadronNameMap.set(String(row.id), String(row.name ?? ""));
    }
  }

  const data = (aircraft ?? []).map((row) => {
    const legacyIds = row.squadron_id ? [row.squadron_id] : [];
    const junctionIds = junctionMap.get(String(row.id)) ?? [];
    const lastFlight = lastFlightMap.get(String(row.id));
    const legacyName = row.squadron_id
      ? squadronNameMap.get(String(row.squadron_id))
      : null;
    return {
      ...row,
      squadron_ids: uniqueStrings([...legacyIds, ...junctionIds]),
      flight_squadrons: legacyName ? { name: legacyName } : null,
      last_flight_at: lastFlight?.last_flight_at ?? null,
      last_flight_order_number: lastFlight?.last_flight_order_number ?? null,
      days_without_flying: lastFlight
        ? daysWithoutFlyingSince(lastFlight.last_flight_at)
        : null,
    };
  });

  return jsonResponse({ ok: true, data, meta: { count: data.length } });
});
