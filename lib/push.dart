import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

// Server link goes here later (full link ending with /api/notify).
// While this is empty, no push is sent and nothing else changes.
const pushUrl = '';

class PushService {
  static String? _uid;

  // Asks for notification permission and saves this phone's token.
  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _uid == user.uid) return;
    _uid = user.uid;
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      final t = await m.getToken();
      if (t != null) await _save(user.uid, t);
      m.onTokenRefresh.listen((n) {
        final u = FirebaseAuth.instance.currentUser;
        if (u != null) _save(u.uid, n);
      });
    } catch (_) {}
  }

  static Future<void> _save(String uid, String token) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcm': token}, SetOptions(merge: true));
  }

  // Tells the server to send a push to another person.
  static Future<void> notify(
      String toUid, String kind, String title, String body) async {
    if (pushUrl.isEmpty) return;
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) return;
      await http
          .post(
            Uri.parse(pushUrl),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'toUid': toUid,
              'kind': kind,
              'title': title,
              'body': body,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
