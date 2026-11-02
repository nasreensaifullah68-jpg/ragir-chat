import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';

String lastSeenText(Map<String, dynamic>? u) {
  if (u == null) return '';
  final ts = u['lastSeen'] as Timestamp?;
  if (ts == null) return '';
  final t = ts.toDate();
  final now = DateTime.now();
  if (u['online'] == true && now.difference(t).inSeconds.abs() < 100) {
    return 'آن لائن';
  }
  final l = t.toLocal();
  final h = l.hour.toString().padLeft(2, '0');
  final m = l.minute.toString().padLeft(2, '0');
  final same = l.year == now.year && l.month == now.month && l.day == now.day;
  return same ? 'آخری بار آج $h:$m' : 'آخری بار ${l.day}/${l.month} $h:$m';
}

class HomeScreen extends StatefulWidget {
  final String name;
  const HomeScreen({super.key, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? timer;

  Future<void> setOnline(bool on) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'online': on,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 40), (_) => setOnline(true));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setOnline(true);
    startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setOnline(true);
      startTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      timer?.cancel();
      setOnline(false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String normalize(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('92')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '+92$digits';
  }

  Future<void> startChat(BuildContext context) async {
    final me = FirebaseAuth.instance.currentUser!;
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نئی چیٹ'),
        content: Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            style: const TextStyle(fontSize: 22),
            decoration: const InputDecoration(
                prefixText: '+92 ', hintText: '3XX XXXXXXX'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('منسوخ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: green),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('شروع کریں'),
          ),
        ],
      ),
    );
    if (input == null || input.trim().isEmpty) return;
    final phone = normalize(input);
    try {
      final found = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (!context.mounted) return;
      if (found.docs.isEmpty) {
        showMsg(context, 'یہ نمبر رَاگیر چیٹ پر نہیں ملا');
        return;
      }
      final other = found.docs.first;
      if (other.id == me.uid) {
        showMsg(context, 'یہ آپ کا اپنا نمبر ہے');
        return;
      }
      final ids = [me.uid, other.id]..sort();
      final chatId = ids.join('_');
      final otherName = (other.data()['name'] as String?) ?? phone;
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': ids,
        'names': {me.uid: widget.name, other.id: otherName},
      }, SetOptions(merge: true));
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, otherName: otherName)));
    } catch (e) {
      if (!context.mounted) return;
      showMsg(context, 'خرابی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text('رَاگیر چیٹ - ${widget.name}'),
        backgroundColor: green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'باہر نکلیں',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await setOnline(false);
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: green,
        foregroundColor: Colors.white,
        onPressed: () => startChat(context),
        icon: const Icon(Icons.chat),
        label: const Text('نئی چیٹ', style: TextStyle(fontSize: 20)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: myId)
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
          final docs = snap.data!.docs.toList();
          docs.sort((a, b) {
            final ta = a.data()['updatedAt'] as Timestamp?;
            final tb = b.data()['updatedAt'] as Timestamp?;
            return (tb?.millisecondsSinceEpoch ?? 0)
                .compareTo(ta?.millisecondsSinceEpoch ?? 0);
          });
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('ابھی کوئی چیٹ نہیں۔\nنیچے "نئی چیٹ" دبائیں',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22)),
              ),
            );
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final names = Map<String, dynamic>.from(d['names'] ?? {});
              final ids = List<String>.from(d['participants'] ?? []);
              final otherId =
                  ids.firstWhere((x) => x != myId, orElse: () => myId);
              final otherName = (names[otherId] as String?) ?? 'نامعلوم';
              final last = (d['lastMessage'] as String?) ?? 'پیغام لکھیں';
              final lastSender = d['lastSenderId'] as String?;
              final upd = d['updatedAt'] as Timestamp?;
              final lr = d['lastRead'] as Map<String, dynamic>?;
              final myRead = lr?[myId] as Timestamp?;
              final unread = lastSender != null &&
                  lastSender != myId &&
                  upd != null &&
                  (myRead == null ||
                      myRead.millisecondsSinceEpoch <
                          upd.millisecondsSinceEpoch);
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: green,
                  child: Text(
                    otherName.isEmpty ? '؟' : otherName.substring(0, 1),
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                title: Text(otherName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                subtitle: Text(last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            unread ? FontWeight.bold : FontWeight.normal)),
                trailing: unread
                    ? Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                            color: green, shape: BoxShape.circle),
                      )
                    : null,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        chatId: docs[i].id, otherName: otherName))),
              );
            },
          );
        },
      ),
    );
  }
}

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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherName, style: const TextStyle(fontSize: 20)),
                if (status.isNotEmpty)
                  Text(status, style: const TextStyle(fontSize: 13)),
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
              child: Row(
                children: [
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
