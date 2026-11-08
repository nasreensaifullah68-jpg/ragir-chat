import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'filter.dart';
import 'look.dart';
import 'main.dart';

class LiveCameraScreen extends StatefulWidget {
  final bool hd;
  const LiveCameraScreen({super.key, this.hd = false});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> cams = [];
  CameraController? ctl;
  int idx = 0;
  int sel = 0;
  bool busy = false;
  bool night = false;
  String? err;
  FlashMode flash = FlashMode.off;
  double expMin = 0, expMax = 0, exp = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ctl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final c = ctl;
      ctl = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && ctl == null) {
      open();
    }
  }

  Future<void> start() async {
    try {
      cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => err = 'کوئی کیمرا نہیں ملا');
        return;
      }
      await open();
    } catch (e) {
      if (mounted) setState(() => err = 'کیمرا نہیں کھلا۔ اجازت دیں: $e');
    }
  }

  Future<void> open() async {
    final old = ctl;
    ctl = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final c = CameraController(
      cams[idx],
      widget.hd ? ResolutionPreset.veryHigh : ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
      await c.setFlashMode(flash);
      expMin = await c.getMinExposureOffset();
      expMax = await c.getMaxExposureOffset();
      exp = 0;
      if (night) await c.setExposureOffset(expMax * 0.7);
    } catch (e) {
      await c.dispose();
      if (mounted) setState(() => err = 'کیمرا نہیں کھلا۔ اجازت دیں: $e');
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      ctl = c;
      err = null;
    });
  }

  Future<void> shoot() async {
    final c = ctl;
    if (c == null || busy) return;
    setState(() => busy = true);
    try {
      final x = await c.takePicture();
      startFilter = sel;
      if (!mounted) return;
      Navigator.pop(context, x.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      showMsg(context, 'تصویر نہیں بنی: $e');
    }
  }

  Future<void> flip() async {
    if (cams.length < 2) return;
    idx = (idx + 1) % cams.length;
    await open();
  }

  Future<void> cycleFlash() async {
    final c = ctl;
    if (c == null) return;
    flash = flash == FlashMode.off
        ? FlashMode.auto
        : flash == FlashMode.auto
            ? FlashMode.always
            : FlashMode.off;
    try {
      await c.setFlashMode(flash);
    } catch (_) {}
    setState(() {});
  }

  Future<void> toggleNight() async {
    final c = ctl;
    if (c == null) return;
    night = !night;
    exp = night ? expMax * 0.7 : 0;
    try {
      await c.setExposureOffset(exp);
    } catch (_) {}
    setState(() {});
  }

  Future<void> setExp(double v) async {
    exp = v;
    setState(() {});
    try {
      await ctl?.setExposureOffset(v);
    } catch (_) {}
  }

  IconData get flashIcon => flash == FlashMode.off
      ? Icons.flash_off
      : flash == FlashMode.auto
          ? Icons.flash_auto
          : Icons.flash_on;

  Widget preview() {
    final c = ctl;
    if (err != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(err!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18)),
      ));
    }
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ClipRect(
      child: Center(
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(photoFilters[sel].m),
          child: CameraPreview(c),
        ),
      ),
    );
  }

  Widget filterStrip() {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: photoFilters.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => setState(() => sel = i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == sel ? green : Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(photoFilters[i].name,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canExp = expMax > expMin;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                IconButton(
                  color: night ? Colors.amber : Colors.white,
                  icon: const Icon(Icons.nightlight_round),
                  onPressed: toggleNight,
                ),
                IconButton(
                  color: Colors.white,
                  icon: Icon(flashIcon),
                  onPressed: cycleFlash,
                ),
              ],
            ),
            Expanded(child: preview()),
            if (canExp)
              Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.wb_sunny, color: Colors.white, size: 20),
                  Expanded(
                    child: Slider(
                      value: exp.clamp(expMin, expMax).toDouble(),
                      min: expMin,
                      max: expMax,
                      activeColor: Colors.greenAccent,
                      onChanged: setExp,
                    ),
                  ),
                ],
              ),
            filterStrip(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 56),
                  GestureDetector(
                    onTap: busy ? null : shoot,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: busy ? Colors.grey : Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: IconButton(
                      color: Colors.white,
                      iconSize: 34,
                      icon: const Icon(Icons.cameraswitch),
                      onPressed: flip,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
