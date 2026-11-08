import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call.dart';

class VideoCallView extends StatefulWidget {
  const VideoCallView({super.key});

  @override
  State<VideoCallView> createState() => _VideoCallViewState();
}

class _VideoCallViewState extends State<VideoCallView> {
  final s = CallService.instance;
  final remoteR = RTCVideoRenderer();
  final localR = RTCVideoRenderer();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await remoteR.initialize();
    await localR.initialize();
    if (!mounted) return;
    ready = true;
    s.addListener(sync);
    sync();
  }

  void sync() {
    if (!mounted || !ready) return;
    if (remoteR.srcObject != s.remoteStream) {
      remoteR.srcObject = s.remoteStream;
    }
    if (localR.srcObject != s.localStream) {
      localR.srcObject = s.localStream;
    }
    setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(sync);
    remoteR.srcObject = null;
    localR.srcObject = null;
    remoteR.dispose();
    localR.dispose();
    super.dispose();
  }

  String clock(int t) {
    final m = (t ~/ 60).toString().padLeft(2, '0');
    final x = (t % 60).toString().padLeft(2, '0');
    return '$m:$x';
  }

  Widget round(IconData icon, Color bg, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRemote = s.remoteStream != null;
    final status = s.phase == CallPhase.outgoing
        ? 'گھنٹی جا رہی ہے…'
        : (s.phase == CallPhase.connecting
            ? 'جڑ رہا ہے… ${s.ice}'
            : clock(s.seconds));
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          if (ready)
            Positioned.fill(
              child: RTCVideoView(hasRemote ? remoteR : localR,
                  mirror: !hasRemote,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
          if (ready && hasRemote)
            Positioned(
              top: 60,
              right: 12,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(localR,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(s.otherName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black)
                              ])),
                      Text(status,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black)
                              ])),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      round(s.muted ? Icons.mic_off : Icons.mic,
                          s.muted ? Colors.orange : Colors.white24,
                          s.toggleMute),
                      round(s.camOff ? Icons.videocam_off : Icons.videocam,
                          s.camOff ? Colors.orange : Colors.white24,
                          s.toggleCam),
                      round(Icons.cameraswitch, Colors.white24, s.flipCam),
                      round(s.speaker ? Icons.volume_up : Icons.hearing,
                          s.speaker ? Colors.orange : Colors.white24,
                          s.toggleSpeaker),
                      round(Icons.call_end, Colors.red, s.hangUp),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
