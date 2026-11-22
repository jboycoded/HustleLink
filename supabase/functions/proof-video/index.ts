import { createClient } from "npm:@supabase/supabase-js@2";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
// Supabase injects named secret API keys as a JSON object.
const secretKeysJson = Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}";
let SUPABASE_SECRET_KEY = "";
try {
  SUPABASE_SECRET_KEY = JSON.parse(secretKeysJson)["default"] ?? "";
} catch {
  console.error("Supabase secret-key environment variable is not valid JSON.");
}
const BUCKET = "worker-proof-videos";
const PHOTO_BUCKET = "profile-photos";

const firebaseJwks = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function verifyFirebaseUser(request: Request): Promise<string> {
  const authorization = request.headers.get("Authorization") ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new Error("Missing Firebase ID token.");

  if (!FIREBASE_PROJECT_ID) {
    throw new Error("Firebase project configuration is missing.");
  }

  const { payload } = await jwtVerify(match[1], firebaseJwks, {
    issuer: `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
    audience: FIREBASE_PROJECT_ID,
    algorithms: ["RS256"],
  });

  const uid = payload.sub;
  const authTime = payload.auth_time;
  if (
    typeof uid !== "string" ||
    uid.length === 0 ||
    typeof authTime !== "number" ||
    authTime > Math.floor(Date.now() / 1000)
  ) {
    throw new Error("Invalid Firebase user claims.");
  }

  return uid;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const uid = await verifyFirebaseUser(request);

    if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) {
      return jsonResponse({ error: "Storage service is not configured." }, 500);
    }

    const body = await request.json().catch(() => ({}));
    const action = body?.action;
    const path = `workerProofVideos/${uid}/profileVideo`;
    const photoPath = `profilePhotos/${uid}/profilePhoto`;

    const admin = createClient(SUPABASE_URL, SUPABASE_SECRET_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const storage = admin.storage.from(BUCKET);
    const photoStorage = admin.storage.from(PHOTO_BUCKET);

    if (action === "create-upload") {
      const { data, error } = await storage.createSignedUploadUrl(path, {
        upsert: true,
      });
      if (error) {
        console.error("Could not create profile-video upload permission.");
        return jsonResponse({ error: "Unable to prepare the video upload." }, 500);
      }
      return jsonResponse({ path, token: data.token });
    }

    if (action === "delete") {
      const { error } = await storage.remove([path]);
      if (error) {
        console.error("Could not delete profile video.");
        return jsonResponse({ error: "Unable to delete the profile video." }, 500);
      }
      return jsonResponse({ success: true });
    }

    if (action === "create-profile-photo-upload") {
      const { data, error } = await photoStorage.createSignedUploadUrl(photoPath, { upsert: true });
      if (error) {
        console.error("Could not create profile-photo upload permission.");
        return jsonResponse({ error: "Unable to prepare the photo upload." }, 500);
      }
      return jsonResponse({ path: photoPath, token: data.token });
    }

    if (action === "delete-profile-photo") {
      const { error } = await photoStorage.remove([photoPath]);
      if (error) {
        console.error("Could not delete profile photo.");
        return jsonResponse({ error: "Unable to delete the profile photo." }, 500);
      }
      return jsonResponse({ success: true });
    }

    return jsonResponse({ error: "Unsupported action." }, 400);
  } catch (error) {
    // Do not log the supplied bearer token or any secret values.
    const message = error instanceof Error ? error.message : "Unauthorized.";
    const status = message.includes("Firebase") || message.includes("token") ||
        message.includes("claims")
      ? 401
      : 400;
    return jsonResponse({ error: status === 401 ? "Unauthorized." : message }, status);
  }
});
