part of 'call.dart';

extension CallControls on CallService {
  void toggleMute() {
    muted = !muted;
    for (final t in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    notifyListeners();
  }

  void toggleCam() {
    camOff = !camOff;
    for (final t in _local?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !camOff;
    }
    notifyListeners();
  }

  Future<void> flipCam() async {
    final v = _local?.getVideoTracks();
    if (v == null || v.isEmpty) return;
    try {
      await Helper.switchCamera(v.first);
    } catch (_) {}
  }

  void toggleSpeaker() {
    speaker = !speaker;
    try {
      Helper.setSpeakerphoneOn(speaker);
    } catch (_) {}
    notifyListeners();
  }
}
