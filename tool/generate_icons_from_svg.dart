// ============================================================
// Generate App Icons from SVG
// ============================================================
// Usage:
//   dart run tool/generate_icons_from_svg.dart <path_to_svg>
//
// Example:
//   dart run tool/generate_icons_from_svg.dart assets/icon/app_icon.svg
//
// What it does:
//   1. Reads an SVG file
//   2. Generates PNG icons at ALL required sizes for Android + iOS
//   3. Also generates 1024x1024 master PNGs for flutter_launcher_icons
//
// After running this script, you can also run:
//   dart run flutter_launcher_icons
// to update the Android adaptive icons and iOS Assets catalog.
// ============================================================

import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run tool/generate_icons_from_svg.dart <path_to_svg>');
    print('Example: dart run tool/generate_icons_from_svg.dart assets/icon/app_icon.svg');
    exit(1);
  }

  final svgPath = args[0];
  final svgFile = File(svgPath);
  if (!svgFile.existsSync()) {
    print('Error: SVG file not found: $svgPath');
    exit(1);
  }

  final svgContent = svgFile.readAsStringSync();

  // Parse SVG dimensions
  final viewBox = _parseViewBox(svgContent);
  print('SVG viewBox: ${viewBox.width}x${viewBox.height}');

  // ─── Android Icon Sizes ─────────────────────────
  final androidIcons = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  // Android adaptive icon foreground (with padding)
  final androidForeground = {
    'drawable-mdpi': 108,
    'drawable-hdpi': 162,
    'drawable-xhdpi': 216,
    'drawable-xxhdpi': 324,
    'drawable-xxxhdpi': 432,
  };

  // ─── iOS Icon Sizes ─────────────────────────────
  final iosIcons = {
    'Icon-App-20x20@1x': 20,
    'Icon-App-20x20@2x': 40,
    'Icon-App-20x20@3x': 60,
    'Icon-App-29x29@1x': 29,
    'Icon-App-29x29@2x': 58,
    'Icon-App-29x29@3x': 87,
    'Icon-App-40x40@1x': 40,
    'Icon-App-40x40@2x': 80,
    'Icon-App-40x40@3x': 120,
    'Icon-App-50x50@1x': 50,
    'Icon-App-50x50@2x': 100,
    'Icon-App-57x57@1x': 57,
    'Icon-App-57x57@2x': 114,
    'Icon-App-60x60@2x': 120,
    'Icon-App-60x60@3x': 180,
    'Icon-App-72x72@1x': 72,
    'Icon-App-72x72@2x': 144,
    'Icon-App-76x76@1x': 76,
    'Icon-App-76x76@2x': 152,
    'Icon-App-83.5x83.5@2x': 167,
    'Icon-App-1024x1024@1x': 1024,
  };

  // ─── Generate master 1024x1024 PNGs ─────────────
  print('\n📐 Generating master PNGs (1024x1024)...');
  final masterPng = _svgToPng(svgContent, viewBox, 1024, 1024);
  _writeFile('assets/icon/app_icon.png', masterPng);
  _writeFile('assets/icon/app_icon_foreground.png', masterPng);

  // ─── Generate Android mipmap icons ──────────────
  print('\n🤖 Generating Android mipmap icons...');
  for (final entry in androidIcons.entries) {
    final dir = 'android/app/src/main/res/${entry.key}';
    final size = entry.value;
    final png = _svgToPng(svgContent, viewBox, size, size);
    _writeFile('$dir/ic_launcher.png', png);
  }

  // ─── Generate Android adaptive foreground ───────
  print('\n🤖 Generating Android adaptive foreground icons...');
  for (final entry in androidForeground.entries) {
    final dir = 'android/app/src/main/res/${entry.key}';
    final size = entry.value;
    final png = _svgToPng(svgContent, viewBox, size, size);
    _writeFile('$dir/ic_launcher_foreground.png', png);
  }

  // ─── Generate iOS icons ─────────────────────────
  print('\n🍎 Generating iOS icons...');
  final iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final entry in iosIcons.entries) {
    final size = entry.value;
    final png = _svgToPng(svgContent, viewBox, size, size);
    _writeFile('$iosDir/${entry.key}.png', png);
  }

  // ─── Summary ────────────────────────────────────
  final totalIcons = androidIcons.length + androidForeground.length + iosIcons.length + 2;
  print('\n✅ Generated $totalIcons icon files from SVG');
  print('\n💡 Tip: You can also run `dart run flutter_launcher_icons` to');
  print('   regenerate using the flutter_launcher_icons config in pubspec.yaml');
}

