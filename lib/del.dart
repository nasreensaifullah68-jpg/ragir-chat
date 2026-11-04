import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'main.dart';

Future<void> deleteMessage(
    BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('پیغام ہٹائیں؟'),
      content: const Text('یہ پیغام دونوں طرف سے ہٹ جائے گا'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('نہیں')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('ہٹائیں'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.delete();
  } catch (e) {
    if (context.mounted) showMsg(context, 'خرابی: $e');
  }
}
