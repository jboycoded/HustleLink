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
    scope: "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/identitytoolkit",
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


type AdminRole = "super_admin" | "admin" | "moderator" | "support" | "analyst";

function firestoreString(value: string) {
  return { stringValue: value };
}
function firestoreTimestamp(value = new Date()) {
  return { timestampValue: value.toISOString() };
}
function decodeValue(value: any): any {
  if (!value || typeof value !== "object") return null;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("timestampValue" in value) return value.timestampValue;
  if ("arrayValue" in value) return (value.arrayValue.values ?? []).map(decodeValue);
  if ("mapValue" in value) return decodeFields(value.mapValue.fields ?? {});
  return null;
}
function decodeFields(fields: Record<string, any>) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}
async function firestorePatch(path: string, fields: Record<string, any>) {
  const url = new URL(firestoreDocumentUrl(path));
  for (const key of Object.keys(fields)) url.searchParams.append("updateMask.fieldPaths", key);
  const token = await googleAccessToken();
  const response = await fetch(url, {
    method: "PATCH",
    headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" },
    body: JSON.stringify({ fields }),
  });
  if (!response.ok) {
    console.error("Firestore admin update failed:", response.status);
    throw new Error("Unable to save the administrative change.");
  }
  return await response.json();
}
async function firestoreCreate(collection: string, id: string, fields: Record<string, any>) {
  const token = await googleAccessToken();
  const url = firestoreDocumentUrl(collection) + "?documentId=" + encodeURIComponent(id);
  const response = await fetch(url, {
    method: "POST",
    headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" },
    body: JSON.stringify({ fields }),
  });
  if (!response.ok) {
    console.error("Firestore admin create failed:", response.status);
    throw new Error("Unable to create the administrative record.");
  }
  return await response.json();
}

async function firestoreBatchCreate(collection: string, documents: { id: string; fields: Record<string, any> }[]) {
  const token = await googleAccessToken();
  for (let start = 0; start < documents.length; start += 400) {
    const writes = documents.slice(start, start + 400).map((document) => ({
      update: {
        name: "projects/" + PROJECT_ID + "/databases/(default)/documents/" + collection + "/" + document.id,
        fields: document.fields,
      },
      currentDocument: { exists: false },
    }));
    const response = await fetch(
      "https://firestore.googleapis.com/v1/projects/" + PROJECT_ID + "/databases/(default)/documents:commit",
      {
        method: "POST",
        headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" },
        body: JSON.stringify({ writes }),
      },
    );
    if (!response.ok) {
      console.error("Firestore batch create failed:", response.status);
      throw new Error("Unable to create announcement notifications.");
    }
  }
}

