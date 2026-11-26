import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "npm:jose@5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const SERVICE_ACCOUNT_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
const firebaseJwks = createRemoteJWKSet(new URL(
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
));

type ServiceAccount = {
  client_email: string;
  private_key: string;
  token_uri?: string;
};

let serviceAccount: ServiceAccount | null = null;
let cachedAccessToken = "";
let accessTokenExpiresAt = 0;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function getServiceAccount(): ServiceAccount {
  if (serviceAccount) return serviceAccount;
  if (!SERVICE_ACCOUNT_JSON) throw new Error("Firebase service account is not configured.");
  const parsed = JSON.parse(SERVICE_ACCOUNT_JSON);
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error("Firebase service account JSON is incomplete.");
  }
  serviceAccount = parsed as ServiceAccount;
  return serviceAccount;
}

async function verifyFirebaseUser(request: Request): Promise<string> {
  const match = (request.headers.get("Authorization") ?? "").match(/^Bearer\s+(.+)$/i);
  if (!match || !PROJECT_ID) throw new Error("Unauthorized.");
  const { payload } = await jwtVerify(match[1], firebaseJwks, {
    issuer: `https://securetoken.google.com/${PROJECT_ID}`,
    audience: PROJECT_ID,
    algorithms: ["RS256"],
  });
  if (typeof payload.sub !== "string" || !payload.sub ||
      typeof payload.auth_time !== "number" ||
      payload.auth_time > Math.floor(Date.now() / 1000)) {
    throw new Error("Unauthorized.");
  }
  return payload.sub;
}

async function googleAccessToken(): Promise<string> {
  if (cachedAccessToken && Date.now() < accessTokenExpiresAt - 60_000) {
    return cachedAccessToken;
  }
  const account = getServiceAccount();
  const key = await importPKCS8(account.private_key, "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience(account.token_uri ?? "https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch(account.token_uri ?? "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== "string") {
    console.error("Google service-account authentication failed.");
    throw new Error("Unable to authenticate with Firebase services.");
  }
  cachedAccessToken = result.access_token;
  accessTokenExpiresAt = Date.now() + Number(result.expires_in ?? 3600) * 1000;
  return cachedAccessToken;
}

function firestoreDocumentUrl(path: string): string {
  return `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`;
}

async function firestoreRequest(path: string, method = "GET", body?: unknown) {
  const token = await googleAccessToken();
  const response = await fetch(firestoreDocumentUrl(path), {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (response.status === 404) return null;
    console.error("Firestore REST request failed:", response.status);
    throw new Error("Unable to access notification data.");
  }
  return data;
}

async function tokenDocumentId(token: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function stringField(fields: Record<string, any>, name: string): string {
  return fields?.[name]?.stringValue ?? "";
}

async function sendPush(notificationId: string, uid: string) {
  if (!notificationId || notificationId.length > 150) {
    throw new Error("A valid notification ID is required.");
  }
  const notification = await firestoreRequest(`notifications/${notificationId}`);
  const fields = notification?.fields;
  if (!fields || stringField(fields, "actorId") !== uid) {
    throw new Error("Notification not found or not created by this account.");
  }
  const recipientId = stringField(fields, "recipientId");
  if (!recipientId || recipientId === uid) throw new Error("Invalid notification recipient.");

  const token = await googleAccessToken();
  const tokenUrl = firestoreDocumentUrl(`users/${recipientId}/fcmTokens`) + "?pageSize=100";
  const tokenResponse = await fetch(tokenUrl, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const tokenData = await tokenResponse.json().catch(() => ({}));
  if (!tokenResponse.ok) throw new Error("Unable to retrieve recipient devices.");
  const documents = Array.isArray(tokenData.documents) ? tokenData.documents : [];
  if (documents.length === 0) return { sent: 0, devices: 0 };

  const title = stringField(fields, "title") || "HustleLink";
  const body = stringField(fields, "body");
  const type = stringField(fields, "type");
  const relatedId = stringField(fields, "relatedId");
  let sent = 0;

  for (const document of documents) {
    const deviceToken = document.fields?.token?.stringValue;
    if (!deviceToken) continue;
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: deviceToken,
            notification: { title, body },
            data: { type, relatedId, notificationId },
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "hustlelink_notifications",
                sound: "default",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
            },
          },
        }),
      },
    );
    if (response.ok) {
      sent++;
    } else {
      const error = await response.json().catch(() => ({}));
      const errorCode = error?.error?.details?.find(
        (detail: any) => detail?.errorCode === "UNREGISTERED",
      );
      if (response.status === 404 || errorCode) {
        await firestoreRequest(
          `users/${recipientId}/fcmTokens/${document.name.split("/").pop()}`,
          "DELETE",
        );
      } else {
        console.error("FCM delivery failed:", response.status);
      }
    }
  }
  return { sent, devices: documents.length };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  try {
    const uid = await verifyFirebaseUser(request);
    const body = await request.json().catch(() => ({}));
    const action = body?.action;

    if (action === "register-token") {
      const deviceToken = typeof body?.token === "string" ? body.token.trim() : "";
      if (!deviceToken || deviceToken.length > 4096) {
        return jsonResponse({ error: "Invalid device token." }, 400);
      }
      const id = await tokenDocumentId(deviceToken);
      await firestoreRequest(`users/${uid}/fcmTokens/${id}`, "PATCH", {
        fields: {
          token: { stringValue: deviceToken },
          platform: { stringValue: typeof body?.platform === "string" ? body.platform : "android" },
          updatedAt: { timestampValue: new Date().toISOString() },
        },
      });
      return jsonResponse({ success: true });
    }

    if (action === "remove-token") {
      const deviceToken = typeof body?.token === "string" ? body.token.trim() : "";
      if (!deviceToken) return jsonResponse({ success: true });
      const id = await tokenDocumentId(deviceToken);
      await firestoreRequest(`users/${uid}/fcmTokens/${id}`, "DELETE");
      return jsonResponse({ success: true });
    }

    if (action === "send-notification") {
      const notificationId = typeof body?.notificationId === "string"
        ? body.notificationId.trim()
        : "";
      const result = await sendPush(notificationId, uid);
      return jsonResponse({ success: true, ...result });
    }

    return jsonResponse({ error: "Unsupported action." }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Request failed.";
    const unauthorized = message === "Unauthorized.";
    if (!unauthorized) console.error("Push notification request failed:", message);
    return jsonResponse({ error: unauthorized ? "Unauthorized." : message }, unauthorized ? 401 : 400);
  }
});
