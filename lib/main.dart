import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

const green = Color(0xFF0F8A5F);
const softBg = Color(0xFFF4FBF7);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const RagirChatApp());
}

class RagirChatApp extends StatelessWidget {
  const RagirChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رَاگیر چیٹ',
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: green),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return snap.data != null ? const HomeGate() : const LoginScreen();
        },
      ),
    );
  }
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final controller = TextEditingController();
  bool loading = false;

  Future<void> sendCode() async {
    var digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length < 10) {
      showMsg(context, 'پورا نمبر لکھیں');
      return;
    }
    setState(() => loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+92$digits',
      verificationCompleted: (cred) async {
        await FirebaseAuth.instance.signInWithCredential(cred);
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => loading = false);
        showMsg(context, 'خرابی: ${e.code}');
      },
      codeSent: (id, _) {
        if (!mounted) return;
        setState(() => loading = false);
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OtpScreen(verificationId: id)));
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration:
                    const BoxDecoration(color: green, shape: BoxShape.circle),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: Colors.white, size: 60),
              ),
              const SizedBox(height: 24),
              const Text('رَاگیر چیٹ',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: green)),
              const SizedBox(height: 8),
              const Text('اپنے فون نمبر سے داخل ہوں',
                  style: TextStyle(fontSize: 22)),
              const SizedBox(height: 32),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 26),
                  decoration: InputDecoration(
                    prefixText: '+92 ',
                    hintText: '3XX XXXXXXX',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: loading ? null : sendCode,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('کوڈ بھیجیں',
                          style: TextStyle(fontSize: 24)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  final String verificationId;
  const OtpScreen({super.key, required this.verificationId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final controller = TextEditingController();
  bool loading = false;

  Future<void> verify() async {
    setState(() => loading = true);
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: controller.text.trim());
      await FirebaseAuth.instance.signInWithCredential(cred);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMsg(context, 'خرابی: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(title: const Text('کوڈ درج کریں')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('آپ کے نمبر پر آیا ہوا 6 ہندسوں کا کوڈ لکھیں',
                style: TextStyle(fontSize: 22), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, letterSpacing: 8),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: loading ? null : verify,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('داخل ہوں', style: TextStyle(fontSize: 24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeGate extends StatelessWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('خرابی: ${snap.error}'),
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final name = snap.data!.data()?['name'] as String?;
        if (name == null || name.isEmpty) return const NameScreen();
        return HomeScreen(name: name);
      },
    );
  }
}

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final controller = TextEditingController();
  bool loading = false;

  Future<void> save() async {
    final name = controller.text.trim();
    if (name.isEmpty) {
      showMsg(context, 'اپنا نام لکھیں');
      return;
    }
    setState(() => loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'phone': user.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMsg(context, 'خرابی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle, color: green, size: 110),
              const SizedBox(height: 16),
              const Text('آپ کا نام کیا ہے؟',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'یہاں نام لکھیں',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: loading ? null : save,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('محفوظ کریں',
                          style: TextStyle(fontSize: 24)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              builder: (c
