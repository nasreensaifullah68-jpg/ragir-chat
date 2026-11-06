import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avatar.dart';
import 'call.dart';

const _green = Color(0xFF0F8A5F);

class CallOverlay extends StatefulWidget {
  final Widget child;
  const CallOverlay({super.key, required this.child});

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  final s = CallService.instance;
  StreamSubscription<User?>? sub;

  @override
  void initState() {
    super.initState();
    sub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u == null) {
        s.stop();
      } else {
        s.listen(u.uid);
      }
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  String clock(int t) {
    final m = (t ~/ 60).toString().padLeft(2, '0');
    final x = (t % 60).toString().padLeft(2, '0');
    return '$m:$x';
  }

  Widget round(IconData icon, Color bg, VoidCallback onTap, {double size = 46}) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }

  Widget banner() {
    final connected = s.phase == CallPhase.connected;
    final text = s.phase == CallPhase.outgoing
        ? 'گھنٹی جا رہی ہے…'
        : (s.phase == CallPhase.connecting ? 'جڑ رہا ہے…' : clock(s.seconds));
    return Material(
      color: _green,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              s.otherId.isEmpty
                  ? const Icon(Icons.call, color: Colors.white)
                  : UserAvatar(uid: s.otherId, name: s.otherName, radius: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.otherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold)),
                    Text(text,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15)),
                  ],
                ),
              ),
              if (connected) ...[
                round(s.muted ? Icons.mic_off : Icons.mic,
                    s.muted ? Colors.orange : Colors.white24, s.toggleMute),
                const SizedBox(width: 10),
                round(s.speaker ? Icons.volume_up : Icons.hearing,
                    s.speaker ? Colors.orange : Colors.white24,
                    s.toggleSpeaker),
                const SizedBox(width: 10),
              ],
              round(Icons.call_end, Colors.red, s.hangUp),
            ],
          ),
        ),
      ),
    );
  }

  Widget noteBar() {
    return Material(
      color: Colors.orange.shade800,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Text(s.note ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 17)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget incoming() {
    return Material(
      color: const Color(0xFF0B3D2E),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            s.otherId.isEmpty
                ? const Icon(Icons.account_circle, color: Colors.white, size: 130)
                : UserAvatar(uid: s.otherId, name: s.otherName, radius: 75),
            const SizedBox(height: 16),
            Text(s.otherName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('راہگیر چیٹ کال آ رہی ہے…',
                style: TextStyle(color: Colors.white70, fontSize: 20)),
            const SizedBox(height: 70),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(children: [
                  round(Icons.call_end, Colors.red, s.hangUp, size: 78),
                  const SizedBox(height: 8),
                  const Text('کاٹیں',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ]),
                Column(children: [
                  round(Icons.call, _green, s.accept, size: 78),
                  const SizedBox(height: 8),
                  const Text('اٹھائیں',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final inCall = s.phase == CallPhase.outgoing ||
            s.phase == CallPhase.connecting ||
            s.phase == CallPhase.connected;
        final showNote = !inCall && s.phase == CallPhase.idle && s.note != null;
        final top = inCall || showNote;
        return Stack(
          children: [
            Column(
              children: [
                inCall
                    ? banner()
                    : (showNote ? noteBar() : const SizedBox.shrink()),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: top,
                    child: widget.child,
                  ),
                ),
              ],
            ),
            s.phase == CallPhase.incoming
                ? Positioned.fill(child: incoming())
                : const SizedBox.shrink(),
          ],
        );
      },
    );
  }
}
