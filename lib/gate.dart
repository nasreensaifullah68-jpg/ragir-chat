import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'device.dart';
import 'filter.dart';
import 'main.dart';
import 'splash.dart';

DocumentReference<Map<String, dynamic>> _userRef() => FirebaseFirestore
    .instance
    .collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid);

Future<T?> _dialog<T>(WidgetBuilder b) async {
  final nav = navKey.currentState;
  final ov = nav?.overlay;
  if (nav == null || ov == null) return null;
  return nav.push<T>(DialogRoute<T>(
      context: ov.context, barrierDismissible: false, builder: b));
}

Future<void> showRecoveryCode(String code) async {
  await _dialog<void>((c) => AlertDialog(
        title: const Text('آپ کا ریکوری کوڈ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'اسے کاغذ پر لکھ لیں۔ فون کھو جائے تو نیا فون اسی کوڈ سے منظور ہوگا۔ یہ دوبارہ نہیں دکھایا جائے گا۔',
                style: TextStyle(fontSize: 17)),
            const SizedBox(height: 16),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(code,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Text('کاپی', style: TextStyle(fontSize: 18))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: () => Navigator.pop(c),
              child: const Text('میں نے لکھ لیا',
                  style: TextStyle(fontSize: 18))),
        ],
      ));
}

class DeviceGate extends StatefulWidget {
  final Widget child;
  const DeviceGate({super.key, required this.child});

  @override
  State<DeviceGate> createState() => _DeviceGateState();
}

class _DeviceGateState extends State<DeviceGate> {
  String? devId;
  bool setting = false;

  @override
  void initState() {
    super.initState();
    myDeviceId().then((v) {
      if (mounted) setState(() => devId = v);
    });
  }

  Future<void> firstTrust(String id) async {
    if (setting) return;
    setting = true;
    final code = newRecoveryCode();
    final salt = newSalt();
    var done = false;
    try {
      final ref = _userRef();
      done = await FirebaseFirestore.instance.runTransaction<bool>((t) async {
        final s = await t.get(ref);
        final tr = (s.data()?['trusted'] as List?) ?? [];
        if (tr.isNotEmpty) return false;
        t.set(
            ref,
            {
              'trusted': [id],
              'recoverySalt': salt,
              'recoveryHash': recoveryHash(code, salt),
            },
            SetOptions(merge: true));
        return true;
      });
    } catch (_) {}
    if (done) await showRecoveryCode(code);
    setting = false;
  }

  @override
  Widget build(BuildContext context) {
    final id = devId;
    if (id == null) return const SplashScreen();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userRef().snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SplashScreen();
        final tr = ((snap.data!.data()?['trusted'] as List?) ?? [])
            .map((e) => e.toString())
            .toList();
        if (tr.isEmpty) {
          firstTrust(id);
          return const SplashScreen();
        }
        if (tr.contains(id)) return _Approver(child: widget.child);
        return PendingScreen(devId: id);
      },
    );
  }
}

class _Approver extends StatefulWidget {
  final Widget child;
  const _Approver({required this.child});

  @override
  State<_Approver> createState() => _ApproverState();
}

class _ApproverState extends State<_Approver> {
  StreamSubscription? sub;
  bool showing = false;

  @override
  void initState() {
    super.initState();
    sub = _userRef()
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((s) {
      if (s.docs.isNotEmpty && !showing) ask(s.docs.first);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<void> ask(QueryDocumentSnapshot<Map<String, dynamic>> d) async {
    showing = true;
    final label = (d.data()['label'] as String?) ?? 'نیا فون';
    final ok = await _dialog<bool>((c) => AlertDialog(
          title: const Text('نیا فون لاگ اِن کرنا چاہتا ہے'),
          content: Text(
              '$label آپ کے اکاؤنٹ میں آنا چاہتا ہے۔\n\nکیا یہ آپ ہی ہیں؟',
              style: const TextStyle(fontSize: 20)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('مسترد',
                    style: TextStyle(fontSize: 20, color: Colors.red))),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: green),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('منظور', style: TextStyle(fontSize: 20))),
          ],
        ));
    try {
      if (ok == true) {
        final b = FirebaseFirestore.instance.batch();
        b.update(d.reference, {'status': 'approved'});
        b.update(_userRef(), {
          'trusted': FieldValue.arrayUnion([d.id])
        });
        await b.commit();
      } else {
        await d.reference.update({'status': 'denied'});
      }
    } catch (_) {}
    showing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class PendingScreen extends StatefulWidget {
  final String devId;
  const PendingScreen({super.key, required this.devId});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  final code = TextEditingController();
  bool busy = false;

  DocumentReference<Map<String, dynamic>> get reqRef =>
      _userRef().collection('requests').doc(widget.devId);

  @override
  void initState() {
    super.initState();
    send();
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> send() async {
    try {
      await reqRef.set({
        'status': 'pending',
        'deviceId': widget.devId,
        'label': 'فون ${shortId(widget.devId)}',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
  }

  Future<void> useCode() async {
    final c = code.text.trim();
    if (c.length < 12) {
      showMsg(context, 'پورا ریکوری کوڈ لکھیں');
      return;
    }
    setState(() => busy = true);
    try {
      final d = (await _userRef().get()).data() ?? {};
      final salt = (d['recoverySalt'] as String?) ?? '';
      if (salt.isNotEmpty && recoveryHash(c, salt) == d['recoveryHash']) {
        await _userRef().update({
          'trusted': FieldValue.arrayUnion([widget.devId])
        });
      } else if (mounted) {
        showMsg(context, 'کوڈ غلط ہے');
      }
    } catch (e) {
      if (mounted) showMsg(context, 'خرابی: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.white,
        title: const Text('منظوری درکار ہے'),
        actions: [
          TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('لاگ آؤٹ',
                  style: TextStyle(color: Colors.white, fontSize: 18))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.phonelink_lock, size: 80, color: green),
          const SizedBox(height: 12),
          Text('یہ نیا فون ہے (فون ${shortId(widget.devId)})',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'اپنے پرانے فون پر رَاگیر چیٹ کھولیں۔ وہاں "منظور" کا پیغام آئے گا۔ منظور ہوتے ہی یہاں ایپ کھل جائے گی۔',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18)),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: reqRef.snapshots(),
            builder: (context, s) {
              final st = s.data?.data()?['status'];
              if (st == 'denied') {
                return const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('پرانے فون سے مسترد کر دیا گیا۔',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.red)),
                );
              }
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: send,
              child: const Text('دوبارہ درخواست بھیجیں',
                  style: TextStyle(fontSize: 18))),
          const Divider(height: 40),
          const Text('پرانا فون نہیں ہے؟ ریکوری کوڈ لکھیں:',
              style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 22, letterSpacing: 2),
              decoration: const InputDecoration(
                  hintText: 'XXXX-XXXX-XXXX', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: busy ? null : useCode,
              child: const Text('کوڈ سے منظور کریں',
                  style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }
}
