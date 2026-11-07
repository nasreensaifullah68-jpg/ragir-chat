import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum CallPhase { idle, outgoing, incoming, connecting, connected }

class CallService extends ChangeNotifier {
  CallService._();
  static final CallService instance = CallService._();

  CallPhase phase = CallPhase.idle;
  String otherName = '';
  String otherId = '';
  String? note;
  bool muted = false;
  bool speaker = false;
  int seconds = 0;

  String? _callId;
  String _role = 'caller';
  DocumentReference<Map<String, dynamic>>? _ref;
  RTCPeerConnection? _pc;
  MediaStream? _local;
  StreamSubscription<dynamic>? _inSub;
  StreamSubscription<dynamic>? _callSub;
  StreamSubscription<dynamic>? _candSub;
  Timer? _timer;
  Timer? _ringTimer;
  Timer? _noteTimer;
  bool _answerSet = false;
  bool _docReady = false;
  final List<Map<String, dynamic>> _pending = [];
  Map<String, dynamic>? _offer;

  final Map<String, dynamic> _config = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      }
    ],
    'sdpSemantics': 'unified-plan',
  };

  CollectionReference<Map<String, dynamic>> get _calls =>
      FirebaseFirestore.instance.collection('calls');

  void _say(String t) {
    note = t;
    notifyListeners();
    _noteTimer?.cancel();
    _noteTimer = Timer(const Duration(seconds: 5), () {
      note = null;
      notifyListeners();
    });
  }

  void listen(String uid) {
    _inSub?.cancel();
    _inSub = _calls
        .where('calleeId', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((s) {
      for (final d in s.docs) {
        if (d.id == _callId) continue;
        final data = d.data();
        final ts = data['createdAt'] as Timestamp?;
        if (ts != null &&
            DateTime.now().difference(ts.toDate()).inSeconds.abs() > 900) {
          continue;
        }
        if (phase != CallPhase.idle) {
          d.reference.update({'status': 'busy'});
          continue;
        }
        _callId = d.id;
        _ref = d.reference;
        _role = 'callee';
        _offer = Map<String, dynamic>.from(data['offer'] as Map);
        otherName = (data['callerName'] as String?) ?? 'نامعلوم';
        otherId = (data['callerId'] as String?) ?? '';
        phase = CallPhase.incoming;
        _ringTimer?.cancel();
        _ringTimer = Timer(const Duration(seconds: 55), () {
          if (phase == CallPhase.incoming) hangUp();
        });
        _watch();
        notifyListeners();
      }
    }, onError: (e) {
      _say('آنے والی کال سننے میں خرابی: $e');
      Timer(const Duration(seconds: 8), () {
        if (_inSub != null) listen(uid);
      });
    });
  }

  Future<void> stop() async {
    await _inSub?.cancel();
    _inSub = null;
    if (phase != CallPhase.idle) await hangUp();
  }

  Future<void> _openMic() async {
    _local = await navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});
  }

  Future<void> _makePc() async {
    _answerSet = false;
    final pc = await createPeerConnection(_config);
    _pc = pc;
    for (final t in _local!.getAudioTracks()) {
      await pc.addTrack(t, _local!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _sendCand(Map<String, dynamic>.from(c.toMap() as Map));
    };
    pc.onTrack = (e) {
      e.track.enabled = true;
    };
    pc.onIceConnectionState = (st) {
      if (st == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          st == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        if (phase == CallPhase.connecting || phase == CallPhase.outgoing) {
          phase = CallPhase.connected;
          seconds = 0;
          speaker = true;
          try {
            Helper.setSpeakerphoneOn(true);
          } catch (_) {}
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            seconds++;
            notifyListeners();
          });
          notifyListeners();
        }
      } else if (st == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _say('کنکشن ٹوٹ گیا');
        hangUp();
      }
    };
  }

  Future<void> _sendCand(Map<String, dynamic> m) async {
    if (!_docReady) {
      _pending.add(m);
      return;
    }
    try {
      await _ref?.collection('cands').add({'from': _role, 'c': m});
    } catch (_) {}
  }

  void _listenCands(String from) {
    _candSub?.cancel();
    _candSub = _ref!
        .collection('cands')
        .where('from', isEqualTo: from)
        .snapshots()
        .listen((s) {
      for (final ch in s.docChanges) {
        if (ch.type != DocumentChangeType.added) continue;
        final c = ch.doc.data()?['c'] as Map?;
        if (c == null) continue;
        _pc?.addCandidate(RTCIceCandidate(c['candidate'] as String?,
            c['sdpMid'] as String?, c['sdpMLineIndex'] as int?));
      }
    }, onError: (_) {});
  }

  void _watch() {
    _callSub?.cancel();
    _callSub = _ref!.snapshots().listen((s) async {
      final d = s.data();
      if (d == null) {
        await _cleanup();
        return;
      }
      final st = d['status'];
      if (st == 'ringing' || st == 'active') {
        if (_role == 'caller' && !_answerSet && d['answer'] != null) {
          _answerSet = true;
          _ringTimer?.cancel();
          phase = CallPhase.connecting;
          notifyListeners();
          final a = Map<String, dynamic>.from(d['answer'] as Map);
          await _pc?.setRemoteDescription(RTCSessionDescription(
              a['sdp'] as String?, a['type'] as String?));
          _listenCands('callee');
        }
      } else if (phase != CallPhase.idle) {
        final texts = {
          'declined': 'کال قبول نہیں ہوئی',
          'busy': 'وہ دوسری کال پر ہیں',
          'missed': 'کال چھوٹ گئی',
          'ended': 'کال ختم ہو گئی',
        };
        await _cleanup();
        _say(texts[st] ?? 'کال ختم ہو گئی');
      }
    }, onError: (_) {});
  }

  Future<void> startCall(String otherId, String name) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || phase != CallPhase.idle) return;
    otherName = name;
    this.otherId = otherId;
    _role = 'caller';
    phase = CallPhase.outgoing;
    notifyListeners();
    try {
      final mine = await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .get();
      final myName = (mine.data()?['name'] as String?) ?? 'کوئی';
      await _openMic();
      final ref = _calls.doc();
      _ref = ref;
      _callId = ref.id;
      _docReady = false;
      await _makePc();
      final offer = await _pc!.createOffer({});
      await _pc!.setLocalDescription(offer);
      await ref.set({
        'callerId': me.uid,
        'calleeId': otherId,
        'callerName': myName,
        'calleeName': name,
        'status': 'ringing',
        'offer': {'sdp': offer.sdp, 'type': offer.type},
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (_ref != ref) {
        try {
          await ref.update({'status': 'missed'});
        } catch (_) {}
        return;
      }
      _docReady = true;
      for (final m in _pending) {
        _sendCand(m);
      }
      _pending.clear();
      _watch();
      _ringTimer = Timer(const Duration(seconds: 50), () {
        if (phase == CallPhase.outgoing) hangUp();
      });
    } catch (e) {
      await _cleanup();
      _say('کال نہیں لگ سکی: $e');
    }
  }

  Future<void> accept() async {
    if (phase != CallPhase.incoming || _ref == null) return;
    _ringTimer?.cancel();
    phase = CallPhase.connecting;
    notifyListeners();
    try {
      await _openMic();
      _docReady = true;
      await _makePc();
      await _pc!.setRemoteDescription(RTCSessionDescription(
          _offer!['sdp'] as String?, _offer!['type'] as String?));
      final ans = await _pc!.createAnswer({});
      await _pc!.setLocalDescription(ans);
      await _ref!.update({
        'answer': {'sdp': ans.sdp, 'type': ans.type},
        'status': 'active',
      });
      _listenCands('caller');
    } catch (e) {
      await hangUp();
      _say('کال نہیں جڑ سکی: $e');
    }
  }

  Future<void> hangUp() async {
    if (phase == CallPhase.idle) return;
    final st = phase == CallPhase.incoming
        ? 'declined'
        : (phase == CallPhase.outgoing ? 'missed' : 'ended');
    final ref = _ref;
    await _cleanup();
    try {
      await ref?.update({'status': st});
    } catch (_) {}
  }

  void toggleMute() {
    muted = !muted;
    for (final t in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    notifyListeners();
  }

  void toggleSpeaker() {
    speaker = !speaker;
    try {
      Helper.setSpeakerphoneOn(speaker);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _cleanup() async {
    _callSub?.cancel();
    _candSub?.cancel();
    _timer?.cancel();
    _ringTimer?.cancel();
    _callSub = null;
    _candSub = null;
    _timer = null;
    _ringTimer = null;
    try {
      for (final t in _local?.getTracks() ?? <MediaStreamTrack>[]) {
        t.stop();
      }
      await _local?.dispose();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    _local = null;
    _pc = null;
    _ref = null;
    _callId = null;
    _pending.clear();
    _docReady = false;
    muted = false;
    speaker = false;
    otherId = '';
    seconds = 0;
    phase = CallPhase.idle;
    notifyListeners();
    try {
      Helper.setSpeakerphoneOn(false);
    } catch (_) {}
  }
}
