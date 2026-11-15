import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'keys.dart';
import 'main.dart';

class PhoneCard extends StatefulWidget {
  const PhoneCard({super.key});

  @override
  State<PhoneCard> createState() => _PhoneCardState();
}

class _PhoneCardState extends State<PhoneCard> {
  final ctrl = TextEditingController();
  String oldKey = '';
  bool busy = false;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    if (uid.isEmpty) return;
    FirebaseFirestore.instance.collection('users').doc(uid).get().then((d) {
      if (!mounted) return;
      final p = (d.data()?['phone'] as String?) ?? '';
      ctrl.text = p;
      oldKey = phoneKey(p);
    });
  }

  Future<void> save() async {
    final raw = ctrl.text.trim();
    final key = phoneKey(raw);
    if (raw.isNotEmpty && key.length < 9) {
      showMsg(context, 'پورا نمبر لکھیں، جیسے 03001234567');
      return;
    }
    setState(() => busy = true);
    final db = FirebaseFirestore.instance;
    try {
      await db.runTransaction((tx) async {
        if (key.isNotEmpty) {
          final r = db.collection('phones').doc(key);
          final s = await tx.get(r);
          if (s.exists && s.data()?['uid'] != uid) throw 'taken';
          if (!s.exists) tx.set(r, {'uid': uid});
        }
        if (oldKey.isNotEmpty && oldKey != key) {
          tx.delete(db.collection('phones').doc(oldKey));
        }
        tx.set(db.collection('users').doc(uid), {'phone': raw},
            SetOptions(merge: true));
      });
      oldKey = key;
      if (mounted) showMsg(context, 'نمبر محفوظ ہو گیا');
    } catch (e) {
      if (mounted) {
        showMsg(
            context,
            e.toString().contains('taken')
                ? 'یہ نمبر کسی اور اکاؤنٹ پر لگا ہوا ہے'
                : 'خرابی: $e');
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('فون نمبر (اختیاری)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'اس نمبر سے لوگ آپ کو ڈھونڈ سکیں گے۔ ایک نمبر ایک ہی اکاؤنٹ پر لگ سکتا ہے۔ نمبر کی تصدیق (OTP) ابھی نہیں ہوتی۔',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  hintText: '03XXXXXXXXX',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: busy ? null : save,
              icon: const Icon(Icons.check),
              label: const Text('نمبر محفوظ کریں',
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
