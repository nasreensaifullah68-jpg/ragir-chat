import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'ui.dart';

Widget _page(String title, List<Widget> kids) {
  return Scaffold(
    backgroundColor: softBg,
    appBar: AppBar(
      backgroundColor: green,
      foregroundColor: Colors.white,
      title: Text(title),
    ),
    body: ListView(padding: const EdgeInsets.all(16), children: kids),
  );
}

Widget _card(List<Widget> kids) {
  return Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: kids,
      ),
    ),
  );
}

Widget _btn(String text, IconData icon, VoidCallback? onTap) {
  return SizedBox(
    width: double.infinity,
    height: 48,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      label: Text(text, style: const TextStyle(fontSize: 18)),
    ),
  );
}

// ---------- Account settings: change name, reset password ----------
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final ctrl = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((d) {
        if (mounted) ctrl.text = (d.data()?['name'] as String?) ?? '';
      });
    }
  }

  Future<void> saveName() async {
    final n = ctrl.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (n.isEmpty || uid == null) {
      showMsg(context, 'نام لکھیں');
      return;
    }
    setState(() => busy = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'name': n}, SetOptions(merge: true));
      if (!mounted) return;
      showMsg(context, 'نام بدل گیا');
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> resetPass() async {
    final mail = FirebaseAuth.instance.currentUser?.email;
    if (mail == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
      if (mounted) showMsg(context, 'پاسورڈ بدلنے کا لنک $mail پر بھیج دیا');
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mail = FirebaseAuth.instance.currentUser?.email ?? '';
    return _page('اکاؤنٹ کی ترتیبات', [
      _card([
        const Text('آپ کا نام',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        _btn('نام محفوظ کریں', Icons.check, busy ? null : saveName),
      ]),
      _card([
        const Text('جی میل',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(mail,
              style: const TextStyle(fontSize: 20, color: Colors.black54)),
        ),
      ]),
      _card([
        const Text('پاسورڈ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('پاسورڈ بدلنے کا لنک آپ کے جی میل پر آئے گا۔',
            style: TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 10),
        _btn('پاسورڈ بدلنے کا لنک بھیجیں', Icons.mail, resetPass),
      ]),
    ]);
  }
}

// ---------- Privacy and security tips ----------
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  Widget item(IconData i, String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, color: green, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 18))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _page('پرائیویسی اور سیکیورٹی', [
      _card([
        item(Icons.search,
            'کوئی آپ کو صرف آپ کے پورے جی میل سے ڈھونڈ سکتا ہے۔ فہرست سب کو نہیں دکھتی۔'),
        item(Icons.lock, 'اپنا پاسورڈ کسی کو نہ بتائیں۔'),
        item(Icons.visibility_off,
            'فوٹو بھیجتے وقت "ایک بار دیکھیں" یا "صرف دیکھیں" چن سکتے ہیں۔'),
        item(Icons.devices,
            'فون بدلیں تو اسی جی میل اور پاسورڈ سے دوبارہ لاگ اِن کریں۔'),
      ]),
      _card([
        const Text('پاسورڈ بدلنا چاہتے ہیں؟',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _btn('اکاؤنٹ کی ترتیبات کھولیں', Icons.settings, () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountPage()));
        }),
      ]),
    ]);
  }
}

// ---------- Notifications ----------
class NotifyPage extends StatefulWidget {
  const NotifyPage({super.key});

  @override
  State<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<NotifyPage> {
  Future<NotificationSettings> f =
      FirebaseMessaging.instance.getNotificationSettings();

  Future<void> ask() async {
    await FirebaseMessaging.instance.requestPermission();
    if (!mounted) return;
    setState(() => f = FirebaseMessaging.instance.getNotificationSettings());
  }

  @override
  Widget build(BuildContext context) {
    return _page('نوٹیفکیشنز', [
      FutureBuilder<NotificationSettings>(
        future: f,
        builder: (context, s) {
          final ok = s.data?.authorizationStatus ==
              AuthorizationStatus.authorized;
          return _card([
            Row(
              children: [
                Icon(ok ? Icons.notifications_active : Icons.notifications_off,
                    color: ok ? green : Colors.red, size: 34),
                const SizedBox(width: 10),
                Text(
                    s.hasData
                        ? (ok ? 'نوٹیفکیشن چالو ہیں' : 'نوٹیفکیشن بند ہیں')
                        : '...',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            if (!ok) _btn('اجازت دیں', Icons.notifications, ask),
          ]);
        },
      ),
      _card([
        const Text(
            'ایپ بند ہو تو نئے پیغام اور کال کی اطلاع بھیجنے کا نظام تیاری میں ہے۔ '
            'اجازت دینے سے آپ تیار رہیں گے۔',
            style: TextStyle(fontSize: 17, color: Colors.black54)),
      ]),
    ]);
  }
}

// ---------- Help and support ----------
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  Widget q(String a, String b) {
    return ExpansionTile(
      title: Text(a, style: const TextStyle(fontSize: 19)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedAlignment: Alignment.centerRight,
      children: [Text(b, style: const TextStyle(fontSize: 17))],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _page('مدد اور سپورٹ', [
      Card(
        color: Colors.white,
        child: Column(
          children: [
            q('دوست کو کیسے ڈھونڈوں؟',
                'چیٹس کے صفحے پر تلاش میں اس کا پورا جی میل لکھیں، پھر "چیٹ شروع کریں" دبائیں۔'),
            q('کال کیسے کروں؟',
                'چیٹ کھولیں اور اوپر فون یا ویڈیو کا بٹن دبائیں۔ دونوں کے پاس ایپ کھلی ہونی چاہیے۔'),
            q('فوٹو کیسے بھیجوں؟',
                'چیٹ میں پن کا نشان دبائیں، پھر کیمرہ یا گیلری چنیں، اور چاہیں تو فلٹر لگائیں۔'),
            q('اپنی فوٹو کیسے بدلوں؟',
                'میری پروفائل میں جا کر "میری فوٹو بدلیں" دبائیں۔'),
            q('پاسورڈ بھول گیا؟',
                'لاگ اِن صفحے پر "پاسورڈ بھول گئے؟" دبائیں، لنک آپ کے جی میل پر آئے گا۔'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _btn('ایپ کے بارے میں', Icons.info, () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AboutPage()));
      }),
    ]);
  }
}

// ---------- About ----------
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _page('ایپ کے بارے میں', [
      const SizedBox(height: 10),
      const Center(child: BrandLogo(size: 110)),
      const SizedBox(height: 14),
      const Text('راہگیر چیٹ',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
      const Text('Rahgeer Chat',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, color: Colors.black54)),
      const SizedBox(height: 18),
      _card([
        const Text(
            'اردو میں بنی مفت چیٹ ایپ: پیغام، فوٹو، ویڈیو، آواز، کال، چینل اور اسٹیٹس۔',
            style: TextStyle(fontSize: 18)),
        const SizedBox(height: 10),
        const Text('ورژن: 1.0 (آزمائشی)',
            style: TextStyle(fontSize: 17, color: Colors.black54)),
      ]),
    ]);
  }
}
