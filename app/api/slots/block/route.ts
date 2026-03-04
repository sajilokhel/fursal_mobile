import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { verifyManager } from "../../auth/verify";
import { db } from "../../../lib/firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";

const blockSlotSchema = z.object({
    venueId: z.string().min(1),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Date must be YYYY-MM-DD format"),
    startTime: z.string().regex(/^\d{2}:\d{2}$/, "Time must be HH:MM format"),
    reason: z.string().optional(),
});

export async function POST(request: NextRequest) {
    try {
        // Verify manager auth
        const authResult = await verifyManager(request);
        if ("error" in authResult) {
            return NextResponse.json(
                { error: authResult.error },
                { status: authResult.status }
            );
        }

        const { uid } = authResult;

        // Parse and validate body
        const body = await request.json();
        const parseResult = blockSlotSchema.safeParse(body);
        if (!parseResult.success) {
            return NextResponse.json(
                { error: "Validation failed", details: parseResult.error.errors },
                { status: 400 }
            );
        }

        const { venueId, date, startTime, reason } = parseResult.data;

        // Verify manager owns this venue
        const venueDoc = await db.collection("venues").doc(venueId).get();
        if (!venueDoc.exists) {
            return NextResponse.json({ error: "Venue not found" }, { status: 404 });
        }

        const venueData = venueDoc.data();
        if (venueData?.managedBy !== uid) {
            return NextResponse.json(
                { error: "You don't manage this venue" },
                { status: 403 }
            );
        }

        // Create blocked slot entry
        const blockedSlot = {
            date,
            startTime,
            reason: reason || null,
            blockedBy: uid,
            blockedAt: Timestamp.now(),
        };

        // Add to venueSlots.blocked array
        const venueSlotsRef = db.collection("venueSlots").doc(venueId);
        await venueSlotsRef.set(
            {
                blocked: FieldValue.arrayUnion(blockedSlot),
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        console.log(`Slot blocked: ${venueId} ${date} ${startTime} by ${uid}`);

        return NextResponse.json({
            success: true,
            message: "Slot blocked successfully",
            blockedSlot,
        });
    } catch (error) {
        console.error("Block slot error:", error);
        return NextResponse.json(
            { error: "Internal server error" },
            { status: 500 }
        );
    }
}
