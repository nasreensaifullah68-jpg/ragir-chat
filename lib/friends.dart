import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'chat.dart';
import 'main.dart';
import 'ui.dart';

class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({super.key});

  Future<void> accept(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> d) async {
    final me = FirebaseAuth.instance.currentUser!;
    final from = (d.data()['from'] as String?) ?? '';
    final name = (d.data()['fromName'] as String?) ?? 'دوست';
    try {
      await d.reference.update({'status': 'accepted'});
      final ids = [me.uid, from]..sort();
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(ids.join('_'))
          .set({
        'participants': ids,
        'names': {from: name},
      }, SetOptions(merge: true));
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ChatScreen(chatId: ids.join('_'), otherName: name)));
    } catch (e) {
      if (context.mounted) showMsg(context, 'خرابی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.white,
        title: const Text('دوستی کی درخواستیں'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('friendReqs')
            .where('to', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('خرابی: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
                child: Text('کوئی نئی درخواست نہیں',
                    style: TextStyle(fontSize: 20, color: Colors.black54)));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final d in docs)
                Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: UserAvatar(
                        uid: (d.data()['from'] as String?) ?? '',
                        name: (d.data()['fromName'] as String?) ?? '',
                        radius: 24),
                    title: Text((d.data()['fromName'] as String?) ?? '',
                        style: const TextStyle(fontSize: 19)),
                    subtitle: const Text('دوستی کی درخواست'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: green, size: 32),
                          onPressed: () => accept(context, d),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel,
                              color: Colors.red, size: 32),
                          onPressed: () => d.reference.delete(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
