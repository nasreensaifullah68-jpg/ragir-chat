import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

const green = Color(0xFF0F8A5F);

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
          return snap.data != null ? const HomeScreen() : const LoginScreen();
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
      backgroundColor: const Color(0xFFF4FBF7),
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
      backgroundColor: const Color(0xFFF4FBF7),
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('رَاگیر چیٹ'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: green, size: 90),
              const SizedBox(height: 16),
              const Text('خوش آمدید!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(user?.phoneNumber ?? '',
                    style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child:
                    const Text('باہر نکلیں', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
