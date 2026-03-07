/**
 * GET /api/manager/payments
 *
 * Returns the manager's eSewa payment transactions and due-amount payment logs.
 * Caller must be authenticated as manager (or admin).
 *
 * Response:
 * {
 *   payments: PaymentRecord[],
 *   duePayments: DuePaymentRecord[],
 * }
 */
import { NextRequest, NextResponse } from "next/server";
import { verifyManager } from "../../auth/verify";
import { db } from "../../../lib/firebase-admin";
import type { QueryDocumentSnapshot } from "firebase-admin/firestore";

export async function GET(request: NextRequest) {
  // Verify manager auth
  const authResult = await verifyManager(request);
  if ("error" in authResult) {
    return NextResponse.json(
      { error: authResult.error },
      { status: authResult.status },
    );
  }
  const { uid: managerId, role } = authResult;

  // Admin can query any manager; otherwise self only
  const targetManagerId =
    role === "admin"
      ? (request.nextUrl.searchParams.get("managerId") ?? managerId)
      : managerId;

  // Fetch both collections in parallel
  const [paymentsSnap, duePaymentsSnap] = await Promise.all([
    db
      .collection("payments")
      .where("managerId", "==", targetManagerId)
      .orderBy("createdAt", "desc")
      .limit(200)
      .get(),
    db
      .collection("duePayments")
      .where("managerId", "==", targetManagerId)
      .limit(200)
      .get(),
  ]);

  const payments = paymentsSnap.docs.map((d: QueryDocumentSnapshot) => {
    const data = d.data();
    return {
      id: d.id,
      ...data,
      createdAt: data.createdAt?.toDate?.()?.toISOString() ?? null,
    };
  });

  const duePayments = duePaymentsSnap.docs
    .map((d: QueryDocumentSnapshot) => {
      const data = d.data();
      return {
        id: d.id,
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString() ?? null,
      };
    })
    .sort((a: any, b: any) =>
      (b.createdAt ?? "").localeCompare(a.createdAt ?? ""),
    );

  return NextResponse.json({ payments, duePayments });
}
