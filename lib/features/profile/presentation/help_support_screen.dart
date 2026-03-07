import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'question': 'How do I book a venue?',
      'answer':
          'Browse venues from the Venues tab, select a venue, choose your preferred time slot, and confirm your booking. You will receive a confirmation notification.',
    },
    {
      'question': 'How do I cancel a booking?',
      'answer':
          'Go to the Bookings tab, find the booking you want to cancel, and tap the Cancel button. Cancellations made 24 hours before the booking are fully refundable.',
    },
    {
      'question': 'How are payments processed?',
      'answer':
          'Payments are securely processed via eSewa. You will be redirected to eSewa to complete your payment during the booking process.',
    },
    {
      'question': 'Can I reschedule a booking?',
      'answer':
          'To reschedule, cancel your existing booking and create a new one. Rescheduling directly will be supported in a future update.',
    },
    {
      'question': 'How do I list my venue?',
      'answer':
          'Apply as a venue manager through the app. Once approved, you can list your venues and manage bookings from the Manager dashboard.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact cards
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: Icons.email_outlined,
                  label: 'Email Us',
                  value: 'contact@sajilokhel.com',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Mail us at contact@sajilokhel.com')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 24),

          // FAQ section
          Text(
            'FREQUENTLY ASKED QUESTIONS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          ..._faqs.map((faq) => _FaqTile(
                question: faq['question']!,
                answer: faq['answer']!,
              )),
          const SizedBox(height: 24),

          // Report a problem
          const SizedBox(height: 12),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
                color: Colors.grey[700], fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
