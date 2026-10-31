import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';

class HomeScreen extends StatelessWidget {
  final String name;
  const HomeScreen({super.key, required this.name});

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
        'names': {me.uid: name, other.id: otherName},
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
        title: Text('رَاگیر چیٹ - $name'),
        backgroundColor: green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'باہر نکلیں',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
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
                    style: const TextStyle(fontSize: 18)),
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

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    try {
      await chatRef.collection('messages').add({
        'text': text,
        'senderId': me.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await chatRef.update({
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
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
        title: Text(widget.otherName),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
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
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = docs[i].data();
                    final mine = m['senderId'] == me.uid;
                    final ts = m['createdAt'] as Timestamp?;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              mine ? const Color(0xFFD6F5E5) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((m['text'] as String?) ?? '',
                                style: const TextStyle(fontSize: 20)),
                            if (ts != null)
                              Text(fmt(ts.toDate()),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
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
}import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';

class HomeScreen extends StatelessWidget {
  final String name;
  const HomeScreen({super.key, required this.name});

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
        'names': {me.uid: name, other.id: otherName},
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
        title: Text('رَاگیر چیٹ - $name'),
        backgroundColor: green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'باہر نکلیں',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
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
                    style: const TextStyle(fontSize: 18)),
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

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    try {
      await chatRef.collection('messages').add({
        'text': text,
        'senderId': me.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await chatRef.update({
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
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
        title: Text(widget.otherName),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
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
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = docs[i].data();
                    final mine = m['senderId'] == me.uid;
                    final ts = m['createdAt'] as Timestamp?;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              mine ? const Color(0xFFD6F5E5) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((m['text'] as String?) ?? '',
                                style: const TextStyle(fontSize: 20)),
                            if (ts != null)
                              Text(fmt(ts.toDate()),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
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
