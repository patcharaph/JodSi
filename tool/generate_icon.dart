// Run: dart run tool/generate_icon.dart
// Generates a simple 1024x1024 app icon PNG using dart:ui
// Requires: flutter environment

import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

/// Generates a minimal PNG with a gold background and white pencil/mic symbol.
/// Since we can't use dart:ui in a standalone script easily,
/// we generate a valid 1024x1024 solid-color PNG as a placeholder.
void main() {
  // Create a 1024x1024 solid gold (#E5A821) PNG
  final width = 1024;
  final height = 1024;
  final png = createSolidPng(width, height, 0xE5, 0xA8, 0x21);

  // App icon (full, with gold background)
  File('assets/icon/app_icon.png').writeAsBytesSync(png);
  print('Created assets/icon/app_icon.png (${png.length} bytes)');

  // Foreground (same for now — replace with actual icon artwork)
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(png);
  print('Created assets/icon/app_icon_foreground.png (${png.length} bytes)');

  print('\n⚠️  These are placeholder solid-color icons.');
  print('Replace with your actual icon design before publishing to Play Store.');
  print('Recommended: Use Figma/Canva to create a 1024x1024 PNG with:');
  print('  - Gold background (#E5A821)');
  print('  - White pencil/notepad icon in center');
}

/// Creates a minimal valid PNG with a solid color
Uint8List createSolidPng(int width, int height, int r, int g, int b) {
  final buffer = BytesBuilder();

  // PNG Signature
  buffer.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR chunk
  final ihdr = BytesBuilder();
  ihdr.add(_uint32(width));
  ihdr.add(_uint32(height));
  ihdr.add([8, 2, 0, 0, 0]); // 8-bit RGB, no interlace
  _writeChunk(buffer, 'IHDR', ihdr.toBytes());

  // IDAT chunk - raw image data with zlib
  final rawData = BytesBuilder();
  for (var y = 0; y < height; y++) {
    rawData.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      rawData.add([r, g, b]);
    }
  }
  final compressed = zDeflate(rawData.toBytes());
  _writeChunk(buffer, 'IDAT', compressed);

  // IEND chunk
  _writeChunk(buffer, 'IEND', Uint8List(0));

  return buffer.toBytes();
}

/// Minimal DEFLATE implementation (store blocks only, no compression)
Uint8List zDeflate(Uint8List data) {
  final out = BytesBuilder();

  // zlib header (CM=8, CINFO=7, FCHECK)
  out.add([0x78, 0x01]);

  // Split into store blocks (max 65535 bytes each)
  final maxBlock = 65535;
  var offset = 0;
  while (offset < data.length) {
    final remaining = data.length - offset;
    final blockSize = remaining > maxBlock ? maxBlock : remaining;
    final isLast = (offset + blockSize) >= data.length;

    out.addByte(isLast ? 0x01 : 0x00); // BFINAL + BTYPE=00 (store)
    out.addByte(blockSize & 0xFF);
    out.addByte((blockSize >> 8) & 0xFF);
    out.addByte((~blockSize) & 0xFF);
    out.addByte(((~blockSize) >> 8) & 0xFF);
    out.add(data.sublist(offset, offset + blockSize));
    offset += blockSize;
  }

  // Adler-32 checksum
  var a = 1, b2 = 0;
  for (var i = 0; i < data.length; i++) {
    a = (a + data[i]) % 65521;
    b2 = (b2 + a) % 65521;
  }
  final adler = (b2 << 16) | a;
  out.add(_uint32(adler));

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

  // CRC32
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
