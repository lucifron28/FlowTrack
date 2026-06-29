import 'dart:io';

const samples = [
  ('Lucky Me Pancit Canton Chilimansi', '4807770271137'),
  ('555 Sardines Tomato Sauce', '4800110020307'),
  ('Nescafe Original Stick', '4800361417406'),
  ('Great Taste White Sachet', '4800016112306'),
  ('SkyFlakes Crackers', '4800016640706'),
  ('C2 Green Tea Apple 230ml', '4804888801234'),
  ('Safeguard White Bar 60g', '4800888206019'),
  ('Piattos Cheese 40g', '4800016060218'),
  ('Coke Sakto 200ml', '4801981111112'),
  ('Asukal Tingi 1/4 kilo', 'FT-TINGI-ASUKAL'),
  ('Mantika Tingi 100ml', 'FT-TINGI-MANTIKA'),
  ('Bigas Tingi 1 kilo', 'FT-TINGI-BIGAS'),
];

const _code39 = {
  '0': 'nnnwwnwnn',
  '1': 'wnnwnnnnw',
  '2': 'nnwwnnnnw',
  '3': 'wnwwnnnnn',
  '4': 'nnnwwnnnw',
  '5': 'wnnwwnnnn',
  '6': 'nnwwwnnnn',
  '7': 'nnnwnnwnw',
  '8': 'wnnwnnwnn',
  '9': 'nnwwnnwnn',
  'A': 'wnnnnwnnw',
  'B': 'nnwnnwnnw',
  'C': 'wnwnnwnnn',
  'D': 'nnnnwwnnw',
  'E': 'wnnnwwnnn',
  'F': 'nnwnwwnnn',
  'G': 'nnnnnwwnw',
  'H': 'wnnnnwwnn',
  'I': 'nnwnnwwnn',
  'J': 'nnnnwwwnn',
  'K': 'wnnnnnnww',
  'L': 'nnwnnnnww',
  'M': 'wnwnnnnwn',
  'N': 'nnnnwnnww',
  'O': 'wnnnwnnwn',
  'P': 'nnwnwnnwn',
  'Q': 'nnnnnnwww',
  'R': 'wnnnnnwwn',
  'S': 'nnwnnnwwn',
  'T': 'nnnnwnwwn',
  'U': 'wwnnnnnnw',
  'V': 'nwwnnnnnw',
  'W': 'wwwnnnnnn',
  'X': 'nwnnwnnnw',
  'Y': 'wwnnwnnnn',
  'Z': 'nwwnwnnnn',
  '-': 'nwnnnnwnw',
  '.': 'wwnnnnwnn',
  ' ': 'nwwnnnwnn',
  r'$': 'nwnwnwnnn',
  '/': 'nwnwnnnwn',
  '+': 'nwnnnwnwn',
  '%': 'nnnwnwnwn',
  '*': 'nwnnwnwnn',
};

void main() {
  final output = File('docs/qa-barcode-sheet.svg');
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
      '<text x="$margin" y="62" font-family="Arial, sans-serif" font-size="14" fill="#64748B">Load QA sample data in Settings, then scan these Code 39 barcodes from Sales or Inventory.</text>',
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
    _appendCode39(buffer, value, x + 18, y + 72, 2.2, 64);
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

void _appendCode39(
  StringBuffer buffer,
  String value,
  double startX,
  double y,
  double narrow,
  double height,
) {
  final encoded = '*${value.toUpperCase()}*';
  var x = startX;
  for (final rune in encoded.runes) {
    final char = String.fromCharCode(rune);
    final pattern = _code39[char];
    if (pattern == null) {
      throw ArgumentError('Unsupported Code 39 character: $char');
    }
    for (var i = 0; i < pattern.length; i++) {
      final width = pattern[i] == 'w' ? narrow * 3 : narrow;
      if (i.isEven) {
        buffer.writeln(
          '<rect x="${x.toStringAsFixed(1)}" y="$y" width="${width.toStringAsFixed(1)}" height="$height" fill="#0F172A"/>',
        );
      }
      x += width;
    }
    x += narrow;
  }
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
