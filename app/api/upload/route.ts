import { NextResponse } from "next/server";
import { auth } from "../../lib/firebase-admin";
import { UTApi } from "uploadthing/server";

// Initialize UploadThing server API
const utapi = new UTApi();

// This endpoint handles file uploads from Flutter mobile clients
export async function POST(request: Request) {
    // Verify auth
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const token = authHeader.split("Bearer ")[1];
    try {
        await auth.verifyIdToken(token);
    } catch {
        return NextResponse.json({ error: "Invalid token" }, { status: 401 });
    }

    try {
        const formData = await request.formData();
        const file = formData.get("file") as File;

        if (!file) {
            return NextResponse.json({ error: "No file provided" }, { status: 400 });
        }

        console.log("Uploading file:", file.name, "Size:", file.size, "Type:", file.type);

        // Upload using UploadThing's UTApi
        const response = await utapi.uploadFiles(file);

        console.log("UploadThing response:", response);

        if (response.error) {
            console.error("UploadThing error:", response.error);
            return NextResponse.json({ error: response.error.message || "Upload failed" }, { status: 500 });
        }

        return NextResponse.json({
            ok: true,
            url: response.data.ufsUrl,
            key: response.data.key,
            fileName: response.data.name,
        });

    } catch (error) {
        console.error("Upload error:", error);
        return NextResponse.json({ error: "Upload failed" }, { status: 500 });
    }
}
