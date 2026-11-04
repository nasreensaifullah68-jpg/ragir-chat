import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'chat.dart';
import 'main.dart';
import 'me.dart';
import 'status.dart';

class HomeScreen extends StatefulWidget {
  final String name;
  const HomeScreen({super.key, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? timer;
  int tab = 0;
  bool searching = false;
  final search = TextEditingController();
  final searchFocus = FocusNode();

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
    search.dispose();
    searchFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> findPerson() async {
    final me = FirebaseAuth.instance.currentUser!;
    var digits = search.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('92')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length != 10) {
      showMsg(context, 'پورا نمبر لکھیں (10 ہندسے)');
      return;
    }
    final phone = '+92$digits';
    setState(() => searching = true);
    try {
      final found = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (!mounted) return;
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
      if (!mounted) return;
      search.clear();
      FocusScope.of(context).unfocus();
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, otherName: otherName)));
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  String timeText(Timestamp? ts) {
    if (ts == null) return '';
    final l = ts.toDate().toLocal();
    final now = DateTime.now();
    final same = l.year == now.year && l.month == now.month && l.day == now.day;
    if (same) {
      final h = l.hour.toString().padLeft(2, '0');
      final m = l.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${l.day}/${l.month}';
  }

  Widget searchBox() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('کسی کا نمبر لکھیں اور چیٹ شروع کریں',
              style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: search,
              focusNode: searchFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => findPerson(),
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                prefixText: '+92 ',
                hintText: '3XX XXXXXXX',
                filled: true,
                fillColor: softBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                suffixIcon: searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 3)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search, color: green, size: 30),
                        onPressed: findPerson,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget chatsTab(String myId) {
    return Column(
      children: [
        searchBox(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    child: Text(
                        'ابھی کوئی چیٹ نہیں۔\nاوپر کسی کا نمبر لکھ کر تلاش کریں',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, color: Colors.black54)),
                  ),
                );
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 84),
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
                    tileColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: UserAvatar(uid: otherId, name: otherName),
                    title: Text(otherName,
                        style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.bold)),
                    subtitle: Text(last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            color: unread ? Colors.black : Colors.black54,
                            fontWeight:
                                unread ? FontWeight.bold : FontWeight.normal)),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(timeText(upd),
                            style: TextStyle(
                                fontSize: 13,
                                color: unread ? green : Colors.black45)),
                        const SizedBox(height: 6),
                        unread
                            ? Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                    color: green, shape: BoxShape.circle),
                              )
                            : const SizedBox(height: 14),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChatScreen(
                            chatId: docs[i].id, otherName: otherName))),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: softBg,
      appBar: tab == 1
          ? null
          : AppBar(
              title: Text(tab == 0 ? 'رَاگیر چیٹ' : 'میرا کھاتا',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              backgroundColor: green,
              foregroundColor: Colors.white,
            ),
      floatingActionButton: tab == 0
          ? FloatingActionButton(
              backgroundColor: green,
              foregroundColor: Colors.white,
              tooltip: 'نئی چیٹ',
              onPressed: () => searchFocus.requestFocus(),
              child: const Icon(Icons.person_add_alt_1),
            )
          : null,
      body: tab == 0
          ? chatsTab(myId)
          : (tab == 1
              ? StatusScreen(name: widget.name)
              : MeTab(
                  name: widget.name,
                  onLogout: () async {
                    await setOnline(false);
                    await FirebaseAuth.instance.signOut();
                  })),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'چیٹس'),
          NavigationDestination(
              icon: Icon(Icons.circle_outlined),
              selectedIcon: Icon(Icons.circle),
              label: 'اسٹیٹس'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'میں'),
        ],
      ),
    );
  }
}