// ─── SVG to PNG Conversion (Pure Dart) ───────────────────────
// Since we can't use Flutter's rendering engine in a CLI script,
// we create proper PNGs by rasterizing SVG paths manually.
// For complex SVGs, this generates a colored-background icon.
// For production quality, export a 1024x1024 PNG from Figma/Illustrator.

Uint8List _svgToPng(String svgContent, _ViewBox vb, int width, int height) {
  // Extract background color from SVG (rect fill or default gold)
  final bgColor = _extractBackgroundColor(svgContent);

  // Extract foreground elements and render
  final pixels = _rasterizeSvg(svgContent, vb, width, height, bgColor);

  return _encodePng(width, height, pixels);
}

// ─── SVG Parsing Helpers ─────────────────────────────────────

class _ViewBox {
  final double x, y, width, height;
  _ViewBox(this.x, this.y, this.width, this.height);
}

class _Color {
  final int r, g, b, a;
  const _Color(this.r, this.g, this.b, [this.a = 255]);

  static const gold = _Color(0xE5, 0xA8, 0x21);
  static const white = _Color(255, 255, 255);
  static const transparent = _Color(0, 0, 0, 0);
}

_ViewBox _parseViewBox(String svg) {
  // Try viewBox attribute
  final vbMatch = RegExp(r'viewBox\s*=\s*"([^"]*)"').firstMatch(svg);
  if (vbMatch != null) {
    final parts = vbMatch.group(1)!.trim().split(RegExp(r'[\s,]+'));
    if (parts.length == 4) {
      return _ViewBox(
        double.parse(parts[0]),
        double.parse(parts[1]),
        double.parse(parts[2]),
        double.parse(parts[3]),
      );
    }
  }

  // Fallback: try width/height attributes
  final wMatch = RegExp(r'<svg[^>]+width\s*=\s*"(\d+)"').firstMatch(svg);
  final hMatch = RegExp(r'<svg[^>]+height\s*=\s*"(\d+)"').firstMatch(svg);
  final w = wMatch != null ? double.parse(wMatch.group(1)!) : 100.0;
  final h = hMatch != null ? double.parse(hMatch.group(1)!) : 100.0;
  return _ViewBox(0, 0, w, h);
}

_Color _extractBackgroundColor(String svg) {
  // Look for a background rect
  final rectMatch = RegExp(
    r'<rect[^>]*fill\s*=\s*"([^"]*)"[^>]*/?>',
    caseSensitive: false,
  ).firstMatch(svg);

  if (rectMatch != null) {
    return _parseColor(rectMatch.group(1)!);
  }

  // Check for style fill on svg element
  final svgFill = RegExp(
    r'<svg[^>]*(?:fill|style\s*=\s*"[^"]*background[^"]*)\s*[:=]\s*"?([#\w]+)',
    caseSensitive: false,
  ).firstMatch(svg);

  if (svgFill != null) {
    return _parseColor(svgFill.group(1)!);
  }

  return _Color.transparent;
}

_Color _parseColor(String color) {
  color = color.trim().toLowerCase();

  // Named colors
  final named = {
    'white': _Color.white,
    'black': const _Color(0, 0, 0),
    'red': const _Color(255, 0, 0),
    'green': const _Color(0, 128, 0),
    'blue': const _Color(0, 0, 255),
    'gold': _Color.gold,
    'none': _Color.transparent,
    'transparent': _Color.transparent,
  };
  if (named.containsKey(color)) return named[color]!;

  // Hex color
  if (color.startsWith('#')) {
    final hex = color.substring(1);
    if (hex.length == 3) {
      final r = int.parse('${hex[0]}${hex[0]}', radix: 16);
      final g = int.parse('${hex[1]}${hex[1]}', radix: 16);
      final b = int.parse('${hex[2]}${hex[2]}', radix: 16);
      return _Color(r, g, b);
    } else if (hex.length == 6) {
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);
      return _Color(r, g, b);
    } else if (hex.length == 8) {
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);
      final a = int.parse(hex.substring(6, 8), radix: 16);
      return _Color(r, g, b, a);
    }
  }

  // rgb() / rgba()
  final rgbMatch = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)').firstMatch(color);
  if (rgbMatch != null) {
    return _Color(
      int.parse(rgbMatch.group(1)!),
      int.parse(rgbMatch.group(2)!),
      int.parse(rgbMatch.group(3)!),
    );
  }

  return _Color.gold; // Default fallback
}

