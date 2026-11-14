import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'call_ui.dart';
import 'filter.dart';
import 'firebase_options.dart';
import 'home.dart';
import 'login.dart';
import 'keys.dart';
import 'push.dart';
import 'splash.dart';

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
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      title: 'رَاگیر چیٹ',
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: CallOverlay(child: child!)),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: green,
        fontFamily: GoogleFonts.notoNastaliqUrdu().fontFamily,
      ),
      home: const Boot(),
    );
  }
}

class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SplashScreen();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        return snap.data != null ? const HomeGate() : const LoginScreen();
      },
    );
  }
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 12)));
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
        if (!snap.hasData) return const SplashScreen();
        final name = snap.data!.data()?['name'] as String?;
        if (name != null && name.isNotEmpty) {
          syncKeys(snap.data!.reference, snap.data!.data()!, user.email ?? '');
        }
        if (name == null || name.isEmpty) return const NameScreen();
        PushService.init();
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
      final mail = (user.email ?? '').trim().toLowerCase();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'email': mail,
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
