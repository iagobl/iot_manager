import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library";

type ManualPushPayload = {
recipientUserIds: string[];
title: string;
body: string;
data?: Record<string, string>;
};

type WebhookPayload = {
type?: string;
table?: string;
schema?: string;
record?: Record<string, unknown> | null;
old_record?: Record<string, unknown> | null;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const firebaseServiceAccountJson =
Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

if (!firebaseServiceAccountJson) {
  throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON");
}

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const body = await req.json();

    const manualPayload = toManualPayload(body);
    if (manualPayload != null) {
      return await handleManualPush(manualPayload);
    }

    const webhookPayload = toWebhookPayload(body);
    if (webhookPayload != null) {
      return await handleWebhookPush(webhookPayload);
    }

    return json({ error: "Unsupported payload" }, 400);
  } catch (error) {
    console.error("send-push error:", error);

    return json(
      {
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});

function toManualPayload(value: unknown): ManualPushPayload | null {
  if (
    typeof value !== "object" ||
    value === null ||
    !("recipientUserIds" in value) ||
    !("title" in value) ||
    !("body" in value)
  ) {
    return null;
  }

  const payload = value as Record<string, unknown>;
  const recipientUserIds = Array.isArray(payload.recipientUserIds)
    ? payload.recipientUserIds.map((e) => String(e))
    : [];

  const title = String(payload.title ?? "").trim();
  const body = String(payload.body ?? "").trim();

  if (recipientUserIds.length === 0 || title.isEmpty || body.isEmpty) {
    return null;
  }

  const data =
    typeof payload.data === "object" && payload.data !== null
      ? Object.fromEntries(
          Object.entries(payload.data as Record<string, unknown>).map(
            ([key, value]) => [key, String(value)],
          ),
)
: undefined;

return {
recipientUserIds,
title,
body,
data,
};
}

function toWebhookPayload(value: unknown): WebhookPayload | null {
  if (
    typeof value !== "object" ||
    value === null ||
    !("table" in value) ||
    !("type" in value)
  ) {
    return null;
  }

  const payload = value as Record<string, unknown>;

  return {
    type: String(payload.type ?? ""),
    table: String(payload.table ?? ""),
    schema: String(payload.schema ?? ""),
    record: (payload.record as Record<string, unknown> | null) ?? null,
    old_record: (payload.old_record as Record<string, unknown> | null) ?? null,
  };
}

async function handleManualPush(payload: ManualPushPayload): Promise<Response> {
  const tokens = await getTokensForUsers(payload.recipientUserIds);

  if (tokens.length === 0) {
    return json({
      ok: true,
      sent: 0,
      reason: "No active tokens found",
    });
  }

  const { accessToken, projectId } = await getFirebaseAccessToken();

  let sent = 0;

  for (const token of tokens) {
    const ok = await sendFcmMessage({
      accessToken,
      projectId,
      token,
      title: payload.title,
      body: payload.body,
      data: payload.data ?? {},
    });

    if (ok) sent++;
  }

  return json({
    ok: true,
    sent,
    totalTokens: tokens.length,
    mode: "manual",
  });
}

async function handleWebhookPush(payload: WebhookPayload): Promise<Response> {
  const eventType = (payload.type ?? "").toUpperCase();
  const table = (payload.table ?? "").trim();
  const record = payload.record ?? null;
  const oldRecord = payload.old_record ?? null;

  if (table === "device_shares") {
    const result = await handleDeviceSharesWebhook({
      eventType,
      record,
      oldRecord,
    });

    return json({
      ok: true,
      mode: "webhook",
      source: "device_shares",
      ...result,
    });
  }

  if (table === "incidents") {
    const result = await handleIncidentsWebhook({
      eventType,
      record,
      oldRecord,
    });

    return json({
      ok: true,
      mode: "webhook",
      source: "incidents",
      ...result,
    });
  }

  return json({
    ok: true,
    mode: "webhook",
    ignored: true,
    reason: `Unsupported table: ${table}`,
  });
}

async function handleDeviceSharesWebhook(args: {
  eventType: string;
  record: Record<string, unknown> | null;
  oldRecord: Record<string, unknown> | null;
}) {
  const record = args.record;
  if (record == null) {
    return { ignored: true, reason: "Missing record" };
  }

  // Solo avisamos cuando una invitación queda pendiente.
  const status = String(record["status"] ?? "").trim().toLowerCase();
  if (status !== "pending") {
    return { ignored: true, reason: "Status is not pending" };
  }

  const recipientUserId = String(record["shared_with_user_id"] ?? "").trim();
  const deviceId = String(record["device_id"] ?? "").trim();
  const ownerId = String(record["owner_id"] ?? "").trim();
  const shareId = String(record["id"] ?? "").trim();

  if (recipientUserId.isEmpty || deviceId.isEmpty || shareId.isEmpty) {
    return { ignored: true, reason: "Missing required identifiers" };
  }

  const deviceName = await getDeviceName(deviceId);
  const ownerName = await getOwnerName(ownerId);

  const response = await sendPushToUsers({
    recipientUserIds: [recipientUserId],
    title: "Nueva invitación",
    body: `${ownerName} te ha invitado a acceder a ${deviceName}.`,
    data: {
      notification_type: "invitation",
      share_id: shareId,
      device_id: deviceId,
    },
  });

  return {
    ignored: false,
    recipients: 1,
    ...response,
  };
}

async function handleIncidentsWebhook(args: {
  eventType: string;
  record: Record<string, unknown> | null;
  oldRecord: Record<string, unknown> | null;
}) {
  const record = args.record;
  if (record == null) {
    return { ignored: true, reason: "Missing record" };
  }

  // En insert siempre interesa. En update, solo si sigue sin acknowledged.
  const isAcknowledged = record["is_acknowledged"] === true;
  if (isAcknowledged) {
    return { ignored: true, reason: "Incident already acknowledged" };
  }

  const incidentId = String(record["id"] ?? "").trim();
  const deviceId = String(record["device_id"] ?? "").trim();
  const type = String(record["type"] ?? "").trim();
  const message = String(record["message"] ?? "").trim();

  if (incidentId.isEmpty || deviceId.isEmpty) {
    return { ignored: true, reason: "Missing incident or device id" };
  }

  const recipients = await getIncidentRecipients(deviceId);
  if (recipients.length === 0) {
    return { ignored: true, reason: "No recipients found" };
  }

  const deviceName = await getDeviceName(deviceId);

  const response = await sendPushToUsers({
    recipientUserIds: recipients,
    title: mapIncidentTitle(type),
    body: message.isNotEmpty
        ? message
        : `Se ha detectado una incidencia en ${deviceName}.`,
    data: {
      notification_type: "incident",
      incident_id: incidentId,
      device_id: deviceId,
    },
  });

  return {
    ignored: false,
    recipients: recipients.length,
    ...response,
  };
}

async function sendPushToUsers(args: {
  recipientUserIds: string[];
  title: string;
  body: string;
  data: Record<string, string>;
}) {
  const tokens = await getTokensForUsers(args.recipientUserIds);

  if (tokens.length === 0) {
    return {
      sent: 0,
      totalTokens: 0,
      reason: "No active tokens found",
    };
  }

  const { accessToken, projectId } = await getFirebaseAccessToken();

  let sent = 0;

  for (const token of tokens) {
    const ok = await sendFcmMessage({
      accessToken,
      projectId,
      token,
      title: args.title,
      body: args.body,
      data: args.data,
    });

    if (ok) sent++;
  }

  return {
    sent,
    totalTokens: tokens.length,
  };
}

async function getTokensForUsers(userIds: string[]): Promise<string[]> {
  const cleanedIds = userIds
    .map((id) => id.trim())
    .where((id) => id.isNotEmpty);

  if (cleanedIds.length === 0) return [];

  const { data, error } = await supabase
    .from("user_push_tokens")
    .select("token")
    .in("user_id", cleanedIds);

  if (error) throw error;

  return (data ?? [])
    .map((row) => String(row.token ?? ""))
    .where((token) => token.trim().length > 0);
}

async function getIncidentRecipients(deviceId: string): Promise<string[]> {
  const recipients = new Set<string>();

  const { data: deviceRow, error: deviceError } = await supabase
    .from("devices")
    .select("owner_id")
    .eq("id", deviceId)
    .maybeSingle();

  if (deviceError) throw deviceError;

  const ownerId = String(deviceRow?.owner_id ?? "").trim();
  if (ownerId.isNotEmpty) {
    recipients.add(ownerId);
  }

  const { data: shares, error: sharesError } = await supabase
    .from("device_shares")
    .select("shared_with_user_id")
    .eq("device_id", deviceId)
    .eq("status", "accepted");

  if (sharesError) throw sharesError;

  for (const row of shares ?? []) {
    const userId = String(row.shared_with_user_id ?? "").trim();
    if (userId.isNotEmpty) {
      recipients.add(userId);
    }
  }

  return [...recipients];
}

async function getDeviceName(deviceId: string): Promise<string> {
  if (deviceId.isEmpty) return "el dispositivo";

  const { data, error } = await supabase
    .from("devices")
    .select("name")
    .eq("id", deviceId)
    .maybeSingle();

  if (error) throw error;

  return String(data?.name ?? "el dispositivo");
}

async function getOwnerName(ownerId: string): Promise<string> {
  if (ownerId.isEmpty) return "Un usuario";

  const { data, error } = await supabase
    .from("profiles")
    .select("first_name, last_name, email")
    .eq("id", ownerId)
    .maybeSingle();

  if (error) throw error;

  const firstName = String(data?.first_name ?? "").trim();
  const lastName = String(data?.last_name ?? "").trim();
  const email = String(data?.email ?? "").trim();
  const fullName = `${firstName} ${lastName}`.trim();

  return fullName.isNotEmpty
    ? fullName
    : (email.isNotEmpty ? email : "Un usuario");
}

async function getFirebaseAccessToken(): Promise<{
  accessToken: string;
  projectId: string;
}> {
  const credentials = JSON.parse(firebaseServiceAccountJson);

  const jwtClient = new JWT({
    email: credentials.client_email,
    key: credentials.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  const tokenResponse = await jwtClient.authorize();
  const accessToken = tokenResponse.access_token;

  if (!accessToken) {
    throw new Error("Could not obtain Firebase access token");
  }

  return {
    accessToken,
    projectId: String(credentials.project_id),
  };
}

async function sendFcmMessage(args: {
  accessToken: string;
  projectId: string;
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<boolean> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${args.projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${args.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: args.token,
          notification: {
            title: args.title,
            body: args.body,
          },
          data: args.data,
          android: {
            priority: "HIGH",
            notification: {
              channel_id: "iot_manager_alerts",
            },
          },
        },
      }),
    },
  );

  if (response.ok) {
    return true;
  }

  const errorText = await response.text();
  console.error("FCM send failed:", errorText);

  if (
    errorText.includes("UNREGISTERED") ||
    errorText.includes("registration-token-not-registered")
  ) {
    await supabase.from("user_push_tokens").delete().eq("token", args.token);
  }

  return false;
}

function mapIncidentTitle(type: string): string {
  const normalized = type.toLowerCase().trim();

  if (normalized.includes("voltage")) return "Tensión máxima superada";
  if (normalized.includes("current")) return "Corriente máxima superada";
  if (normalized.includes("power")) return "Potencia máxima superada";
  if (normalized.includes("temperature")) return "Temperatura elevada";
  if (normalized.includes("offline")) return "Dispositivo desconectado";

  return "Alerta de seguridad";
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}
