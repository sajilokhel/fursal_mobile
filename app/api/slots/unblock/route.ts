import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { verifyManager } from "../../auth/verify";
import { db } from "../../../lib/firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

const unblockSlotSchema = z.object({
    venueId: z.string().min(1),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Date must be YYYY-MM-DD format"),
    startTime: z.string().regex(/^\d{2}:\d{2}$/, "Time must be HH:MM format"),
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
        const parseResult = unblockSlotSchema.safeParse(body);
        if (!parseResult.success) {
            return NextResponse.json(
                { error: "Validation failed", details: parseResult.error.errors },
                { status: 400 }
            );
        }

        const { venueId, date, startTime } = parseResult.data;

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

        // Use transaction to find and remove the blocked slot
        const venueSlotsRef = db.collection("venueSlots").doc(venueId);

        await db.runTransaction(async (transaction) => {
            const slotsDoc = await transaction.get(venueSlotsRef);

            if (!slotsDoc.exists) {
                throw new Error("No slot data found for this venue");
            }

            const data = slotsDoc.data();
            const blockedSlots = data?.blocked || [];

            // Find the matching blocked slot
            const matchingSlot = blockedSlots.find(
                (slot: { date: string; startTime: string }) =>
                    slot.date === date && slot.startTime === startTime
            );

            if (!matchingSlot) {
                throw new Error("Slot is not currently blocked");
            }

            // Remove the blocked slot
            transaction.update(venueSlotsRef, {
                blocked: FieldValue.arrayRemove(matchingSlot),
                updatedAt: FieldValue.serverTimestamp(),
            });
        });

        console.log(`Slot unblocked: ${venueId} ${date} ${startTime} by ${uid}`);

        return NextResponse.json({
            success: true,
            message: "Slot unblocked successfully",
        });
    } catch (error) {
        console.error("Unblock slot error:", error);
        const errorMessage = error instanceof Error ? error.message : "Internal server error";
        return NextResponse.json(
            { error: errorMessage },
            { status: errorMessage.includes("not") ? 400 : 500 }
        );
    }
}
