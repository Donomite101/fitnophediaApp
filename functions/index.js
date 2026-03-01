const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggered whenever a document is created in the 'push_notifications' collection.
 * This is the CENTRAL server-side logic for all notifications.
 */
exports.sendPushNotificationTrigger = functions.firestore
    .document("push_notifications/{docId}")
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();

        // Required data check
        if (!data.token || !data.title || !data.body) {
            console.log("❌ Missing required push notification fields.");
            return null;
        }

        const message = {
            notification: {
                title: data.title,
                body: data.body,
            },
            data: data.data || {},
            token: data.token,
            android: {
                priority: "high",
                notification: {
                    channelId: "high_importance_channel",
                },
            },
            apns: {
                payload: {
                    aps: {
                        contentAvailable: true,
                        sound: "default",
                    },
                },
            },
        };

        try {
            const response = await admin.messaging().send(message);
            console.log("✅ Successfully sent message:", response);

            // Optional: Update document status as 'sent'
            return snapshot.ref.update({
                status: "sent",
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                messageId: response,
            });
        } catch (error) {
            console.error("❌ Error sending push notification:", error);
            return snapshot.ref.update({
                status: "failed",
                error: error.message,
            });
        }
    });

/**
 * HTTPS Callable function for direct notification sends from the app.
 * Accessible via Firebase Functions SDK.
 */
exports.sendDirectNotification = functions.https.onCall(async (data, context) => {
    // Simple auth check
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Only authenticated users can send notifications.",
        );
    }

    const { token, title, body, extraData } = data;

    if (!token || !title || !body) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Required: token, title, body.",
        );
    }

    const message = {
        notification: { title, body },
        data: extraData || {},
        token: token,
    };

    try {
        const response = await admin.messaging().send(message);
        return { success: true, messageId: response };
    } catch (error) {
        throw new functions.https.HttpsError("internal", error.message);
    }
});
