import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'main.dart';
import 'orbit.dart';
import 'ui.dart';

class MeTab extends StatelessWidget {
  final String name;
  final Future<void> Function() onLogout;
  const MeTab({super.key, required this.name, required this.onLogout});

  Widget row(IconData icon, Color c, String text, VoidCallback onTap) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: c, size: 30),
        title: Text(text, style: TextStyle(fontSize: 20, color: c)),
        trailing: const Icon(Icons.chevron_left, color: Colors.black38),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(myId).snapshots(),
      builder: (context, snap) {
        final phone = (snap.data?.data()?['phone'] as String?) ?? '';
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: GestureDetector(
                onTap: () => changePhoto(context),
                child: OrbitBadge(
                  size: 250,
                  child: Stack(
                    children: [
                      UserAvatar(uid: myId, name: name, radius: 54),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                              color: green, shape: BoxShape.circle),
                          child: const Icon(Icons.photo_camera,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Text(name,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, color: Colors.black54)),
            ),
            const SizedBox(height: 14),
            _Stats(uid: myId),
            const SizedBox(height: 14),
            row(Icons.photo_camera, green, 'میری فوٹو بدلیں',
                () => changePhoto(context)),
            row(Icons.settings, green, 'اکاؤنٹ کی ترتیبات', () => soon(context)),
            row(Icons.lock, green, 'پرائیویسی اور سیکیورٹی',
                () => soon(context)),
            row(Icons.notifications, green, 'نوٹیفکیشنز', () => soon(context)),
            row(Icons.help, green, 'مدد اور سپورٹ', () => soon(context)),
            row(Icons.logout, Colors.red, 'لاگ آؤٹ', onLogout),
          ],
        );
      },
    );
  }
}

class _Stats extends StatefulWidget {
  final String uid;
  const _Stats({required this.uid});

  @override
  State<_Stats> createState() => _StatsState();
}

class _StatsState extends State<_Stats> {
  int? friends;
  int? channels;
  int? statuses;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final db = FirebaseFirestore.instance;
    try {
      final a = await db
          .collection('chats')
          .where('participants', arrayContains: widget.uid)
          .get();
      final b = await db
          .collection('channels')
          .where('ownerId', isEqualTo: widget.uid)
          .get();
      final c = await db
          .collection('statuses')
          .where('authorId', isEqualTo: widget.uid)
          .get();
      final live = c.docs.where((x) {
        final t = x.data()['createdAt'] as Timestamp?;
        return t == null || DateTime.now().difference(t.toDate()).inHours < 24;
      }).length;
      if (!mounted) return;
      setState(() {
        friends = a.docs.length;
        channels = b.docs.length;
        statuses = live;
      });
    } catch (_) {}
  }

  Widget cell(int? n, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(n == null ? '-' : '$n',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(fontSize: 17, color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: green,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          cell(friends, 'دوست'),
          cell(channels, 'چینلز'),
          cell(statuses, 'اسٹیٹس'),
        ],
      ),
    );
  }
}