// ─── SVG Rasterizer ──────────────────────────────────────────
// Parses circles, ellipses, rects, and paths from SVG and renders
// them onto a pixel buffer.

Uint8List _rasterizeSvg(String svg, _ViewBox vb, int w, int h, _Color bg) {
  final pixels = Uint8List(w * h * 4);

  // Fill background
  for (var i = 0; i < w * h; i++) {
    pixels[i * 4 + 0] = bg.r;
    pixels[i * 4 + 1] = bg.g;
    pixels[i * 4 + 2] = bg.b;
    pixels[i * 4 + 3] = bg.a;
  }

  final scaleX = w / vb.width;
  final scaleY = h / vb.height;

  // Render circles
  for (final match in RegExp(
    r'<circle[^>]*cx\s*=\s*"([^"]*)"[^>]*cy\s*=\s*"([^"]*)"[^>]*r\s*=\s*"([^"]*)"[^>]*',
    caseSensitive: false,
  ).allMatches(svg)) {
    final cx = double.parse(match.group(1)!) * scaleX;
    final cy = double.parse(match.group(2)!) * scaleY;
    final r = double.parse(match.group(3)!) * ((scaleX + scaleY) / 2);
    final fillStr = RegExp(r'fill\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
    final fill = fillStr != null ? _parseColor(fillStr.group(1)!) : _Color.white;
    _drawCircle(pixels, w, h, cx, cy, r, fill);
  }

  // Render ellipses
  for (final match in RegExp(
    r'<ellipse[^>]*cx\s*=\s*"([^"]*)"[^>]*cy\s*=\s*"([^"]*)"[^>]*rx\s*=\s*"([^"]*)"[^>]*ry\s*=\s*"([^"]*)"[^>]*',
    caseSensitive: false,
  ).allMatches(svg)) {
    final cx = double.parse(match.group(1)!) * scaleX;
    final cy = double.parse(match.group(2)!) * scaleY;
    final rx = double.parse(match.group(3)!) * scaleX;
    final ry = double.parse(match.group(4)!) * scaleY;
    final fillStr = RegExp(r'fill\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
    final fill = fillStr != null ? _parseColor(fillStr.group(1)!) : _Color.white;
    _drawEllipse(pixels, w, h, cx, cy, rx, ry, fill);
  }

  // Render rects (skip first rect if it's the background)
  var isFirst = true;
  for (final match in RegExp(
    r'<rect[^>]*/>',
    caseSensitive: false,
  ).allMatches(svg)) {
    if (isFirst) {
      isFirst = false;
      // Check if this rect covers the full viewBox (background)
      final rw = RegExp(r'width\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
      final rh = RegExp(r'height\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
      if (rw != null && rh != null) {
        final rectW = double.tryParse(rw.group(1)!.replaceAll('%', '')) ?? 0;
        final rectH = double.tryParse(rh.group(1)!.replaceAll('%', '')) ?? 0;
        if (rectW >= vb.width * 0.9 && rectH >= vb.height * 0.9) continue;
      }
    }

    final rx = RegExp(r'\bx\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
    final ry = RegExp(r'\by\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
    final rw = RegExp(r'width\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
    final rh = RegExp(r'height\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
    final rrx = RegExp(r'\brx\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
    final fillStr = RegExp(r'fill\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);

    if (rw != null && rh != null) {
      final x = (rx != null ? double.parse(rx.group(1)!) : 0.0) * scaleX;
      final y = (ry != null ? double.parse(ry.group(1)!) : 0.0) * scaleY;
      final rectW = double.parse(rw.group(1)!) * scaleX;
      final rectH = double.parse(rh.group(1)!) * scaleY;
      final cornerR = rrx != null ? double.parse(rrx.group(1)!) * ((scaleX + scaleY) / 2) : 0.0;
      final fill = fillStr != null ? _parseColor(fillStr.group(1)!) : _Color.white;
      _drawRect(pixels, w, h, x, y, rectW, rectH, cornerR, fill);
    }
  }

  // Render simple path-based shapes (lines/polygons)
  for (final match in RegExp(
    r'<(?:path|polygon)[^>]*(?:d|points)\s*=\s*"([^"]*)"[^>]*',
    caseSensitive: false,
  ).allMatches(svg)) {
    final fillStr = RegExp(r'fill\s*=\s*"([^"]*)"').firstMatch(match.group(0)!);
    final fill = fillStr != null ? _parseColor(fillStr.group(1)!) : _Color.white;
    if (fill.a == 0) continue; // Skip transparent fills

    final pathData = match.group(1)!;
    final points = _parsePathToPoints(pathData, scaleX, scaleY);
    if (points.isNotEmpty) {
      _fillPolygon(pixels, w, h, points, fill);
    }
  }

  return pixels;
}

// ─── Drawing Primitives ──────────────────────────────────────

void _setPixel(Uint8List pixels, int w, int h, int x, int y, _Color c) {
  if (x < 0 || x >= w || y < 0 || y >= h || c.a == 0) return;
  final i = (y * w + x) * 4;
  if (c.a == 255) {
    pixels[i] = c.r;
    pixels[i + 1] = c.g;
    pixels[i + 2] = c.b;
    pixels[i + 3] = 255;
  } else {
    // Alpha blend
    final a = c.a / 255.0;
    final ia = 1.0 - a;
    pixels[i] = (c.r * a + pixels[i] * ia).round();
    pixels[i + 1] = (c.g * a + pixels[i + 1] * ia).round();
    pixels[i + 2] = (c.b * a + pixels[i + 2] * ia).round();
    pixels[i + 3] = 255;
  }
}

void _drawCircle(Uint8List px, int w, int h, double cx, double cy, double r, _Color c) {
  final minY = (cy - r).floor().clamp(0, h - 1);
  final maxY = (cy + r).ceil().clamp(0, h - 1);
  for (var y = minY; y <= maxY; y++) {
    final dy = y - cy;
    final dx = (r * r - dy * dy);
    if (dx < 0) continue;
    final sqrtDx = _sqrt(dx);
    final minX = (cx - sqrtDx).floor().clamp(0, w - 1);
    final maxX = (cx + sqrtDx).ceil().clamp(0, w - 1);
    for (var x = minX; x <= maxX; x++) {
      _setPixel(px, w, h, x, y, c);
    }
  }
}

void _drawEllipse(Uint8List px, int w, int h, double cx, double cy, double rx, double ry, _Color c) {
  final minY = (cy - ry).floor().clamp(0, h - 1);
  final maxY = (cy + ry).ceil().clamp(0, h - 1);
  for (var y = minY; y <= maxY; y++) {
    final dy = (y - cy) / ry;
    final dxNorm = 1.0 - dy * dy;
    if (dxNorm < 0) continue;
    final halfW = rx * _sqrt(dxNorm);
    final minX = (cx - halfW).floor().clamp(0, w - 1);
    final maxX = (cx + halfW).ceil().clamp(0, w - 1);
    for (var x = minX; x <= maxX; x++) {
      _setPixel(px, w, h, x, y, c);
    }
  }
}

void _drawRect(Uint8List px, int w, int h, double rx, double ry, double rw, double rh, double cr, _Color c) {
  final minY = ry.floor().clamp(0, h - 1);
  final maxY = (ry + rh).ceil().clamp(0, h - 1);
  final minX = rx.floor().clamp(0, w - 1);
  final maxX = (rx + rw).ceil().clamp(0, w - 1);

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      if (cr > 0) {
        // Check rounded corners
        final dx = x.toDouble();
        final dy = y.toDouble();
        if (dx < rx + cr && dy < ry + cr) {
          if (_dist(dx, dy, rx + cr, ry + cr) > cr) continue;
        } else if (dx > rx + rw - cr && dy < ry + cr) {
          if (_dist(dx, dy, rx + rw - cr, ry + cr) > cr) continue;
        } else if (dx < rx + cr && dy > ry + rh - cr) {
          if (_dist(dx, dy, rx + cr, ry + rh - cr) > cr) continue;
        } else if (dx > rx + rw - cr && dy > ry + rh - cr) {
          if (_dist(dx, dy, rx + rw - cr, ry + rh - cr) > cr) continue;
        }
      }
      _setPixel(px, w, h, x, y, c);
    }
  }
}

double _dist(double x1, double y1, double x2, double y2) {
  final dx = x1 - x2;
  final dy = y1 - y2;
  return _sqrt(dx * dx + dy * dy);
}

double _sqrt(double x) {
  if (x <= 0) return 0;
  var guess = x / 2;
  for (var i = 0; i < 20; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}

// ─── Path Parsing (simplified M/L/Z commands) ────────────────

List<List<double>> _parsePathToPoints(String pathData, double sx, double sy) {
  final points = <List<double>>[];
  var cx = 0.0, cy = 0.0;

  final tokens = RegExp(r'[MmLlHhVvZzCcSsQqTtAa]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
      .allMatches(pathData)
      .map((m) => m.group(0)!)
      .toList();

  var i = 0;
  var cmd = '';

  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp(r'[A-Za-z]').hasMatch(t)) {
      cmd = t;
      i++;
    }

    switch (cmd) {
      case 'M':
        if (i + 1 < tokens.length) {
          cx = double.parse(tokens[i]) * sx;
          cy = double.parse(tokens[i + 1]) * sy;
          points.add([cx, cy]);
          i += 2;
          cmd = 'L'; // Subsequent coords are L
        }
        break;
      case 'm':
        if (i + 1 < tokens.length) {
          cx += double.parse(tokens[i]) * sx;
          cy += double.parse(tokens[i + 1]) * sy;
          points.add([cx, cy]);
          i += 2;
          cmd = 'l';
        }
        break;
      case 'L':
        if (i + 1 < tokens.length) {
          cx = double.parse(tokens[i]) * sx;
          cy = double.parse(tokens[i + 1]) * sy;
          points.add([cx, cy]);
          i += 2;
        }
        break;
      case 'l':
        if (i + 1 < tokens.length) {
          cx += double.parse(tokens[i]) * sx;
          cy += double.parse(tokens[i + 1]) * sy;
          points.add([cx, cy]);
          i += 2;
        }
        break;
      case 'H':
        cx = double.parse(tokens[i]) * sx;
        points.add([cx, cy]);
        i++;
        break;
      case 'h':
        cx += double.parse(tokens[i]) * sx;
        points.add([cx, cy]);
        i++;
        break;
      case 'V':
        cy = double.parse(tokens[i]) * sy;
        points.add([cx, cy]);
        i++;
        break;
      case 'v':
        cy += double.parse(tokens[i]) * sy;
        points.add([cx, cy]);
        i++;
        break;
      case 'C':
        if (i + 5 < tokens.length) {
          // Cubic bezier - sample a few points
          final x1 = double.parse(tokens[i]) * sx;
          final y1 = double.parse(tokens[i + 1]) * sy;
          final x2 = double.parse(tokens[i + 2]) * sx;
          final y2 = double.parse(tokens[i + 3]) * sy;
          final x3 = double.parse(tokens[i + 4]) * sx;
          final y3 = double.parse(tokens[i + 5]) * sy;
          for (var t = 0.1; t <= 1.0; t += 0.1) {
            final pt = _cubicBezier(cx, cy, x1, y1, x2, y2, x3, y3, t);
            points.add(pt);
          }
          cx = x3;
          cy = y3;
          i += 6;
        }
        break;
      case 'c':
        if (i + 5 < tokens.length) {
          final x1 = cx + double.parse(tokens[i]) * sx;
          final y1 = cy + double.parse(tokens[i + 1]) * sy;
          final x2 = cx + double.parse(tokens[i + 2]) * sx;
          final y2 = cy + double.parse(tokens[i + 3]) * sy;
          final x3 = cx + double.parse(tokens[i + 4]) * sx;
          final y3 = cy + double.parse(tokens[i + 5]) * sy;
          for (var t = 0.1; t <= 1.0; t += 0.1) {
            final pt = _cubicBezier(cx, cy, x1, y1, x2, y2, x3, y3, t);
            points.add(pt);
          }
          cx = x3;
          cy = y3;
          i += 6;
        }
        break;
      case 'Z':
      case 'z':
        if (points.isNotEmpty) {
          points.add([points.first[0], points.first[1]]);
        }
        i++;
        break;
      default:
        i++; // Skip unknown
    }
  }

  return points;
}

List<double> _cubicBezier(
    double x0, double y0, double x1, double y1,
    double x2, double y2, double x3, double y3, double t) {
  final u = 1 - t;
  final x = u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3;
  final y = u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3;
  return [x, y];
}

// ─── Polygon Fill (Scanline) ─────────────────────────────────

void _fillPolygon(Uint8List px, int w, int h, List<List<double>> pts, _Color c) {
  if (pts.length < 3) return;

  var minY = double.infinity, maxY = double.negativeInfinity;
  for (final p in pts) {
    if (p[1] < minY) minY = p[1];
    if (p[1] > maxY) maxY = p[1];
  }

  final yStart = minY.floor().clamp(0, h - 1);
  final yEnd = maxY.ceil().clamp(0, h - 1);

  for (var y = yStart; y <= yEnd; y++) {
    final intersections = <double>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final y0 = pts[i][1], y1 = pts[i + 1][1];
      final x0 = pts[i][0], x1 = pts[i + 1][0];
      if ((y0 <= y && y1 > y) || (y1 <= y && y0 > y)) {
        final t = (y - y0) / (y1 - y0);
        intersections.add(x0 + t * (x1 - x0));
      }
    }
    intersections.sort();
    for (var i = 0; i + 1 < intersections.length; i += 2) {
      final xStart = intersections[i].floor().clamp(0, w - 1);
      final xEnd = intersections[i + 1].ceil().clamp(0, w - 1);
      for (var x = xStart; x <= xEnd; x++) {
        _setPixel(px, w, h, x, y, c);
      }
    }
  }
}

// ─── PNG Encoder ─────────────────────────────────────────────

Uint8List _encodePng(int width, int height, Uint8List pixels) {
  final buffer = BytesBuilder();

  // PNG Signature
  buffer.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR chunk
  final ihdr = BytesBuilder();
  ihdr.add(_uint32(width));
  ihdr.add(_uint32(height));
  ihdr.add([8, 6, 0, 0, 0]); // 8-bit RGBA, no interlace
  _writeChunk(buffer, 'IHDR', ihdr.toBytes());

  // IDAT chunk
  final rawData = BytesBuilder();
  for (var y = 0; y < height; y++) {
    rawData.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      rawData.add([pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]]);
    }
  }
  final compressed = _zDeflate(rawData.toBytes());
  _writeChunk(buffer, 'IDAT', compressed);

  // IEND
  _writeChunk(buffer, 'IEND', Uint8List(0));

  return buffer.toBytes();
}

Uint8List _zDeflate(Uint8List data) {
  final out = BytesBuilder();
  out.add([0x78, 0x01]); // zlib header

  final maxBlock = 65535;
  var offset = 0;
  while (offset < data.length) {
    final remaining = data.length - offset;
    final blockSize = remaining > maxBlock ? maxBlock : remaining;
    final isLast = (offset + blockSize) >= data.length;

    out.addByte(isLast ? 0x01 : 0x00);
    out.addByte(blockSize & 0xFF);
    out.addByte((blockSize >> 8) & 0xFF);
    out.addByte((~blockSize) & 0xFF);
    out.addByte(((~blockSize) >> 8) & 0xFF);
    out.add(data.sublist(offset, offset + blockSize));
    offset += blockSize;
  }

  // Adler-32
  var a = 1, b = 0;
  for (var i = 0; i < data.length; i++) {
    a = (a + data[i]) % 65521;
    b = (b + a) % 65521;
  }
  out.add(_uint32((b << 16) | a));

  return out.toBytes();
}

Uint8List _uint32(int value) {
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}

void _writeChunk(BytesBuilder buffer, String type, Uint8List data) {
  buffer.add(_uint32(data.length));
  final typeBytes = type.codeUnits;
  buffer.add(typeBytes);
  buffer.add(data);
  final crcData = Uint8List(typeBytes.length + data.length);
  crcData.setAll(0, typeBytes);
  crcData.setAll(typeBytes.length, data);
  buffer.add(_uint32(_crc32(crcData)));
}

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (var byte in data) {
    crc ^= byte;
    for (var j = 0; j < 8; j++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}

// ─── File Helper ─────────────────────────────────────────────

void _writeFile(String path, Uint8List data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data);
  print('  ✓ $path (${data.length} bytes)');
}
