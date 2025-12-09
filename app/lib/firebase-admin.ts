import "server-only";
import { getApps, initializeApp, cert, getApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

// Check if we are in a serverless environment and need to initialize
// Note: In Next.js, this might run multiple times in dev, so check getApps()
function initAdmin() {
    if (getApps().length === 0) {
        if (process.env.FIREBASE_PRIVATE_KEY && process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL) {
            const privateKey = process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n");
            return initializeApp({
                credential: cert({
                    projectId: process.env.FIREBASE_PROJECT_ID,
                    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
                    privateKey: privateKey,
                }),
            });
        } else {
            // Fallback or local emulator support could go here if needed
            console.warn("FIREBASE credentials not set. Backend will not function correctly without them.");
            if (getApps().length === 0) {
                // Initialize with no-op for build to pass if possible, or just don't init
                // But if we don't init, getAuth() calls might fail.
                // Better to return 0 apps and handle it or let it fail at runtime.
                // However, for build, we might just want to skip.
                return initializeApp({ projectId: "demo-project" }); // Mock for build
            }
            return getApp();
        }
    }
    return getApp();
}

export const app = initAdmin();
export const db = getFirestore(app);
export const auth = getAuth(app);
