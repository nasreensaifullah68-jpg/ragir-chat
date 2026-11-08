import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'attach.dart';
import 'main.dart';
import 'media.dart';
import 'photo.dart';
import 'react.dart';

class MsgBubble extends StatelessWidget {
  final Map<String, dynamic> m;
  final bool mine;
  final bool read;
  final DocumentReference<Map<String, dynamic>> ref;
  const MsgBubble(
      {super.key,
      required this.m,
      required this.mine,
      required this.read,
      required this.ref});

  String fmt(DateTime t) {
    final l = t.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$h:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final ts = m['createdAt'] as Timestamp?;
    return Container(
      constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.75),
      margin: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? green : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000),
              blurRadius: 3,
              offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m['imageUrl'] != null ||
              m['viewed'] == true)
            PhotoBubble(
                url: m['imageUrl'] as String?,
                mode:
                    (m['photoMode'] as String?) ?? 'save',
                mine: mine,
                viewed: m['viewed'] == true,
                msgRef: ref),
          AttachBubble(m: m),
          if (m['audioUrl'] != null)
            VoiceBubble(
                url: m['audioUrl'] as String,
                secs: ((m['audioSecs'] as num?) ?? 0)
                    .toInt()),
          if (((m['text'] as String?) ?? '').isNotEmpty)
            Text((m['text'] as String?) ?? '',
                style: TextStyle(
                    fontSize: 20,
                    color: mine
                        ? Colors.white
                        : Colors.black87)),
          ReactionRow(
              reactions: Map<String, dynamic>.from(
                  (m['reactions'] as Map?) ?? {})),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ts != null)
                Text(fmt(ts.toDate()),
                    style: TextStyle(
                        fontSize: 12,
                        color: mine
                            ? Colors.white70
                            : Colors.black54)),
              if (mine) const SizedBox(width: 4),
              if (mine)
                Icon(
                  ts == null
                      ? Icons.access_time
                      : (read
                          ? Icons.done_all
                          : Icons.done),
                  size: 16,
                  color: read
                      ? Colors.lightBlueAccent
                      : Colors.white70,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
