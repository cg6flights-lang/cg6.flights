import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const reportTypes = new Set(["metar", "taf"]);

type ErrorCategory = "AUTH" | "VALIDATION" | "NETWORK" | "SYSTEM";

function jsonResponse(
  body: unknown,
  status = 200,
  headers: Record<string, string> = {},
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, ...headers, "Content-Type": "application/json" },
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
      "VALIDATION_INVALID_INPUT",
      "Metodo no permitido.",
      "VALIDATION",
      "medium",
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
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
  const reportType = String(payload.report_type ?? "metar").trim()
    .toLowerCase();
  const icao = String(payload.icao ?? "").trim().toUpperCase();

  if (!reportTypes.has(reportType)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Tipo de reporte meteorologico invalido.",
      "VALIDATION",
      "medium",
    );
  }

  if (!/^[A-Z]{4}$/.test(icao)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Codigo OACI invalido.",
      "VALIDATION",
      "medium",
    );
  }

  const url = new URL(`https://aviationweather.gov/api/data/${reportType}`);
  url.searchParams.set("ids", icao);
  url.searchParams.set("format", "json");

  try {
    const upstream = await fetch(url, {
      headers: { "Accept": "application/json" },
    });

    if (!upstream.ok) {
      return errorResponse(
        502,
        "NETWORK_UPSTREAM_ERROR",
        "No se pudo consultar Aviation Weather.",
        "NETWORK",
      );
    }

    const data = await upstream.json();
    if (!Array.isArray(data)) {
      return errorResponse(
        502,
        "NETWORK_UPSTREAM_ERROR",
        "Respuesta meteorologica invalida.",
        "NETWORK",
      );
    }

    return jsonResponse(
      {
        ok: true,
        data,
        meta: { source: "aviationweather.gov", report_type: reportType, icao },
      },
      200,
      { "Cache-Control": "public, max-age=60" },
    );
  } catch (_) {
    return errorResponse(
      504,
      "NETWORK_TIMEOUT",
      "No se pudo consultar Aviation Weather.",
      "NETWORK",
    );
  }
});
