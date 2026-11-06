import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';

class PostActions extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> postRef;
  final List<String> likes;
  final String channelName;
  final String text;
  final String? imageUrl;
  final String? videoUrl;
  final bool isOwner;
  const PostActions({
    super.key,
    required this.postRef,
    required this.likes,
    required this.channelName,
    required this.text,
    required this.imageUrl,
    required this.videoUrl,
    required this.isOwner,
  });

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> toggleLike(BuildContext context, bool liked) async {
    try {
      await postRef.update({
        'likes': liked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    } catch (e) {
      if (context.mounted) showMsg(context, 'خرابی: $e');
    }
  }

  Future<void> share(BuildContext context) async {
    final parts = <String>['📢 $channelName', if (text.isNotEmpty) text];
    if (imageUrl != null) parts.add(imageUrl!);
    if (videoUrl != null) parts.add(videoUrl!);
    parts.add('— راہگیر چیٹ');
    await Clipboard.setData(ClipboardData(text: parts.join('\n')));
    try {
      await postRef.update({'shares': FieldValue.increment(1)});
    } catch (_) {}
    if (context.mounted) {
      showMsg(context, 'کاپی ہو گیا۔ اب کسی چیٹ میں پیسٹ کر کے بھیج دیں');
    }
  }

  void openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(postRef: postRef, isOwner: isOwner),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String label, Color c, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: c, size: 26),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 17, color: c)),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: postRef.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? {};
        final lk = List<String>.from(d['likes'] ?? likes);
        final liked = lk.contains(uid);
        final cc = ((d['commentCount'] as num?) ?? 0).toInt();
        final sh = ((d['shares'] as num?) ?? 0).toInt();
        return Column(
          children: [
            const Divider(height: 12),
            Row(
              children: [
                btn(
                    liked ? Icons.favorite : Icons.favorite_border,
                    lk.isEmpty ? 'لائک' : 'لائک ${lk.length}',
                    liked ? Colors.red : Colors.black54,
                    () => toggleLike(context, liked)),
                btn(Icons.mode_comment_outlined,
                    cc > 0 ? 'تبصرہ $cc' : 'تبصرہ', Colors.black54,
                    () => openComments(context)),
                btn(Icons.share, sh > 0 ? 'شیئر $sh' : 'شیئر',
                    Colors.black54, () => share(context)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class CommentsSheet extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> postRef;
  final bool isOwner;
  const CommentsSheet({super.key, required this.postRef, required this.isOwner});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final controller = TextEditingController();
  final me = FirebaseAuth.instance.currentUser!;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final t = controller.text.trim();
    if (t.isEmpty) return;
    controller.clear();
    try {
      final u = await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .get();
      await widget.postRef.collection('comments').add({
        'text': t,
        'authorId': me.uid,
        'authorName': (u.data()?['name'] as String?) ?? 'نامعلوم',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await widget.postRef.update({'commentCount': FieldValue.increment(1)});
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
  }

  Future<void> removeComment(
      DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.delete();
      await widget.postRef.update({'commentCount': FieldValue.increment(-1)});
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: h * 0.65,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('تبصرے',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.postRef
                    .collection('comments')
                    .orderBy('createdAt')
                    .limit(100)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('خرابی: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('ابھی کوئی تبصرہ نہیں',
                            style:
                                TextStyle(fontSize: 19, color: Colors.black54)));
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      final canDel = widget.isOwner || d['authorId'] == me.uid;
                      return ListTile(
                        title: Text((d['authorName'] as String?) ?? '',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        subtitle: Text((d['text'] as String?) ?? '',
                            style: const TextStyle(
                                fontSize: 19, color: Colors.black87)),
                        trailing: canDel
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => removeComment(docs[i].reference),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(fontSize: 19),
                      decoration: InputDecoration(
                        hintText: 'تبصرہ لکھیں',
                        filled: true,
                        fillColor: softBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: send,
                    style: IconButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
