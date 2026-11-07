import 'package:flutter/material.dart';
import 'orbit.dart';
import 'ui.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2FBF71), Color(0xFF0B6B3A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              const OrbitBadge(size: 270, child: BrandLogo(size: 120)),
              const SizedBox(height: 10),
              const Text(
                'راہگیر چیٹ',
                style: TextStyle(
                  fontSize: 44,
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
              const Text(
                'Rahgeer Chat',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B5F32),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: gold, width: 2),
                ),
                child: const Text(
                  'جڑیں، بات کریں، آگے بڑھیں',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: 230,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    minHeight: 10,
                    color: Color(0xFFB6F442),
                    backgroundColor: Color(0x55FFFFFF),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Loading...',
                  style: TextStyle(fontSize: 16, color: Colors.white)),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
