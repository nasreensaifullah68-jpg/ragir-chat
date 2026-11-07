import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'main.dart';

final FlutterTts _tts = FlutterTts();
bool _ready = false;
bool _urduOk = true;

Future<void> speakText(BuildContext context, String text) async {
  final t = text.trim();
  if (t.isEmpty) return;
  try {
    if (!_ready) {
      final ok = await _tts.isLanguageAvailable('ur-PK');
      _urduOk = ok == true || ok == 1;
      if (_urduOk) await _tts.setLanguage('ur-PK');
      await _tts.setSpeechRate(0.45);
      _ready = true;
    }
    if (!_urduOk && context.mounted) {
      showMsg(context,
          'اردو آواز فون میں نہیں ملی۔ فون کی سیٹنگز میں "Text-to-speech" کھول کر اردو ڈاؤن لوڈ کریں');
    }
    await _tts.stop();
    await _tts.speak(t);
  } catch (e) {
    if (context.mounted) showMsg(context, 'آواز میں خرابی: $e');
  }
}

Future<void> stopSpeaking() async {
  try {
    await _tts.stop();
  } catch (_) {}
}
