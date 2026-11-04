import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'cloud.dart';
import 'main.dart';
import 'media.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherName;
  const ChatScreen({super.key, required this.chatId, required this.otherName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final me = FirebaseAuth.instance.currentUser!;
  Timer? tick;
  String? markedId;
  bool uploading = false;
  bool recording = false;

  DocumentReference<Map<String, dynamic>> get chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

  String get otherId =>
      widget.chatId.split('_').firstWhere((x) => x != me.uid,
          orElse: () => me.uid);

  @override
  void initState() {
    super.initState();
    tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> markRead() async {
    try {
      await chatRef.update({
        'lastRead.${me.uid}': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    try {
      await chatRef.collection('messages').add({
        'text': text,
        'senderId': me.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await chatRef.update({
        'lastMessage': text,
        'lastSenderId': me.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastRead.${me.uid}': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      showMsg(context, 'خرابی: $e');
    }
  }

  Future<void> sendPhoto() async {
    if (uploading) return;
    setState(() => uploading = true);
    try {
      final url = await pickAndUploadPhoto();
      if (url != null) {
        await chatRef.collection('messages').add({
          'text': '',
          'imageUrl': url,
          'senderId': me.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await chatRef.update({
          'lastMessage': '📷 فوٹو',
          'lastSenderId': me.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastRead.${me.uid}': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
    if (mounted) setState(() => uploading = false);
  }

  Future<void> sendVoice(String path, int secs) async {
    setState(() {
      recording = false;
      uploading = true;
    });
    try {
      final url = await uploadAudio(path);
      if (url != null) {
        await chatRef.collection('messages').add({
          'text': '',
          'audioUrl': url,
          'audioSecs': secs,
          'senderId': me.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await chatRef.update({
          'lastMessage': '🎤 آواز',
          'lastSenderId': me.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastRead.${me.uid}': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
    if (mounted) setState(() => uploading = false);
  }

  String fmt(DateTime t) {
    final l = t.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(otherId)
              .snapshots(),
          builder: (context, s) {
            final status = lastSeenText(s.data?.data());
            return Row(
              children: [
                UserAvatar(uid: otherId, name: widget.otherName, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.otherName,
                          style: const TextStyle(fontSize: 20)),
                      if (status.isNotEmpty)
                        Text(status, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: chatRef.snapshots(),
              builder: (context, chatSnap) {
                final lr =
                    chatSnap.data?.data()?['lastRead'] as Map<String, dynamic>?;
                final otherRead = lr?[otherId] as Timestamp?;
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: chatRef
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .limit(200)
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
                    if (docs.isNotEmpty) {
                      final newest = docs.first;
                      if (newest.data()['senderId'] != me.uid &&
                          newest.id != markedId) {
                        markedId = newest.id;
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => markRead());
                      }
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final m = docs[i].data();
                        final mine = m['senderId'] == me.uid;
                        final ts = m['createdAt'] as Timestamp?;
                        final read = ts != null &&
                            otherRead != null &&
                            otherRead.millisecondsSinceEpoch >=
                                ts.millisecondsSinceEpoch;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: mine
                                  ? const Color(0xFFD6F5E5)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (m['imageUrl'] != null)
                                  ImageBubble(url: m['imageUrl'] as String),
                                if (m['audioUrl'] != null)
                                  VoiceBubble(
                                      url: m['audioUrl'] as String,
                                      secs: ((m['audioSecs'] as num?) ?? 0)
                                          .toInt()),
                                if (((m['text'] as String?) ?? '').isNotEmpty)
                                  Text((m['text'] as String?) ?? '',
                                      style: const TextStyle(fontSize: 20)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (ts != null)
                                      Text(fmt(ts.toDate()),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54)),
                                    if (mine) const SizedBox(width: 4),
                                    if (mine)
                                      Icon(
                                        ts == null
                                            ? Icons.access_time
                                            : (read
                                                ? Icons.done_all
                                                : Icons.done),
                                        size: 16,
                                        color: read
                                            ? Colors.blue
                                            : Colors.black45,
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
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: recording
                  ? RecorderBar(
                      onSend: sendVoice,
                      onCancel: () => setState(() => recording = false))
                  : Row(
                children: [
                  IconButton(
                    onPressed: uploading ? null : sendPhoto,
                    icon: uploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3))
                        : const Icon(Icons.photo, color: green, size: 30),
                  ),
                  IconButton(
                    onPressed:
                        uploading ? null : () => setState(() => recording = true),
                    icon: const Icon(Icons.mic, color: green, size: 32),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        hintText: 'پیغام لکھیں',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28)),
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
          ),
        ],
      ),
    );
  }
}
