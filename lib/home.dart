import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'channels.dart';
import 'chat.dart';
import 'chat_list.dart';
import 'main.dart';
import 'me.dart';
import 'status.dart';
import 'ui.dart';

class HomeScreen extends StatefulWidget {
  final String name;
  const HomeScreen({super.key, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? timer;
  int tab = 0;
  int filter = 0;
  bool searching = false;
  final search = TextEditingController();
  final searchFocus = FocusNode();

  String get digits => search.text.replaceAll(RegExp(r'[^0-9]'), '');

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
    var d = digits;
    if (d.startsWith('92')) d = d.substring(2);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length != 10) {
      showMsg(context, 'پورا نمبر لکھیں (10 ہندسے)');
      return;
    }
    final phone = '+92$d';
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

  Future<void> logout() async {
    await setOnline(false);
    await FirebaseAuth.instance.signOut();
  }

  Widget searchBox() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: TextField(
        controller: search,
        focusNode: searchFocus,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (digits.length >= 10) findPerson();
        },
        style: const TextStyle(fontSize: 20),
        decoration: InputDecoration(
          hintText: 'نام یا نمبر سے تلاش کریں',
          filled: true,
          fillColor: softBg,
          prefixIcon: const Icon(Icons.search, color: green, size: 28),
          suffixIcon: search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    search.clear();
                    setState(() {});
                  },
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget chatsTab(String myId) {
    final isNumber = digits.length >= 10;
    return Column(
      children: [
        searchBox(),
        Container(
          color: Colors.white,
          child: PillTabs(
            labels: const ['تمام چیٹس', 'گروپ', 'ذاتی', 'پسندیدہ'],
            selected: filter,
            onTap: (i) => setState(() => filter = i),
          ),
        ),
        if (isNumber)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: searching ? null : findPerson,
                icon: searching
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.white))
                    : const Icon(Icons.chat),
                label: const Text('اس نمبر سے چیٹ شروع کریں',
                    style: TextStyle(fontSize: 19)),
              ),
            ),
          ),
        Expanded(
          child: ChatList(
            myId: myId,
            query: isNumber ? '' : search.text.trim(),
            filter: filter,
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget chatsBar() {
    return AppBar(
      toolbarHeight: 70,
      backgroundColor: green,
      foregroundColor: Colors.white,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.search, size: 30),
        onPressed: () => searchFocus.requestFocus(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLogo(size: 40),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('راہگیر چیٹ',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              Text('Rahgeer Chat', style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, size: 32),
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          ),
        ),
      ],
    );
  }

  Widget drawerItem(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: green, size: 28),
      title: Text(text, style: const TextStyle(fontSize: 20)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget drawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: green,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const BrandLogo(size: 72),
                  const SizedBox(height: 10),
                  Text(widget.name,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ),
            drawerItem(Icons.person, 'میری پروفائل', () => setState(() => tab = 3)),
            drawerItem(Icons.person_add_alt_1, 'نیا رابطہ', () => soon(context)),
            drawerItem(Icons.group_add, 'نیا گروپ بنائیں', () => soon(context)),
            drawerItem(Icons.campaign, 'نیا چینل بنائیں', () => setState(() => tab = 1)),
            drawerItem(Icons.qr_code_scanner, 'QR کوڈ سے اسکین کریں', () => soon(context)),
            drawerItem(Icons.settings, 'سیٹنگز', () => soon(context)),
            drawerItem(Icons.dark_mode, 'ڈارک موڈ', () => soon(context)),
            drawerItem(Icons.info, 'ایپ کے بارے میں', () => soon(context)),
            const Divider(),
            drawerItem(Icons.logout, 'لاگ آؤٹ', logout),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: softBg,
      endDrawer: drawer(),
      appBar: tab == 0
          ? chatsBar()
          : (tab == 3
              ? AppBar(
                  title: const Text('میرا کھاتا',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                )
              : null),
      floatingActionButton: tab == 0
          ? FloatingActionButton(
              backgroundColor: green,
              foregroundColor: Colors.white,
              tooltip: 'نئی چیٹ',
              onPressed: () => searchFocus.requestFocus(),
              child: const Icon(Icons.edit),
            )
          : null,
      body: tab == 0
          ? chatsTab(myId)
          : (tab == 1
              ? ChannelsScreen(name: widget.name)
              : tab == 2
                  ? StatusScreen(name: widget.name)
                  : MeTab(name: widget.name, onLogout: logout)),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD6F5E5),
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: green),
              label: 'چیٹس'),
          NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign, color: green),
              label: 'چینلز'),
          NavigationDestination(
              icon: Icon(Icons.circle_outlined),
              selectedIcon: Icon(Icons.circle, color: green),
              label: 'اسٹیٹس'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: green),
              label: 'میں'),
        ],
      ),
    );
  }
}
