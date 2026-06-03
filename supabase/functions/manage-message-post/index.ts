import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const actions = new Set(["create_post", "add_comment"]);
const globalRoles = new Set(["leader", "general_admin"]);
const publisherRoles = new Set(["leader", "general_admin", "unit_command", "unit_admin"]);

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

  const audit = async (
    action: string,
    resourceType: string,
    result: "success" | "denied" | "failed",
    resourceId: string | null,
    metadata: Record<string, unknown>,
  ) => {
    await adminClient.from("audit_logs").insert({
      actor_id: userData.user.id,
      actor_role: actorProfile?.role ?? null,
      actor_unit_id: actorProfile?.unit_id ?? null,
      action,
      resource_type: resourceType,
      resource_id: resourceId,
      result,
      metadata,
    });
  };

  if (!actorProfile || actorProfile.status !== "active" || !actorProfile.role) {
    await audit("message_posts.access", "message_post", "denied", null, {
      reason: "profile_not_operational",
    });
    return errorResponse(
      403,
      "AUTHORIZATION_ROLE_REQUIRED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const payload = await req.json().catch(() => ({}));
  const action = String(payload.action ?? "");
  if (!actions.has(action)) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Accion de mensajeria invalida.",
      "VALIDATION",
      "medium",
    );
  }

  if (action === "create_post") {
    const { data: hasPermission, error: permissionError } = await userClient.rpc(
      "has_permission",
      { permission_key: "message_posts.create" },
    );

    if (permissionError || hasPermission !== true || !publisherRoles.has(actorProfile.role)) {
      await audit("message_posts.create", "message_post", "denied", null, {
        reason: "missing_permission",
      });
      return errorResponse(
        403,
        "AUTHORIZATION_PERMISSION_DENIED",
        "Operacion no autorizada.",
        "AUTHORIZATION",
      );
    }

    const body = String(payload.body ?? "").trim();
    const scope = String(payload.scope ?? "unit");
    const requestedUnitId = payload.unit_id ? String(payload.unit_id) : null;
    const isGlobal = globalRoles.has(actorProfile.role);
    const actorUnitId = actorProfile.unit_id ? String(actorProfile.unit_id) : null;
    const unitId = scope === "unit" ? (isGlobal ? requestedUnitId : actorUnitId) : null;

    if (!body) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        "El contenido de la publicacion es obligatorio.",
        "VALIDATION",
        "medium",
      );
    }

    if (scope !== "global" && scope !== "unit") {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        "Alcance de publicacion invalido.",
        "VALIDATION",
        "medium",
      );
    }

    if (scope === "global" && !isGlobal) {
      await audit("message_posts.create", "message_post", "denied", null, {
        reason: "global_scope_denied",
      });
      return errorResponse(
        403,
        "AUTHORIZATION_PERMISSION_DENIED",
        "Operacion no autorizada.",
        "AUTHORIZATION",
      );
    }

    if (scope === "unit" && !unitId) {
      return errorResponse(
        400,
        "VALIDATION_INVALID_INPUT",
        "La unidad es obligatoria para publicar por unidad.",
        "VALIDATION",
        "medium",
      );
    }

    if (scope === "unit") {
      const { data: unit } = await adminClient
        .from("units")
        .select("id")
        .eq("id", unitId)
        .eq("active", true)
        .maybeSingle();

      if (!unit) {
        return errorResponse(
          400,
          "VALIDATION_INVALID_INPUT",
          "Unidad destino invalida.",
          "VALIDATION",
          "medium",
        );
      }
    }

    const { data: post, error: postError } = await adminClient
      .from("message_posts")
      .insert({
        author_id: userData.user.id,
        scope,
        unit_id: unitId,
        body,
      })
      .select("id")
      .single();

    if (postError || !post) {
      await audit("message_posts.create", "message_post", "failed", null, {
        reason: postError?.message ?? "insert_failed",
      });
      return errorResponse(
        500,
        "MESSAGE_POST_SAVE_FAILED",
        "No se pudo crear la publicacion.",
        "SYSTEM",
      );
    }

    await audit("message_posts.create", "message_post", "success", post.id, {
      scope,
      unit_id: unitId,
    });
    return jsonResponse({ ok: true, data: { post_id: post.id }, meta: {} });
  }

  const { data: hasPermission, error: permissionError } = await userClient.rpc(
    "has_permission",
    { permission_key: "message_posts.comment" },
  );
  if (permissionError || hasPermission !== true) {
    await audit("message_posts.comment", "message_post", "denied", null, {
      reason: "missing_permission",
    });
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const postId = String(payload.post_id ?? "");
  const body = String(payload.body ?? "").trim();
  if (!postId || !body) {
    return errorResponse(
      400,
      "VALIDATION_INVALID_INPUT",
      "Publicacion y comentario son obligatorios.",
      "VALIDATION",
      "medium",
    );
  }

  const { data: post } = await adminClient
    .from("message_posts")
    .select("id,scope,unit_id,deleted_at")
    .eq("id", postId)
    .maybeSingle();

  const actorUnitId = actorProfile.unit_id ? String(actorProfile.unit_id) : null;
  const canReadPost = post && !post.deleted_at && (
    post.scope === "global" ||
    globalRoles.has(actorProfile.role) ||
    (post.scope === "unit" && post.unit_id && String(post.unit_id) === actorUnitId)
  );

  if (!canReadPost) {
    await audit("message_posts.comment", "message_post", "denied", postId, {
      reason: "post_scope_denied",
    });
    return errorResponse(
      403,
      "AUTHORIZATION_PERMISSION_DENIED",
      "Operacion no autorizada.",
      "AUTHORIZATION",
    );
  }

  const { data: comment, error: commentError } = await adminClient
    .from("message_post_comments")
    .insert({
      post_id: postId,
      author_id: userData.user.id,
      body,
    })
    .select("id")
    .single();

  if (commentError || !comment) {
    await audit("message_posts.comment", "message_post_comment", "failed", postId, {
      reason: commentError?.message ?? "insert_failed",
    });
    return errorResponse(
      500,
      "MESSAGE_POST_SAVE_FAILED",
      "No se pudo comentar la publicacion.",
      "SYSTEM",
    );
  }

  await audit("message_posts.comment", "message_post_comment", "success", comment.id, {
    post_id: postId,
  });
  return jsonResponse({ ok: true, data: { comment_id: comment.id }, meta: {} });
});
