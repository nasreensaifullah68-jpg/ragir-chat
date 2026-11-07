import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'del.dart';
import 'main.dart';
import 'tts.dart';

const quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

Future<void> setReaction(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String? emoji) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  try {
    await ref.update({
      'reactions.$uid': emoji ?? FieldValue.delete(),
    });
  } catch (e) {
    if (context.mounted) showMsg(context, 'خرابی: $e');
  }
}

Future<void> customEmoji(
    BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
  final c = TextEditingController();
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('اپنی مرضی کی اِموجی'),
      content: TextField(
        controller: c,
        autofocus: true,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 34),
        decoration: const InputDecoration(
            hintText: '😀', helperText: 'کی بورڈ سے اِموجی چنیں'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('منسوخ')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: green),
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('لگائیں'),
        ),
      ],
    ),
  );
  if (v == null || v.isEmpty || v.length > 12) return;
  if (context.mounted) await setReaction(context, ref, v);
}

Future<void> showReactSheet(
  BuildContext context, {
  required DocumentReference<Map<String, dynamic>> ref,
  required bool mine,
  required String? current,
  String? text,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in quickEmojis)
                InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    Navigator.pop(ctx);
                    setReaction(context, ref, current == e ? null : e);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: current == e ? const Color(0xFFD6F5E5) : null,
                      shape: BoxShape.circle,
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 34)),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.pop(ctx);
                  customEmoji(context, ref);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.black12, shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 34),
                ),
              ),
            ],
          ),
          if (current != null)
            ListTile(
              leading: const Icon(Icons.close, color: Colors.black54),
              title: const Text('اپنی اِموجی ہٹائیں',
                  style: TextStyle(fontSize: 19)),
              onTap: () {
                Navigator.pop(ctx);
                setReaction(context, ref, null);
              },
            ),
          if (text != null && text.trim().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.volume_up, color: green),
              title: const Text('سنیں', style: TextStyle(fontSize: 19)),
              onTap: () {
                Navigator.pop(ctx);
                speakText(context, text);
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('پیغام مٹائیں',
                  style: TextStyle(fontSize: 19, color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                deleteMessage(context, ref);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class ReactionRow extends StatelessWidget {
  final Map<String, dynamic> reactions;
  const ReactionRow({super.key, required this.reactions});

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final v in reactions.values) {
      final e = v.toString();
      counts[e] = (counts[e] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: [
          for (final en in counts.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(14)),
              child: Text(
                  en.value > 1 ? '${en.key} ${en.value}' : en.key,
                  style: const TextStyle(fontSize: 17)),
            ),
        ],
      ),
    );
  }
}