async function listCollection(collection: string): Promise<any[]> {
  const token = await googleAccessToken();
  const documents: any[] = [];
  let pageToken = "";
  do {
    const url = new URL(firestoreDocumentUrl(collection));
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);
    const response = await fetch(url, { headers: { Authorization: "Bearer " + token } });
    if (!response.ok) throw new Error("Unable to retrieve platform users.");
    const result = await response.json();
    documents.push(...(result.documents ?? []));
    pageToken = result.nextPageToken ?? "";
  } while (pageToken && documents.length < 10000);
  return documents;
}
async function requireAdmin(uid: string, allowed: AdminRole[]): Promise<AdminRole> {
  const record = await firestoreRequest("adminUsers/" + uid);
  const fields = record?.fields;
  const role = fields ? stringField(fields, "role") : "";
  const active = fields?.active?.booleanValue === true;
  if (!active || !allowed.includes(role as AdminRole)) {
    throw new Error("You do not have permission to perform this action.");
  }
  return role as AdminRole;
}
async function writeAdminAudit(uid: string, role: string, action: string,
  targetType: string, targetId: string, details = "") {
  const id = crypto.randomUUID();
  await firestoreCreate("adminAuditLogs", id, {
    actorId: firestoreString(uid),
    actorRole: firestoreString(role),
    action: firestoreString(action),
    targetType: firestoreString(targetType),
    targetId: firestoreString(targetId),
    details: firestoreString(details.slice(0, 1000)),
    createdAt: firestoreTimestamp(),
  });
}
async function sendAnnouncement(uid: string, role: string, body: any) {
  const title = typeof body?.title === "string" ? body.title.trim() : "";
  const message = typeof body?.body === "string" ? body.body.trim() : "";
  const audience = typeof body?.audience === "string" ? body.audience : "all";
  const targetUserId = typeof body?.targetUserId === "string" ? body.targetUserId.trim() : "";
  if (!title || title.length > 100 || !message || message.length > 1000) {
    throw new Error("Enter a title (max 100 characters) and message (max 1,000 characters).");
  }
  if (!["all", "workers", "posters", "user"].includes(audience)) {
    throw new Error("Invalid announcement audience.");
  }
  if (audience === "user" && !targetUserId) throw new Error("Select a user for this announcement.");

  let recipients: any[] = [];
  if (audience === "user") {
    const target = await firestoreRequest("users/" + targetUserId);
    if (target && target.fields?.accountStatus?.stringValue !== "suspended") {
      recipients = [{ name: "users/" + targetUserId, fields: target.fields ?? {} }];
    }
  } else {
    const users = await listCollection("users");
    recipients = users.filter((doc) => {
      const fields = doc.fields ?? {};
      const status = fields.accountStatus?.stringValue ?? "active";
      if (status === "suspended") return false;
      if (audience === "workers") {
        return fields.activeRole?.stringValue === "worker";
      }
      if (audience === "posters") {
        return fields.activeRole?.stringValue === "poster";
      }
      return true;
    });
  }
  recipients = recipients.filter((doc) => doc.name.split("/").pop() !== uid);
  const announcementId = crypto.randomUUID();
  await firestoreCreate("adminAnnouncements", announcementId, {
    title: firestoreString(title),
    body: firestoreString(message),
    audience: firestoreString(audience),
    createdBy: firestoreString(uid),
    createdByRole: firestoreString(role),
    recipientCount: { integerValue: String(recipients.length) },
    createdAt: firestoreTimestamp(),
  });

  const notificationDocuments = recipients.map((recipient) => {
    const recipientId = recipient.name.split("/").pop() ?? "";
    return {
      id: "announcement_" + announcementId + "_" + recipientId,
      recipientId,
      fields: {
        recipientId: firestoreString(recipientId),
        actorId: firestoreString(uid),
        type: firestoreString("announcement"),
        title: firestoreString(title),
        body: firestoreString(message),
        relatedId: firestoreString(announcementId),
        isRead: { booleanValue: false },
        createdAt: firestoreTimestamp(),
      },
    };
  }).filter((item) => item.recipientId.length > 0);
  await firestoreBatchCreate("notifications", notificationDocuments);
  let delivered = 0;
  for (let start = 0; start < notificationDocuments.length; start += 20) {
    const chunk = notificationDocuments.slice(start, start + 20);
    const results = await Promise.all(chunk.map(async (item) => {
      try {
        await sendPush(item.id, uid);
        return true;
      } catch (_) {
        console.error("Announcement push failed for recipient.");
        return false;
      }
    }));
    delivered += results.filter(Boolean).length;
  }
  await writeAdminAudit(uid, role, "announcement_sent", "announcement", announcementId,
    "Audience: " + audience + "; recipients: " + recipients.length);
  return { announcementId, recipients: recipients.length, pushDeliveries: delivered };
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

    if (action === "admin-close-gig" || action === "admin-remove-gig") {
      const role = await requireAdmin(uid, ["super_admin", "admin", "moderator"]);
      const gigId = typeof body?.gigId === "string" ? body.gigId.trim() : "";
      if (!gigId) throw new Error("A gig ID is required.");
      const gig = await firestoreRequest("gigs/" + gigId);
      if (!gig) throw new Error("Gig not found.");
      const currentStatus = gig.fields?.status?.stringValue ?? "unknown";
      if (action === "admin-close-gig" && currentStatus !== "open") {
        throw new Error("Only open gigs can be closed.");
      }
      const nextStatus = action === "admin-close-gig" || currentStatus === "open"
        ? "closed"
        : currentStatus;
      const moderationStatus = action === "admin-remove-gig" ? "removed" : "closed";
      await firestorePatch("gigs/" + gigId, {
        status: firestoreString(nextStatus),
        moderationStatus: firestoreString(moderationStatus),
        moderatedAt: firestoreTimestamp(),
        moderatedBy: firestoreString(uid),
        moderationNote: firestoreString(typeof body?.note === "string" ? body.note.trim().slice(0, 500) : ""),
        updatedAt: firestoreTimestamp(),
      });
      await writeAdminAudit(uid, role, action === "admin-remove-gig" ? "gig_removed" : "gig_closed",
        "gig", gigId, typeof body?.note === "string" ? body.note : "");
      return jsonResponse({ success: true });
    }

    if (action === "admin-review-report") {
      const role = await requireAdmin(uid, ["super_admin", "admin", "moderator", "support"]);
      const reportId = typeof body?.reportId === "string" ? body.reportId.trim() : "";
      const status = typeof body?.status === "string" ? body.status : "";
      const note = typeof body?.resolutionNote === "string" ? body.resolutionNote.trim().slice(0, 1000) : "";
      if (!reportId || !["under_review", "resolved", "dismissed"].includes(status)) {
        throw new Error("Choose a valid report status.");
      }
      const report = await firestoreRequest("reports/" + reportId);
      if (!report) throw new Error("Report not found.");
      await firestorePatch("reports/" + reportId, {
        status: firestoreString(status),
        reviewedAt: firestoreTimestamp(),
        reviewedBy: firestoreString(uid),
        resolutionNote: firestoreString(note),
      });
      await writeAdminAudit(uid, role, "report_" + status, "report", reportId, note);
      return jsonResponse({ success: true });
    }

    if (action === "admin-get-report-target") {
      await requireAdmin(uid, ["super_admin", "admin", "moderator", "support"]);
      const targetType = typeof body?.targetType === "string" ? body.targetType : "";
      const targetId = typeof body?.targetId === "string" ? body.targetId.trim() : "";
      if (!targetId || !["user", "gig"].includes(targetType)) {
        throw new Error("A valid report target is required.");
      }
      const target = await firestoreRequest((targetType === "user" ? "users/" : "gigs/") + targetId);
      if (!target?.fields) return jsonResponse({ success: true, target: null });
      const data = decodeFields(target.fields);
      const allowedFields = targetType === "user"
        ? ["fullName", "email", "location", "activeRole", "accountStatus", "createdAt", "photoUrl", "rating", "completedGigs"]
        : ["title", "description", "category", "pay", "posterName", "posterId", "location", "status", "moderationStatus", "createdAt"];
      const safeTarget = Object.fromEntries(allowedFields
        .filter((key) => data[key] !== undefined)
        .map((key) => [key, data[key]]));
      return jsonResponse({ success: true, target: safeTarget });
    }

    if (action === "admin-set-user-status") {
      const role = await requireAdmin(uid, ["super_admin", "admin"]);
      const targetUid = typeof body?.userId === "string" ? body.userId.trim() : "";
      const suspend = body?.suspended === true;
      const reason = typeof body?.reason === "string" ? body.reason.trim().slice(0, 500) : "";
      if (!targetUid || targetUid === uid) throw new Error("You cannot suspend your own account.");
      const adminTarget = await firestoreRequest("adminUsers/" + targetUid);
      if (adminTarget !== null) {
        throw new Error("Administrative accounts cannot be suspended from User Management.");
      }
      const target = await firestoreRequest("users/" + targetUid);
      if (!target) throw new Error("User not found.");
      const token = await googleAccessToken();
      const authResponse = await fetch(
        "https://identitytoolkit.googleapis.com/v1/projects/" + PROJECT_ID + "/accounts:update",
        {
          method: "POST",
          headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" },
          body: JSON.stringify({ targetProjectId: PROJECT_ID, localId: targetUid, disableUser: suspend }),
        },
      );
      if (!authResponse.ok) {
        const error = await authResponse.json().catch(() => ({}));
        console.error("Firebase Auth account status update failed:", authResponse.status);
        throw new Error(error?.error?.message ?? "Firebase could not update this account. Check the service account's Identity Toolkit permissions.");
      }
      await firestorePatch("users/" + targetUid, {
        accountStatus: firestoreString(suspend ? "suspended" : "active"),
        suspensionReason: firestoreString(suspend ? reason : ""),
        suspendedBy: firestoreString(suspend ? uid : ""),
        statusUpdatedAt: firestoreTimestamp(),
      });
      if (suspend) {
        const postedGigs = await listCollection("gigs");
        const activeGigs = postedGigs.filter((doc) =>
          doc.fields?.posterId?.stringValue === targetUid &&
          doc.fields?.status?.stringValue === "open");
        for (const gig of activeGigs) {
          const gigId = gig.name.split("/").pop();
          if (!gigId) continue;
          await firestorePatch("gigs/" + gigId, {
            status: firestoreString("closed"),
            moderationStatus: firestoreString("account_suspended"),
            moderatedAt: firestoreTimestamp(),
            moderatedBy: firestoreString(uid),
            moderationNote: firestoreString("Poster account suspended: " + reason),
            updatedAt: firestoreTimestamp(),
          });
        }
      }
      await writeAdminAudit(uid, role, suspend ? "user_suspended" : "user_restored",
        "user", targetUid, reason);
      return jsonResponse({ success: true });
    }

    if (action === "admin-send-announcement") {
      const role = await requireAdmin(uid, ["super_admin", "admin"]);
      const result = await sendAnnouncement(uid, role, body);
      return jsonResponse({ success: true, ...result });
    }

    if (action === "admin-overview") {
      await requireAdmin(uid, ["super_admin", "admin", "moderator", "support", "analyst"]);
      const [users, gigs, reports] = await Promise.all([
        listCollection("users"), listCollection("gigs"), listCollection("reports"),
      ]);
      const activeGigs = gigs.filter((doc) => doc.fields?.status?.stringValue === "open").length;
      const openReports = reports.filter((doc) => doc.fields?.status?.stringValue === "open").length;
      return jsonResponse({
        success: true,
        users: users.length,
        gigs: gigs.length,
        openGigs: activeGigs,
        reports: reports.length,
        pendingReports: openReports,
      });
    }

    return jsonResponse({ error: "Unsupported action." }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Request failed.";
    const unauthorized = message === "Unauthorized.";
    if (!unauthorized) console.error("Push notification request failed:", message);
    return jsonResponse({ error: unauthorized ? "Unauthorized." : message }, unauthorized ? 401 : 400);
  }
});
