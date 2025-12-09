import { auth, db } from "../../lib/firebase-admin";

export async function verifyAuth(request: Request) {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
        return { error: "Missing or invalid Authorization header", status: 401 };
    }

    const token = authHeader.split("Bearer ")[1];
    try {
        const decodedToken = await auth.verifyIdToken(token);
        return { uid: decodedToken.uid, token: decodedToken };
    } catch (error) {
        console.error("Token verification failed:", error);
        return { error: "Invalid token", status: 401 };
    }
}

export async function verifyManager(request: Request) {
    const authResult = await verifyAuth(request);
    if ('error' in authResult) return authResult;

    const { uid } = authResult;

    // Check user role
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
        return { error: "User not found", status: 404 };
    }

    const userData = userDoc.data();
    // Allow 'admin' or 'manager' roles
    if (userData?.role !== "manager" && userData?.role !== "admin") {
        return { error: "Forbidden: Manager access required", status: 403 };
    }

    // Return user info if successful
    return { uid, role: userData.role };
}
