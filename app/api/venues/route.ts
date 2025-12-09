import { NextResponse } from "next/server";
import { db } from "../../lib/firebase-admin";
import { verifyManager } from "../auth/verify";
import { z } from "zod";

// Schema for validation - matches Flutter Venue.toMap() output
const venueSchema = z.object({
    id: z.string().optional(), // Allow ID for updates
    name: z.string().min(1),
    description: z.string().nullable().optional(),
    latitude: z.number(),
    longitude: z.number(),
    address: z.string().nullable().optional(),
    imageUrls: z.array(z.string()).optional(),
    pricePerHour: z.number(),
    attributes: z.record(z.string(), z.string()).optional(),
    createdAt: z.string().optional(),
    managedBy: z.string().optional(),
    averageRating: z.number().optional(),
    reviewCount: z.number().optional(),
});

export async function POST(request: Request) {
    // 1. Verify Authentication & Role
    const authResult = await verifyManager(request);
    if ('error' in authResult) {
        return NextResponse.json({ error: authResult.error }, { status: authResult.status });
    }

    const { uid } = authResult;

    try {
        // 2. Parse & Validate Body
        const body = await request.json();
        const validatedData = venueSchema.parse(body);
        const { id, ...venueData } = validatedData;

        let venueId;

        if (id) {
            // Update existing venue by ID
            const docRef = db.collection("venues").doc(id);
            const doc = await docRef.get();

            if (!doc.exists) {
                return NextResponse.json({ error: "Venue not found" }, { status: 404 });
            }

            // Verify manager owns this venue
            const existingData = doc.data();
            if (existingData?.managedBy !== uid) {
                return NextResponse.json({ error: "Forbidden: You do not manage this venue" }, { status: 403 });
            }

            await docRef.update({
                ...venueData,
                updatedAt: new Date(),
            });
            venueId = id;
        } else {
            // Check if manager already has a venue (for new creation)
            const venuesSnapshot = await db.collection("venues").where("managedBy", "==", uid).limit(1).get();

            if (!venuesSnapshot.empty) {
                // Update existing
                const doc = venuesSnapshot.docs[0];
                venueId = doc.id;
                await doc.ref.update({
                    ...venueData,
                    updatedAt: new Date(),
                });
            } else {
                // Create new
                const docRef = await db.collection("venues").add({
                    ...venueData,
                    managedBy: uid,
                    createdAt: new Date(),
                    updatedAt: new Date(),
                });
                venueId = docRef.id;
            }
        }

        return NextResponse.json({ ok: true, venueId });

    } catch (error) {
        if (error instanceof z.ZodError) {
            return NextResponse.json({ error: "Validation failed", details: error.flatten() }, { status: 400 });
        }
        console.error("Venue upsert error:", error);
        return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
    }
}
