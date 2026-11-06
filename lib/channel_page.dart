import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'new_post.dart';
import 'post_actions.dart';
import 'photo.dart';
import 'vid.dart';

class ChannelPage extends StatelessWidget {
  final String channelId;
  final String name;
  final String about;
  final String ownerId;
  final String ownerName;
  const ChannelPage({
    super.key,
    required this.channelId,
    required this.name,
    required this.about,
    required this.ownerId,
    required this.ownerName,
  });

  String timeText(Timestamp? ts) {
    if (ts == null) return '';
    final l = ts.toDate().toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    return '${l.day}/${l.month} $h:$m';
  }

  Future<void> removePost(
      BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پوسٹ ہٹائیں؟'),
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

  @override
  Widget build(BuildContext context) {
    final mine = ownerId == (FirebaseAuth.instance.currentUser?.uid ?? '');
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 21)),
            Text(ownerName, style: const TextStyle(fontSize: 13)),
          ],
        ),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: mine
          ? FloatingActionButton.extended(
              backgroundColor: green,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NewPostScreen(channelId: channelId))),
              icon: const Icon(Icons.edit),
              label: const Text('نئی پوسٹ', style: TextStyle(fontSize: 20)),
            )
          : null,
      body: Column(
        children: [
          if (about.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(14),
              child: Text(about, style: const TextStyle(fontSize: 18)),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('channels')
                  .doc(channelId)
                  .collection('posts')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          mine
                              ? 'ابھی کوئی پوسٹ نہیں۔\nنیچے "نئی پوسٹ" دبائیں'
                              : 'ابھی کوئی پوسٹ نہیں',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22, color: Colors.black54)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100, top: 6),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final text = (d['text'] as String?) ?? '';
                    final img = d['imageUrl'] as String?;
                    final vid = d['videoUrl'] as String?;
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (img != null)
                              GestureDetector(
                                onTap: () => showPhoto(context, img, true),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    img,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, st) => const SizedBox(
                                        height: 80,
                                        child: Center(
                                            child: Icon(Icons.broken_image))),
                                  ),
                                ),
                              ),
                            if (vid != null) VideoPost(url: vid),
                            if (text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(text,
                                    style: const TextStyle(fontSize: 20)),
                              ),
                            PostActions(
                              postRef: docs[i].reference,
                              likes: List<String>.from(d['likes'] ?? []),
                              channelName: name,
                              text: text,
                              imageUrl: img,
                              videoUrl: vid,
                              isOwner: mine,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      timeText(d['createdAt'] as Timestamp?),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54)),
                                ),
                                if (mine)
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        removePost(context, docs[i].reference),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
