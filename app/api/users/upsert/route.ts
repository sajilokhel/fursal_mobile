import { NextResponse } from "next/server";
import { db } from "../../../lib/firebase-admin";
import { verifyAuth } from "../../auth/verify";
import { z } from "zod";

// Schema for validation
const userUpsertSchema = z.object({
    uid: z.string(),
    displayName: z.string().optional(),
    email: z.string().email().optional(),
    photoURL: z.string().optional(),
    role: z.string().optional(),
});

export async function POST(request: Request) {
    // 1. Verify Authentication
    const authResult = await verifyAuth(request);
    if ('error' in authResult) {
        return NextResponse.json({ error: authResult.error }, { status: authResult.status });
    }

    const { uid: callerUid } = authResult;

    try {
        // 2. Parse & Validate Body
        const body = await request.json();
        const validatedData = userUpsertSchema.parse(body);

        // 3. Authorization Check
        // User can upsert themselves. Admin can upsert anyone.
        // If trying to set 'role', must be admin.

        // Check if caller is admin effectively if they are trying to set role or update another user
        let isAdmin = false; // default
        if (callerUid !== validatedData.uid || validatedData.role) {
            const callerDoc = await db.collection("users").doc(callerUid).get();
            const callerData = callerDoc.data();
            if (callerData?.role === 'admin') {
                isAdmin = true;
            }
        }

        if (callerUid !== validatedData.uid && !isAdmin) {
            return NextResponse.json({ error: "Forbidden: Cannot update other users" }, { status: 403 });
        }

        if (validatedData.role && !isAdmin) {
            return NextResponse.json({ error: "Forbidden: Only admin can set roles" }, { status: 403 });
        }

        // 4. Upsert User
        // We use set with merge: true to avoid overwriting existing fields like createdAt if we didn't pass them
        // But we might want 'createdAt' on creation.

        const userRef = db.collection("users").doc(validatedData.uid);
        // clean undefineds (zod optional returns undefined usually, but careful with JSON)
        // Firestore ignores undefined in node usually or throws, safer to strip
        const dataToUpdate = JSON.parse(JSON.stringify({
            ...validatedData,
            updatedAt: new Date()
        }));

        // Check if exists to add createdAt
        const docSnap = await userRef.get();
        if (!docSnap.exists) {
            dataToUpdate.createdAt = new Date();
            // Default role if not provided? Maybe handle in code or let it be null.
            if (!dataToUpdate.role) {
                dataToUpdate.role = 'user';
            }
        }

        await userRef.set(dataToUpdate, { merge: true });

        return NextResponse.json({ ok: true, uid: validatedData.uid });

    } catch (error) {
        if (error instanceof z.ZodError) {
            return NextResponse.json({ error: "Validation failed", details: error.flatten() }, { status: 400 });
        }
        console.error("User upsert error:", error);
        return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
    }
}
