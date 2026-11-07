import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'orbit.dart';
import 'ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  bool hide = true;

  String? emailFromPhone() {
    var digits = phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('92')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length != 10) return null;
    return '92$digits@ragir.chat';
  }

  String errText(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'نمبر یا پاسورڈ غلط ہے';
      case 'email-already-in-use':
        return 'یہ نمبر پہلے سے رجسٹر ہے، "داخل ہوں" دبائیں';
      case 'weak-password':
        return 'پاسورڈ کم از کم 6 حروف کا رکھیں';
      case 'network-request-failed':
        return 'انٹرنیٹ نہیں ہے';
      default:
        return 'خرابی: ${e.code} ${e.message}';
    }
  }

  Future<void> submit(bool create) async {
    final email = emailFromPhone();
    if (email == null) {
      showMsg(context, 'پورا نمبر لکھیں');
      return;
    }
    if (pass.text.length < 6) {
      showMsg(context, 'پاسورڈ کم از کم 6 حروف کا رکھیں');
      return;
    }
    setState(() => loading = true);
    try {
      if (create) {
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass.text);
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pass.text);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showMsg(context, errText(e));
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2FBF71), Color(0xFF0B6B3A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const OrbitBadge(size: 230, child: BrandLogo(size: 100)),
                  const Text(
                    'راہگیر چیٹ',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: gold,
                      shadows: [
                        Shadow(
                            color: Color(0x66000000),
                            blurRadius: 6,
                            offset: Offset(0, 3)),
                      ],
                    ),
                  ),
                  const Text('Rahgeer Chat',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Text('اپنے فون نمبر سے داخل ہوں',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Column(
                            children: [
                              TextField(
                                controller: phone,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 24),
                                decoration: InputDecoration(
                                  prefixText: '+92 ',
                                  hintText: '3XX XXXXXXX',
                                  filled: true,
                                  fillColor: softBg,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: pass,
                                obscureText: hide,
                                style: const TextStyle(fontSize: 24),
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  filled: true,
                                  fillColor: softBg,
                                  suffixIcon: IconButton(
                                    icon: Icon(hide
                                        ? Icons.visibility
                                        : Icons.visibility_off),
                                    onPressed: () =>
                                        setState(() => hide = !hide),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: green,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: loading ? null : () => submit(false),
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('داخل ہوں',
                                    style: TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: green,
                              side: const BorderSide(color: green, width: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: loading ? null : () => submit(true),
                            child: const Text('نیا کھاتا بنائیں',
                                style: TextStyle(fontSize: 22)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
