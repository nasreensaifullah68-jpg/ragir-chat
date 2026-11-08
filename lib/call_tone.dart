import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

Uint8List _ringWav() {
  const rate = 8000;
  const on = rate;
  const total = rate * 3;
  final d = ByteData(44 + total * 2);
  void s(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      d.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  s(0, 'RIFF');
  d.setUint32(4, 36 + total * 2, Endian.little);
  s(8, 'WAVE');
  s(12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, 1, Endian.little);
  d.setUint32(24, rate, Endian.little);
  d.setUint32(28, rate * 2, Endian.little);
  d.setUint16(32, 2, Endian.little);
  d.setUint16(34, 16, Endian.little);
  s(36, 'data');
  d.setUint32(40, total * 2, Endian.little);
  for (var i = 0; i < on; i++) {
    final fade = math.min(1.0, math.min(i, on - i) / 400);
    final v = (math.sin(2 * math.pi * 425 * i / rate) * 0.6 * fade * 32767)
        .round();
    d.setInt16(44 + i * 2, v, Endian.little);
  }
  return d.buffer.asUint8List();
}

class RingTone {
  AudioPlayer? _p;
  bool _on = false;

  Future<void> play() async {
    if (_on) return;
    _on = true;
    try {
      final p = AudioPlayer();
      _p = p;
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(BytesSource(_ringWav()));
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!_on) return;
    _on = false;
    final p = _p;
    _p = null;
    try {
      await p?.stop();
      await p?.dispose();
    } catch (_) {}
  }
}
