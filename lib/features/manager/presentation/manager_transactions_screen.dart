import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_repository.dart';
import '../data/manager_payments_provider.dart';
import '../domain/manager_payment_data.dart';

class ManagerTransactionsScreen extends ConsumerStatefulWidget {
  const ManagerTransactionsScreen({super.key});

  @override
  ConsumerState<ManagerTransactionsScreen> createState() =>
      _ManagerTransactionsScreenState();
}

class _ManagerTransactionsScreenState
    extends ConsumerState<ManagerTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final dataAsync = ref.watch(managerPaymentsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Transactions',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(managerPaymentsProvider(userId)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'eSewa Payments'),
            Tab(text: 'Due Collected'),
          ],
        ),
      ),
      body: dataAsync.when(
        data: (data) => Column(
          children: [
            // ── Search bar ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by customer, venue, amount…',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),

            // ── Tabs ────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _PaymentsTab(
                      records: data.payments, search: _search),
                  _DueCollectedTab(
                      records: data.duePayments, search: _search),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(managerPaymentsProvider(userId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── eSewa payments tab ────────────────────────────────────────────────────────

class _PaymentsTab extends StatelessWidget {
  final List<PaymentRecord> records;
  final String search;
  const _PaymentsTab({required this.records, required this.search});

  @override
  Widget build(BuildContext context) {
    final filtered = search.isEmpty
        ? records
        : records.where((r) {
            final q = search.toLowerCase();
            return r.userName.toLowerCase().contains(q) ||
                r.venueName.toLowerCase().contains(q) ||
                r.amount.toString().contains(q) ||
                r.bookingId.toLowerCase().contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return _emptyState(
          'No eSewa transactions found', Icons.payment_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _PaymentCard(record: filtered[i]),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentRecord record;
  const _PaymentCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmtDate(record.createdAt);
    final status = record.status.toUpperCase();
    final isSuccess = record.status.toLowerCase() == 'complete' ||
        record.status.toLowerCase() == 'success' ||
        record.status.toLowerCase() == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green.shade50 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payment,
                color: isSuccess ? Colors.green.shade600 : Colors.grey,
                size: 22),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.venueName.isNotEmpty ? record.venueName : 'Payment',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  record.userName.isNotEmpty
                      ? record.userName
                      : 'ID: ${record.bookingId.length > 8 ? record.bookingId.substring(0, 8) : record.bookingId}…',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(dateStr,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),

          // Amount + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${record.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.isNotEmpty ? status : 'UNKNOWN',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSuccess
                          ? Colors.green.shade700
                          : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Due collected tab ─────────────────────────────────────────────────────────

class _DueCollectedTab extends StatelessWidget {
  final List<DuePaymentRecord> records;
  final String search;
  const _DueCollectedTab({required this.records, required this.search});

  @override
  Widget build(BuildContext context) {
    final filtered = search.isEmpty
        ? records
        : records.where((r) {
            final q = search.toLowerCase();
            return r.userName.toLowerCase().contains(q) ||
                r.venueName.toLowerCase().contains(q) ||
                r.amount.toString().contains(q) ||
                r.bookingId.toLowerCase().contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return _emptyState(
          'No collected dues yet', Icons.account_balance_wallet_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _DueCollectedCard(record: filtered[i]),
    );
  }
}

class _DueCollectedCard extends StatelessWidget {
  final DuePaymentRecord record;
  const _DueCollectedCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmtDate(record.createdAt);
    final isCash = record.paymentMethod.toLowerCase() == 'cash';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: Colors.green.shade400),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCash
                              ? Icons.payments_outlined
                              : Icons.phone_android,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.venueName.isNotEmpty
                                  ? record.venueName
                                  : 'Due Payment',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              record.userName.isNotEmpty
                                  ? record.userName
                                  : 'Unknown customer',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 11,
                                    color: Colors.grey.shade400),
                                const SizedBox(width: 3),
                                Text(
                                  record.bookingDate.isNotEmpty
                                      ? '${record.bookingDate}  ${record.bookingStartTime}–${record.bookingEndTime}'
                                      : dateStr,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Amount + method
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${record.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.green.shade700),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCash
                                  ? Colors.teal.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isCash ? 'CASH' : 'ONLINE',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCash
                                      ? Colors.teal.shade700
                                      : Colors.blue.shade700),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    return DateFormat('MMM d, y · HH:mm').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

Widget _emptyState(String msg, IconData icon) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(msg,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      ],
    ),
  );
}
