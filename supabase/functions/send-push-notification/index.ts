import { SignJWT, importPKCS8 } from "npm:jose@5";

Deno.serve(async (req) => {
  try {
    const { token, title, body, conversationId, messageId } = await req.json();

    if (!token || !title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing token, title, or body" }),
        { status: 400 },
      );
    }

    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT secret is not set");
    }
    const serviceAccount = JSON.parse(serviceAccountRaw);

    const privateKey = await importPKCS8(serviceAccount.private_key, "RS256");
    const nowSeconds = Math.floor(Date.now() / 1000);

    // Request BOTH messaging (to send the push) and datastore (to mark
    // the message delivered in Firestore) scopes in one token.
    const jwt = await new SignJWT({
      scope:
        "https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/datastore",
    })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuedAt(nowSeconds)
      .setExpirationTime(nowSeconds + 3600)
      .setIssuer(serviceAccount.client_email)
      .setSubject(serviceAccount.client_email)
      .setAudience("https://oauth2.googleapis.com/token")
      .sign(privateKey);

    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });
    const tokenData = await tokenResponse.json();
    if (!tokenData.access_token) {
      throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`);
    }
    const accessToken = tokenData.access_token;

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
              body: JSON.stringify({
                message: {
                  token,
                  notification: { title, body },
                  // Data payload lets the RECEIVING device's own app confirm
                  // "I actually received this" by writing delivered status
                  // itself — the accurate signal, since a push only reaches
                  // a device that has real connectivity right now.
                  data: {
                    conversationId: String(conversationId ?? ''),
                    messageId: String(messageId ?? ''),
                  },
                },
              }),
      },
    );
    const fcmResult = await fcmResponse.json();

      return new Response(JSON.stringify(fcmResult), {
        headers: { "Content-Type": "application/json" },
        status: fcmResponse.ok ? 200 : 500,
      });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
    });
  }
});