import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { verifyManager } from "../../auth/verify";
import { db } from "../../../lib/firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";

const physicalBookingSchema = z.object({
    venueId: z.string().min(1),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Date must be YYYY-MM-DD format"),
    startTime: z.string().regex(/^\d{2}:\d{2}$/, "Time must be HH:MM format"),
    endTime: z.string().regex(/^\d{2}:\d{2}$/, "Time must be HH:MM format"),
    customerName: z.string().min(1),
    customerPhone: z.string().optional(),
    notes: z.string().optional(),
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
        const parseResult = physicalBookingSchema.safeParse(body);
        if (!parseResult.success) {
            return NextResponse.json(
                { error: "Validation failed", details: parseResult.error.errors },
                { status: 400 }
            );
        }

        const { venueId, date, startTime, endTime, customerName, customerPhone, notes } = parseResult.data;

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

        // Generate booking ID
        const bookingId = db.collection("bookings").doc().id;
        const now = Timestamp.now();

        // Run transaction to check slot availability and create booking
        const venueSlotsRef = db.collection("venueSlots").doc(venueId);
        const bookingRef = db.collection("bookings").doc(bookingId);

        await db.runTransaction(async (transaction) => {
            const slotsDoc = await transaction.get(venueSlotsRef);
            const data = slotsDoc.exists ? slotsDoc.data() : {};

            const blockedSlots = data?.blocked || [];
            const bookedSlots = data?.bookings || [];
            const heldSlots = data?.held || [];

            // Check if slot is blocked
            const isBlocked = blockedSlots.some(
                (slot: { date: string; startTime: string }) =>
                    slot.date === date && slot.startTime === startTime
            );
            if (isBlocked) {
                throw new Error("This slot is blocked");
            }

            // Check if slot is already booked
            const isBooked = bookedSlots.some(
                (slot: { date: string; startTime: string; status?: string }) =>
                    slot.date === date && slot.startTime === startTime && slot.status !== "cancelled"
            );
            if (isBooked) {
                throw new Error("This slot is already booked");
            }

            // Remove any expired holds for this slot
            const activeHolds = heldSlots.filter(
                (hold: { date: string; startTime: string; holdExpiresAt: Timestamp }) => {
                    if (hold.date === date && hold.startTime === startTime) {
                        return hold.holdExpiresAt.toDate() > now.toDate();
                    }
                    return true;
                }
            );

            // Create booked slot entry for venueSlots
            const bookedSlot = {
                date,
                startTime,
                bookingId,
                bookingType: "physical",
                status: "confirmed",
                createdAt: now,
                userId: uid,
                customerName,
                customerPhone: customerPhone || null,
                notes: notes || null,
            };

            // Create full booking document
            const bookingDoc = {
                id: bookingId,
                venueId,
                venueName: venueData?.name || "",
                userId: uid,
                userName: customerName,
                userPhone: customerPhone || null,
                date,
                startTime,
                endTime,
                bookingType: "physical",
                status: "confirmed",
                paymentStatus: "full",
                amount: 0, // Physical bookings typically paid on-site
                createdAt: now,
                notes: notes || null,
            };

            // Update venueSlots
            transaction.set(
                venueSlotsRef,
                {
                    bookings: FieldValue.arrayUnion(bookedSlot),
                    held: activeHolds, // Replace with filtered holds
                    updatedAt: FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            // Create booking document
            transaction.set(bookingRef, bookingDoc);
        });

        console.log(`Physical booking created: ${bookingId} for ${venueId} ${date} ${startTime}`);

        return NextResponse.json({
            success: true,
            message: "Physical booking created successfully",
            bookingId,
        });
    } catch (error) {
        console.error("Physical booking error:", error);
        const errorMessage = error instanceof Error ? error.message : "Internal server error";
        const isClientError = errorMessage.includes("blocked") || errorMessage.includes("booked");
        return NextResponse.json(
            { error: errorMessage },
            { status: isClientError ? 400 : 500 }
        );
    }
}
