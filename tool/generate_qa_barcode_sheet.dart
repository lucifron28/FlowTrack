import 'dart:io';
import 'package:barcode/barcode.dart' as barcode;

const samples = [
  ('Lucky Me Pancit Canton Chilimansi', '4807770271137'),
  ('555 Sardines Tomato Sauce', '4800110020303'),
  ('Nescafe Original Stick', '4800361417402'),
  ('Great Taste White Sachet', '4800016112300'),
  ('SkyFlakes Crackers', '4800016640704'),
  ('C2 Green Tea Apple 230ml', '4804888801232'),
  ('Safeguard White Bar 60g', '4800888206015'),
  ('Piattos Cheese 40g', '4800016060212'),
  ('Coke Sakto 200ml', '4801981111114'),
  ('Asukal Tingi 1/4 kilo', 'FT-TINGI-ASUKAL'),
  ('Mantika Tingi 100ml', 'FT-TINGI-MANTIKA'),
  ('Bigas Tingi 1 kilo', 'FT-TINGI-BIGAS'),
];

void main() {
  final output = File('demo/qa-barcode-sheet.svg');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(_buildSheet());
}

String _buildSheet() {
  const pageWidth = 1200;
  const margin = 48;
  const cardWidth = 520;
  const cardHeight = 170;
  const gap = 32;
  const rowGap = 28;
  final rows = (samples.length / 2).ceil();
  final pageHeight = margin * 2 + rows * cardHeight + (rows - 1) * rowGap;
  final buffer = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$pageWidth" height="$pageHeight" viewBox="0 0 $pageWidth $pageHeight">',
    )
    ..writeln('<rect width="100%" height="100%" fill="#F8FAFC"/>')
    ..writeln(
      '<text x="$margin" y="34" font-family="Arial, sans-serif" font-size="24" font-weight="700" fill="#0F172A">FlowTrack QA Scan Sheet</text>',
    )
    ..writeln(
      '<text x="$margin" y="62" font-family="Arial, sans-serif" font-size="14" fill="#64748B">Load QA sample data in Settings, then scan these barcodes from Sales or Inventory.</text>',
    );

  for (var index = 0; index < samples.length; index++) {
    final row = index ~/ 2;
    final col = index % 2;
    final x = margin + col * (cardWidth + gap);
    final y = 86 + row * (cardHeight + rowGap);
    final (name, value) = samples[index];
    buffer
      ..writeln(
        '<rect x="$x" y="$y" width="$cardWidth" height="$cardHeight" rx="14" fill="#FFFFFF" stroke="#CBD5E1"/>',
      )
      ..writeln(
        '<text x="${x + 18}" y="${y + 30}" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="#0F172A">${_escape(name)}</text>',
      )
      ..writeln(
        '<text x="${x + 18}" y="${y + 54}" font-family="Arial, sans-serif" font-size="13" fill="#64748B">${_escape(value)}</text>',
      );
    _appendBarcode(buffer, value, x + 18, y + 72, 330, 64);
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

void _appendBarcode(
  StringBuffer buffer,
  String value,
  double startX,
  double y,
  double width,
  double height,
) {
  final isEan13 = RegExp(r'^\d+$').hasMatch(value) && value.length == 13;
  final bc = isEan13 ? barcode.Barcode.ean13() : barcode.Barcode.code128();

  var barcodeSvg = bc.toSvg(
    value,
    width: width,
    height: height,
    drawText: false,
  );

  // Customize nested SVG tags and colors
  barcodeSvg = barcodeSvg
      .replaceFirst(
        '<svg viewBox=',
        '<svg x="$startX" y="$y" width="$width" height="$height" viewBox=',
      )
      .replaceAll('style="fill: #000000"', 'style="fill: #0F172A"');

  buffer.writeln(barcodeSvg);

  buffer.writeln(
    '<text x="$startX" y="${y + height + 22}" font-family="Arial, sans-serif" font-size="16" letter-spacing="2" fill="#0F172A">${_escape(value)}</text>',
  );
}

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
