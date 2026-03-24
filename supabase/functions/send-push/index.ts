import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const fcmServerKey = Deno.env.get("FCM_SERVER_KEY")!;

serve(async (req) => {
  try {
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

    // Send FCM push to each token
    for (const { fcm_token } of tokens) {
      await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${fcmServerKey}`,
        },
        body: JSON.stringify({
          to: fcm_token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: {
            type: notification.type,
            notification_id: notification.id,
            ...(notification.data || {}),
          },
        }),
      });
    }

    return new Response("Sent", { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
