import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'chat.dart';
import 'main.dart';
import 'status.dart';

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
            tooltip: 'میری فوٹو',
            icon: const Icon(Icons.account_circle),
            onPressed: () => changePhoto(context),
          ),
          IconButton(
            tooltip: 'اسٹیٹس',
            icon: const Icon(Icons.circle_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => StatusScreen(name: widget.name))),
          ),
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
                leading: UserAvatar(uid: otherId, name: otherName),
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
