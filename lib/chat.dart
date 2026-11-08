import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'attach.dart';
import 'avatar.dart';
import 'chat_bubble.dart';
import 'call.dart';
import 'camera.dart';
import 'main.dart';
import 'media.dart';
import 'photo.dart';
import 'react.dart';
import 'ui.dart';

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
  bool hasText = false;

  DocumentReference<Map<String, dynamic>> get chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

  String get otherId =>
      widget.chatId.split('_').firstWhere((x) => x != me.uid,
          orElse: () => me.uid);

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      final h = controller.text.trim().isNotEmpty;
      if (h != hasText && mounted) setState(() => hasText = h);
    });
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

  Future<void> run(Future<void> Function() job) async {
    if (uploading) return;
    setState(() => uploading = true);
    try {
      await job();
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
    if (mounted) setState(() => uploading = false);
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    try {
      await postMsg(chatRef, me.uid, {'text': text}, text);
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
  }

  Future<void> sendPhoto(ImageSource source) async {
    if (uploading) return;
    final mode = await choosePhotoMode(context);
    if (mode == null) return;
    await run(() async {
      final url = await pickAndUploadFrom(source);
      if (url != null) {
        await postMsg(chatRef, me.uid,
            {'imageUrl': url, 'photoMode': mode}, '📷 فوٹو');
      }
    });
  }

  Future<void> sendVoice(String path, int secs) async {
    setState(() => recording = false);
    await run(() async {
      final url = await uploadAudio(path);
      if (url != null) {
        await postMsg(chatRef, me.uid,
            {'audioUrl': url, 'audioSecs': secs}, '🎤 آواز');
      }
    });
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
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'ویڈیو کال',
            icon: const Icon(Icons.videocam, size: 28),
            onPressed: () => soon(context),
          ),
          IconButton(
            tooltip: 'کال کریں',
            icon: const Icon(Icons.call, size: 26),
            onPressed: () =>
                CallService.instance.startCall(otherId, widget.otherName),
          ),
          IconButton(
            tooltip: 'مزید',
            icon: const Icon(Icons.more_vert),
            onPressed: () => soon(context),
          ),
        ],
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
                        return GestureDetector(
                          onLongPress: () => showReactSheet(context,
                              ref: docs[i].reference,
                              mine: mine,
                              text: m['text'] as String?,
                              current: (m['reactions']
                                  as Map<String, dynamic>?)?[me.uid] as String?),
                          child: Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: MsgBubble(
                              m: m,
                              mine: mine,
                              read: read,
                              ref: docs[i].reference),
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
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x1A000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1)),
                              ],
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => soon(context),
                                  icon: const Icon(Icons.emoji_emotions_outlined,
                                      color: Colors.black45, size: 26),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    minLines: 1,
                                    maxLines: 4,
                                    style: const TextStyle(fontSize: 20),
                                    decoration: const InputDecoration(
                                      hintText: 'پیغام لکھیں',
                                      border: InputBorder.none,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: uploading
                                      ? null
                                      : () => run(() => sendAttachment(
                                          context, chatRef, me.uid)),
                                  icon: const Icon(Icons.attach_file,
                                      color: green, size: 26),
                                ),
                                IconButton(
                                  onPressed: uploading
                                      ? null
                                      : () => sendPhoto(ImageSource.gallery),
                                  icon: uploading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 3))
                                      : const Icon(Icons.photo,
                                          color: green, size: 26),
                                ),
                                IconButton(
                                  onPressed: uploading
                                      ? null
                                      : () => sendPhoto(ImageSource.camera),
                                  icon: const Icon(Icons.photo_camera,
                                      color: green, size: 26),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 27,
                          backgroundColor: green,
                          child: IconButton(
                            color: Colors.white,
                            onPressed: hasText
                                ? send
                                : (uploading
                                    ? null
                                    : () => setState(() => recording = true)),
                            icon: Icon(hasText ? Icons.send : Icons.mic,
                                size: 28),
                          ),
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
