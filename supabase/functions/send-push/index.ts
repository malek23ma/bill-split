import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// FCM HTTP v1 API (legacy API was shut down June 2024)
// Requires a Firebase service account JSON stored as FIREBASE_SERVICE_ACCOUNT secret.

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

/** Build a signed JWT for Google OAuth2 token exchange. */
async function createSignedJwt(sa: ServiceAccount): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const unsignedToken = `${encode(header)}.${encode(payload)}`;

  // Import the PEM private key
  const pemContents = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${unsignedToken}.${sig}`;
}

/** Exchange a signed JWT for a short-lived Google access token. */
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const jwt = await createSignedJwt(sa);
  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(`OAuth token exchange failed: ${err}`);
  }

  const data = await resp.json();
  return data.access_token;
}

serve(async (req) => {
  try {
    const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!saJson) {
      return new Response("FIREBASE_SERVICE_ACCOUNT secret not set", { status: 500 });
    }

    const sa: ServiceAccount = JSON.parse(saJson);
    const payload = await req.json();
    const notification = payload.record;

    if (!notification || !notification.recipient_user_id) {
      return new Response("No recipient", { status: 400 });
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get recipient's FCM tokens
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("fcm_token")
      .eq("user_id", notification.recipient_user_id);

    if (!tokens || tokens.length === 0) {
      return new Response("No tokens", { status: 200 });
    }

    // Get a fresh access token for FCM v1
    const accessToken = await getAccessToken(sa);
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    // Send FCM v1 push to each token
    for (const { fcm_token } of tokens) {
      const resp = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: fcm_token,
            notification: {
              title: notification.title,
              body: notification.body,
            },
            data: {
              type: notification.type || "",
              notification_id: notification.id || "",
              ...(notification.data || {}),
            },
          },
        }),
      });

      if (!resp.ok) {
        const err = await resp.text();
        console.error(`FCM send failed for token ${fcm_token}: ${err}`);
      }
    }

    return new Response("Sent", { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
