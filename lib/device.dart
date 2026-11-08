import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? _cachedId;

String _rand(int n, String chars) {
  final r = Random.secure();
  return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
}

Future<String> myDeviceId() async {
  if (_cachedId != null) return _cachedId!;
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  try {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('device_id');
    if (id == null || id.length < 10) {
      id = _rand(20, chars);
      await p.setString('device_id', id);
    }
    _cachedId = id;
    return id;
  } catch (_) {
    _cachedId ??= _rand(20, chars);
    return _cachedId!;
  }
}

String shortId(String id) => id.substring(0, 4).toUpperCase();

String newSalt() => _rand(16, 'abcdef0123456789');

String newRecoveryCode() {
  final c = _rand(12, 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789');
  return '${c.substring(0, 4)}-${c.substring(4, 8)}-${c.substring(8)}';
}

String recoveryHash(String code, String salt) {
  final clean = code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  return sha256.convert(utf8.encode('$salt:$clean')).toString();
}
