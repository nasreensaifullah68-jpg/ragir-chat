import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';

const statusColors = [
  Color(0xFF0F8A5F),
  Color(0xFF1E6FD9),
  Color(0xFF8E44AD),
  Color(0xFFD35400),
  Color(0xFFC0392B),
];

class StatusScreen extends StatelessWidget {
  final String name;
  const StatusScreen({super.key, required this.name});

  Future<void> addStatus(BuildContext context) async {
    final me = FirebaseAuth.instance.currentUser!;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نیا اسٹیٹس'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 200,
          style: const TextStyle(fontSize: 22),
          decoration: const InputDecoration(hintText: 'اپنا اسٹیٹس لکھیں'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('منسوخ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: green),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('لگائیں'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('statuses').add({
        'authorId': me.uid,
        'authorName': name,
        'text': text.trim(),
        'color': DateTime.now().millisecond % statusColors.length,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!context.mounted) return;
      showMsg(context, 'خرابی: $e');
    }
  }

  String timeText(DateTime t) {
    final l = t.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final same = l.year == now.year && l.month == now.month && l.day == now.day;
    return same ? 'آج $h:$m' : 'کل $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final since = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: const Text('اسٹیٹس'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: green,
        foregroundColor: Colors.white,
        onPressed: () => addStatus(context),
        icon: const Icon(Icons.add),
        label: const Text('اسٹیٹس لگائیں', style: TextStyle(fontSize: 20)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('statuses')
            .where('createdAt', isGreaterThan: since)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('خرابی: ${snap.error}'),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('ابھی کوئی اسٹیٹس نہیں۔\nنیچے "اسٹیٹس لگائیں" دبائیں',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final mine = d['authorId'] == myId;
              final ts = d['createdAt'] as Timestamp?;
              final ci = ((d['color'] as num?) ?? 0).toInt() %
                  statusColors.length;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: statusColors[ci],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mine ? 'آپ' : ((d['authorName'] as String?) ?? ''),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (ts != null)
                          Text(timeText(ts.toDate()),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        if (mine)
                          IconButton(
                            tooltip: 'ہٹائیں',
                            icon: const Icon(Icons.delete,
                                color: Colors.white),
                            onPressed: () => docs[i].reference.delete(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text((d['text'] as String?) ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 26)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
