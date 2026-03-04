import { createUploadthing, type FileRouter } from "uploadthing/next";
import { auth as firebaseAdminAuth } from "../../lib/firebase-admin";

const f = createUploadthing();

const verifyAuth = async (req: Request) => {
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
        console.warn("UploadThing: No authorization header found");
        return null;
    }

    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : null;

    if (!idToken) {
        console.warn("UploadThing: Invalid bearer token format");
        return null;
    }

    try {
        const decoded = await firebaseAdminAuth.verifyIdToken(idToken);
        console.log("UploadThing: Token verified for user", decoded.uid);
        return { id: decoded.uid, email: decoded.email };
    } catch (err) {
        console.error("UploadThing: Failed to verify ID token", err);
        return null;
    }
};

export const ourFileRouter = {
    imageUploader: f({ image: { maxFileSize: "4MB", maxFileCount: 5 } })
        .middleware(async ({ req }) => {
            const user = await verifyAuth(req);
            if (!user) throw new Error("Unauthorized");
            return { userId: user.id };
        })
        .onUploadComplete(async ({ metadata, file }) => {
            console.log("Upload complete for userId:", metadata.userId);
            console.log("File URL:", file.url);
            return { uploadedBy: metadata.userId, url: file.url };
        }),
} satisfies FileRouter;

export type OurFileRouter = typeof ourFileRouter;
