import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const sections = [
  { key: "aircraft", table: "aircraft", identifierCols: ["tail_number", "model"], secondaryCols: ["unit_id"], deletedAtCol: "deleted_at", useActive: true },
  { key: "crew_members", table: "crew_members", identifierCols: ["full_name", "document_id"], secondaryCols: ["unit_id"], deletedAtCol: "deleted_at", useActive: true },
  { key: "routes", table: "routes", identifierCols: ["name"], secondaryCols: ["unit_id"], deletedAtCol: "deleted_at", useActive: true },
  { key: "units", table: "units", identifierCols: ["name", "code"], secondaryCols: [], deletedAtCol: "deleted_at", useActive: true },
  { key: "users", table: "profiles", identifierCols: ["display_name", "email"], secondaryCols: ["unit_id"], deletedAtCol: null, useActive: false, customFilter: "inactive" },
  { key: "flight_orders", table: "flight_orders", identifierCols: ["order_number"], secondaryCols: ["unit_id", "operation_date"], deletedAtCol: "deleted_at", useActive: false },
  { key: "flights", table: "flights", identifierCols: ["aircraft_id"], secondaryCols: ["unit_id", "flight_order_id"], deletedAtCol: "deleted_at", useActive: false },
  { key: "calendar_events", table: "calendar_events", identifierCols: ["title"], secondaryCols: ["event_date"], deletedAtCol: "deleted_at", useActive: false },
  { key: "messages", table: "messages", identifierCols: ["subject"], secondaryCols: ["sender_id"], deletedAtCol: "deleted_at", useActive: false },
  { key: "flight_order_profiles", table: "flight_order_profiles", identifierCols: ["description"], secondaryCols: ["flight_order_id"], deletedAtCol: "deleted_at", useActive: false },
];

const globalRoles = new Set(["leader", "general_admin"]);

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorResponse(status: number, code: string, message: string) {
  return jsonResponse({ ok: false, error: { code, message } }, status);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return errorResponse(500, "SYSTEM_UNEXPECTED", "Configuracion backend incompleta.");
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: req.headers.get("Authorization")! } },
  });

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  // Auth check
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return errorResponse(401, "AUTH_REQUIRED", "Autenticacion requerida.");
  }

  // Role check: only leader / general_admin
  const { data: profile } = await serviceClient
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (!profile || !globalRoles.has(profile.role)) {
    return errorResponse(403, "ACCESS_DENIED", "Acceso denegado.");
  }

  const body = await req.json().catch(() => ({}));
  const filterSection = body.section ?? null;

  try {
    const allItems: Record<string, unknown>[] = [];

    for (const sec of sections) {
      if (filterSection && sec.key !== filterSection) continue;

      let query = serviceClient.from(sec.table).select("*");

      if (sec.customFilter) {
        // users: status = 'inactive'
        query = query.eq("status", "inactive");
      } else if (sec.deletedAtCol) {
        query = query.not(sec.deletedAtCol, "is", null);
      }

      const orderCol = sec.deletedAtCol ?? "updated_at";
      query = query.order(orderCol, { ascending: false }).limit(200);

      const { data: rows, error: qError } = await query;
      if (qError) continue;

      for (const row of rows ?? []) {
        const idParts: string[] = [];
        for (const col of sec.identifierCols) {
          const val = row[col];
          if (val != null && String(val).length > 0) idParts.push(String(val));
        }
        const identifier = idParts.length > 0 ? idParts.join(" — ") : sec.key;

        const secondaryParts: string[] = [];
        for (const col of sec.secondaryCols) {
          const val = row[col];
          if (val != null && String(val).length > 0) secondaryParts.push(String(val));
        }
        const secondaryInfo = secondaryParts.join(" | ");

        const deletedAt = sec.deletedAtCol ? row[sec.deletedAtCol] : row["updated_at"];

        allItems.push({
          id: row["id"],
          section: sec.key,
          identifier,
          secondaryInfo,
          deletedBy: "Sistema",
          deletedAt: deletedAt ?? new Date().toISOString(),
        });
      }
    }

    allItems.sort((a, b) =>
      String(b.deletedAt).localeCompare(String(a.deletedAt))
    );

    return jsonResponse({ ok: true, data: allItems });
  } catch (e) {
    return errorResponse(500, "SYSTEM_UNEXPECTED", String(e));
  }
});
