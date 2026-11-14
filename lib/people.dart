import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'chat.dart';
import 'keys.dart';
import 'main.dart';

typedef PersonDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

// نام، جی میل یا نمبر سے لوگ ڈھونڈیں
Future<List<PersonDoc>> searchPeople(String raw) async {
  final t = raw.trim().toLowerCase();
  final isPhone = RegExp(r'^[+0-9\s-]{7,}$').hasMatch(t);
  final q = isPhone ? phoneKey(t) : t;
  final col = FirebaseFirestore.instance.collection('users');
  try {
    final s = await col
        .where('discover', isEqualTo: true)
        .where('keys', arrayContains: q)
        .limit(20)
        .get();
    return s.docs;
  } catch (e) {
    // پرانے رولز: صرف مکمل جی میل ملے گا
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      final s = await col.where('email', isEqualTo: t).limit(1).get();
      return s.docs;
    }
    rethrow;
  }
}

Future<void> openChatWith(
    BuildContext context, String myName, PersonDoc other) async {
  final me = FirebaseAuth.instance.currentUser!;
  final ids = [me.uid, other.id]..sort();
  final chatId = ids.join('_');
  final otherName = (other.data()['name'] as String?) ?? 'دوست';
  await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
    'participants': ids,
    'names': {me.uid: myName, other.id: otherName},
  }, SetOptions(merge: true));
  if (!context.mounted) return;
  FocusScope.of(context).unfocus();
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(chatId: chatId, otherName: otherName)));
}

class PeopleResults extends StatelessWidget {
  final List<PersonDoc> docs;
  final void Function(PersonDoc) onTap;
  const PeopleResults({super.key, required this.docs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final d in docs)
            ListTile(
              leading: UserAvatar(
                  uid: d.id,
                  name: (d.data()['name'] as String?) ?? '',
                  radius: 22),
              title: Text((d.data()['name'] as String?) ?? '',
                  style: const TextStyle(fontSize: 19)),
              subtitle: Text((d.data()['email'] as String?) ?? '',
                  style: const TextStyle(fontSize: 13)),
              trailing: const Icon(Icons.chat, color: green),
              onTap: () => onTap(d),
            ),
        ],
      ),
    );
  }
}
