import 'package:flutter/material.dart';

class BlockingReasonDialog extends StatefulWidget {
  const BlockingReasonDialog({super.key});

  @override
  State<BlockingReasonDialog> createState() => _BlockingReasonDialogState();
}

class _BlockingReasonDialogState extends State<BlockingReasonDialog> {
  final _reasonController = TextEditingController();

  Future<void> _submit() async {
    // Return the text (even if empty, as it is optional)
    Navigator.of(context).pop(_reasonController.text);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Block Slot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Are you sure you want to block this slot?'),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (Optional)',
              hintText: 'e.g. Maintenance, Cleaning',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // Return null
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Block Slot'),
        ),
      ],
    );
  }
}
