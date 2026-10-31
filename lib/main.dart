import 'package:flutter/material.dart';

void main() => runApp(const RagirChatApp());

class RagirChatApp extends StatelessWidget {
  const RagirChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رَاگیر چیٹ',
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F8A5F),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0F8A5F);
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
                decoration: const BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: Colors.white, size: 60),
              ),
              const SizedBox(height: 24),
              const Text(
                'رَاگیر چیٹ',
                style: TextStyle(
                    fontSize: 36, fontWeight: FontWeight.bold, color: green),
              ),
              const SizedBox(height: 8),
              const Text(
                'اپنے فون نمبر سے داخل ہوں',
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 32),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 26),
                  decoration: InputDecoration(
                    prefixText: '+92 ',
                    hintText: '3XX XXXXXXX',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('جلد ہی کوڈ بھیجا جائے گا')),
                    );
                  },
                  child: const Text('کوڈ بھیجیں',
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
