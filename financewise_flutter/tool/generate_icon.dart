import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Generates a modern FinanceWise app icon as a 1024x1024 PNG.
/// Run: dart run tool/generate_icon.dart
void main() {
  const size = 1024;
  final image = img.Image(width: size, height: size);
  final fgImage = img.Image(width: size, height: size);

  // ── Background: teal gradient ──
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final t = (x + y) / (2 * size);
      final r = _lerp(13, 20, t);
      final g = _lerp(148, 184, t);
      final b = _lerp(136, 166, t);
      image.setPixelRgba(x, y, r, g, b, 255);
      fgImage.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }

  final cx = size ~/ 2;
  final cy = size ~/ 2;

  // ── White rounded wallet shape ──
  _drawRoundedRect(image, cx - 220, cy - 180, cx + 220, cy + 180, 60, 255, 255, 255, 255);
  _drawRoundedRect(fgImage, cx - 220, cy - 180, cx + 220, cy + 180, 60, 255, 255, 255, 255);

  // ── Inner teal area ──
  _drawRoundedRect(image, cx - 180, cy - 145, cx + 180, cy + 100, 40, 13, 148, 136, 255);
  _drawRoundedRect(fgImage, cx - 180, cy - 145, cx + 180, cy + 100, 40, 13, 148, 136, 255);

  // ── Growth arrow (white) ──
  _drawThickLine(image, cx - 130, cy + 20, cx - 40, cy - 80, 18, 255, 255, 255);
  _drawThickLine(image, cx - 40, cy - 80, cx + 40, cy - 20, 18, 255, 255, 255);
  _drawThickLine(image, cx + 40, cy - 20, cx + 130, cy - 100, 18, 255, 255, 255);
  _drawThickLine(fgImage, cx - 130, cy + 20, cx - 40, cy - 80, 18, 255, 255, 255);
  _drawThickLine(fgImage, cx - 40, cy - 80, cx + 40, cy - 20, 18, 255, 255, 255);
  _drawThickLine(fgImage, cx + 40, cy - 20, cx + 130, cy - 100, 18, 255, 255, 255);

  // Arrow head
  _drawThickLine(image, cx + 80, cy - 100, cx + 130, cy - 100, 18, 255, 255, 255);
  _drawThickLine(image, cx + 130, cy - 100, cx + 130, cy - 50, 18, 255, 255, 255);
  _drawThickLine(fgImage, cx + 80, cy - 100, cx + 130, cy - 100, 18, 255, 255, 255);
  _drawThickLine(fgImage, cx + 130, cy - 100, cx + 130, cy - 50, 18, 255, 255, 255);

  // ── Coin circle (bottom right) ──
  _drawFilledCircle(image, cx + 130, cy + 110, 70, 255, 255, 255);
  _drawFilledCircle(image, cx + 130, cy + 110, 52, 13, 148, 136);
  _drawFilledCircle(fgImage, cx + 130, cy + 110, 70, 255, 255, 255);
  _drawFilledCircle(fgImage, cx + 130, cy + 110, 52, 13, 148, 136);

  // ── F letter inside coin ──
  _drawThickLine(image, cx + 115, cy + 88, cx + 115, cy + 132, 10, 255, 255, 255);
  _drawThickLine(image, cx + 115, cy + 88, cx + 148, cy + 88, 10, 255, 255, 255);
  _drawThickLine(image, cx + 115, cy + 108, cx + 140, cy + 108, 8, 255, 255, 255);
  _drawThickLine(fgImage, cx + 115, cy + 88, cx + 115, cy + 132, 10, 255, 255, 255);
  _drawThickLine(fgImage, cx + 115, cy + 88, cx + 148, cy + 88, 10, 255, 255, 255);
  _drawThickLine(fgImage, cx + 115, cy + 108, cx + 140, cy + 108, 8, 255, 255, 255);

  // ── Save ──
  final dir = Directory('assets/icon');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(image));
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(fgImage));
  print('Icons generated in assets/icon/');
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);

void _drawRoundedRect(img.Image image, int x1, int y1, int x2, int y2, int radius, int r, int g, int b, int a) {
  for (int y = y1; y <= y2; y++) {
    for (int x = x1; x <= x2; x++) {
      if (x < 0 || x >= image.width || y < 0 || y >= image.height) continue;
      // Check if inside rounded corners
      bool inside = true;
      if (x < x1 + radius && y < y1 + radius) {
        inside = _dist(x, y, x1 + radius, y1 + radius) <= radius;
      } else if (x > x2 - radius && y < y1 + radius) {
        inside = _dist(x, y, x2 - radius, y1 + radius) <= radius;
      } else if (x < x1 + radius && y > y2 - radius) {
        inside = _dist(x, y, x1 + radius, y2 - radius) <= radius;
      } else if (x > x2 - radius && y > y2 - radius) {
        inside = _dist(x, y, x2 - radius, y2 - radius) <= radius;
      }
      if (inside) image.setPixelRgba(x, y, r, g, b, a);
    }
  }
}

double _dist(int x1, int y1, int x2, int y2) {
  return sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

void _drawFilledCircle(img.Image image, int cx, int cy, int radius, int r, int g, int b) {
  for (int y = cy - radius; y <= cy + radius; y++) {
    for (int x = cx - radius; x <= cx + radius; x++) {
      if (x < 0 || x >= image.width || y < 0 || y >= image.height) continue;
      if (_dist(x, y, cx, cy) <= radius) {
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }
}

void _drawThickLine(img.Image image, int x1, int y1, int x2, int y2, int thickness, int r, int g, int b) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final steps = max(dx.abs(), dy.abs());
  if (steps == 0) return;
  for (int i = 0; i <= steps; i++) {
    final x = x1 + (dx * i / steps).round();
    final y = y1 + (dy * i / steps).round();
    _drawFilledCircle(image, x, y, thickness ~/ 2, r, g, b);
  }
}
