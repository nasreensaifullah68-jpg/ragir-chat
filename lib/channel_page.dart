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

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get chRef =>
      FirebaseFirestore.instance.collection('channels').doc(channelId);

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

  Future<void> toggle(BuildContext context, String field, String other,
      List<String> list) async {
    try {
      await chRef.update({
        field: list.contains(uid)
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
        if (other.isNotEmpty) other: FieldValue.arrayRemove([uid]),
      });
    } catch (e) {
      if (context.mounted) showMsg(context, 'خرابی: $e');
    }
  }

  Widget count(IconData icon, int n, String label, Color c) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: c, size: 26),
          Text('$n', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget header(BuildContext context, bool mine, int posts, int photos,
      int videos, bool more) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: chRef.snapshots(),
      builder: (context, s) {
        final d = s.data?.data() ?? {};
        final followers = List<String>.from(d['followers'] ?? []);
        final likes = List<String>.from(d['likes'] ?? []);
        final dislikes = List<String>.from(d['dislikes'] ?? []);
        final following = followers.contains(uid);
        final plus = more ? '+' : '';
        return Container(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (about.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(about, style: const TextStyle(fontSize: 18)),
                ),
              Row(
                children: [
                  const Icon(Icons.group, color: green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${followers.length} فالوور',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  if (!mine)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: following ? Colors.grey : green),
                      onPressed: () =>
                          toggle(context, 'followers', '', followers),
                      icon: Icon(following ? Icons.check : Icons.add),
                      label: Text(following ? 'فالو کر رہے ہیں' : 'فالو کریں',
                          style: const TextStyle(fontSize: 18)),
                    ),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  count(Icons.article, posts, 'پوسٹیں$plus', green),
                  count(Icons.photo, photos, 'تصویریں$plus', Colors.blue),
                  count(Icons.videocam, videos, 'ویڈیوز$plus', Colors.deepOrange),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          toggle(context, 'likes', 'dislikes', likes),
                      icon: Icon(Icons.thumb_up,
                          color: likes.contains(uid) ? green : Colors.black54),
                      label: Text('لائک ${likes.length}',
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          toggle(context, 'dislikes', 'likes', dislikes),
                      icon: Icon(Icons.thumb_down,
                          color:
                              dislikes.contains(uid) ? Colors.red : Colors.black54),
                      label: Text('ڈس لائک ${dislikes.length}',
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget postCard(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc, bool mine) {
    final d = doc.data();
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
                        child: Center(child: Icon(Icons.broken_image))),
                  ),
                ),
              ),
            if (vid != null) VideoPost(url: vid),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(text, style: const TextStyle(fontSize: 20)),
              ),
            PostActions(
              postRef: doc.reference,
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
                  child: Text(timeText(d['createdAt'] as Timestamp?),
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54)),
                ),
                if (mine)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => removePost(context, doc.reference),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = ownerId == uid;
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chRef
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
          final photos =
              docs.where((x) => x.data()['imageUrl'] != null).length;
          final videos =
              docs.where((x) => x.data()['videoUrl'] != null).length;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: docs.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  children: [
                    header(context, mine, docs.length, photos, videos,
                        docs.length >= 100),
                    if (docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                            mine
                                ? 'ابھی کوئی پوسٹ نہیں۔\nنیچے "نئی پوسٹ" دبائیں'
                                : 'ابھی کوئی پوسٹ نہیں',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, color: Colors.black54)),
                      ),
                  ],
                );
              }
              return postCard(context, docs[i - 1], mine);
            },
          );
        },
      ),
    );
  }
}
