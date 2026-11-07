import 'dart:math' as math;
import 'dart:typed_data';

List<double> satMatrix(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return [
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> lookMatrix({
  double sat = 1,
  double contrast = 1,
  double bright = 0,
  double r = 1,
  double g = 1,
  double b = 1,
}) {
  final s = satMatrix(sat);
  final gains = [r, g, b];
  final off = 255 * (0.5 - 0.5 * contrast) + bright;
  final out = <double>[];
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 5; j++) {
      out.add(j == 4 ? off : s[i * 5 + j] * gains[i] * contrast);
    }
  }
  out.addAll([0, 0, 0, 1, 0]);
  return out;
}

class PhotoFilter {
  final String name;
  final List<double> m;
  const PhotoFilter(this.name, this.m);
}

final List<PhotoFilter> photoFilters = [
  const PhotoFilter('اصل', [
    1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]),
  PhotoFilter('DSLR', lookMatrix(sat: 1.15, contrast: 1.12, bright: 6)),
  PhotoFilter('iPhone', lookMatrix(
      sat: 1.3, contrast: 1.1, bright: 10, r: 1.03, g: 1.0, b: 0.97)),
  PhotoFilter('پورٹریٹ', lookMatrix(
      sat: 1.05, contrast: 1.05, bright: 14, r: 1.04, g: 1.01, b: 0.98)),
  PhotoFilter('سنیما', lookMatrix(
      sat: 0.9, contrast: 1.2, bright: -4, r: 1.06, g: 1.0, b: 0.9)),
  PhotoFilter('سنہری', lookMatrix(
      sat: 1.2, contrast: 1.08, bright: 10, r: 1.1, g: 1.03, b: 0.85)),
  PhotoFilter('ٹھنڈا', lookMatrix(
      sat: 1.1, contrast: 1.1, bright: 4, r: 0.9, g: 1.0, b: 1.15)),
  PhotoFilter('HDR', lookMatrix(sat: 1.35, contrast: 1.3, bright: -8)),
  PhotoFilter('فلم', lookMatrix(
      sat: 0.8, contrast: 1.05, bright: 14, r: 1.08, g: 1.0, b: 0.88)),
  PhotoFilter('کالا سفید', lookMatrix(sat: 0, contrast: 1.2, bright: 0)),
  const PhotoFilter('سیپیا', [
    0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534,
    0.131, 0, 0, 0, 0, 0, 1, 0]),
];

class EnhanceJob {
  final Uint8List px;
  final double amount;
  EnhanceJob(this.px, this.amount);
}

Uint8List enhancePixels(EnhanceJob job) {
  final px = job.px;
  if (px.length < 64) return px;
  var sum = 0.0;
  var n = 0;
  for (var i = 0; i < px.length - 3; i += 64) {
    sum += 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
    n++;
  }
  final mean = (sum / n / 255).clamp(0.03, 0.99).toDouble();
  var gamma = (math.log(0.46) / math.log(mean)).clamp(0.4, 1.0).toDouble();
  gamma = 1 - (1 - gamma) * job.amount;
  if (gamma >= 0.99) return px;
  final lut = Uint8List(256);
  for (var i = 0; i < 256; i++) {
    var x = math.pow(i / 255, gamma).toDouble();
    x = (x - 0.5) * 1.06 + 0.5 + 0.02;
    lut[i] = (x.clamp(0.0, 1.0) * 255).round();
  }
  final out = Uint8List.fromList(px);
  for (var i = 0; i < out.length - 3; i += 4) {
    out[i] = lut[out[i]];
    out[i + 1] = lut[out[i + 1]];
    out[i + 2] = lut[out[i + 2]];
  }
  return out;
}
