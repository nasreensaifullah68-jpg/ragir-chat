import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'chat.dart';
import 'main.dart';

class _Row {
  final String id;
  final String otherId;
  final String otherName;
  final Map<String, dynamic> d;
  _Row(this.id, this.otherId, this.otherName, this.d);
}

class ChatList extends StatelessWidget {
  final String myId;
  final String query;
  final int filter;
  const ChatList({
    super.key,
    required this.myId,
    required this.query,
    required this.filter,
  });

  String timeText(Timestamp? ts) {
    if (ts == null) return '';
    final l = ts.toDate().toLocal();
    final now = DateTime.now();
    final same = l.year == now.year && l.month == now.month && l.day == now.day;
    if (same) {
      final h = l.hour.toString().padLeft(2, '0');
      final m = l.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${l.day}/${l.month}';
  }

  Widget note(String t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, color: Colors.black54)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (filter == 1) return note('گروپ چیٹ جلد آ رہی ہے');
    if (filter == 3) return note('پسندیدہ چیٹس جلد آ رہی ہیں');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: myId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text('خرابی: ${snap.error}'),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = <_Row>[];
        for (final doc in snap.data!.docs) {
          final d = doc.data();
          final names = Map<String, dynamic>.from(d['names'] ?? {});
          final ids = List<String>.from(d['participants'] ?? []);
          final otherId = ids.firstWhere((x) => x != myId, orElse: () => myId);
          final otherName = (names[otherId] as String?) ?? 'نامعلوم';
          if (query.isNotEmpty && !otherName.contains(query)) continue;
          rows.add(_Row(doc.id, otherId, otherName, d));
        }
        rows.sort((a, b) {
          final ta = a.d['updatedAt'] as Timestamp?;
          final tb = b.d['updatedAt'] as Timestamp?;
          return (tb?.millisecondsSinceEpoch ?? 0)
              .compareTo(ta?.millisecondsSinceEpoch ?? 0);
        });
        if (rows.isEmpty) {
          return note(query.isNotEmpty
              ? 'اس نام کی کوئی چیٹ نہیں ملی'
              : 'ابھی کوئی چیٹ نہیں۔\nاوپر کسی کا نمبر لکھ کر تلاش کریں');
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
          itemBuilder: (context, i) {
            final r = rows[i];
            final last = (r.d['lastMessage'] as String?) ?? 'پیغام لکھیں';
            final lastSender = r.d['lastSenderId'] as String?;
            final upd = r.d['updatedAt'] as Timestamp?;
            final lr = r.d['lastRead'] as Map<String, dynamic>?;
            final myRead = lr?[myId] as Timestamp?;
            final unread = lastSender != null &&
                lastSender != myId &&
                upd != null &&
                (myRead == null ||
                    myRead.millisecondsSinceEpoch < upd.millisecondsSinceEpoch);
            return ListTile(
              tileColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: UserAvatar(uid: r.otherId, name: r.otherName),
              title: Text(r.otherName,
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.bold)),
              subtitle: Text(last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17,
                      color: unread ? Colors.black : Colors.black54,
                      fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(timeText(upd),
                      style: TextStyle(
                          fontSize: 13,
                          color: unread ? green : Colors.black45)),
                  const SizedBox(height: 6),
                  unread
                      ? Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: green, shape: BoxShape.circle),
                        )
                      : const SizedBox(height: 16),
                ],
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(chatId: r.id, otherName: r.otherName))),
            );
          },
        );
      },
    );
  }
}
