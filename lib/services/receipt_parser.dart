class ParsedReceipt {
  final DateTime? date;
  final List<ParsedItem> items;
  final double total;
  final String rawText;
  final String category;

  ParsedReceipt({
    this.date,
    required this.items,
    required this.total,
    required this.rawText,
    this.category = 'other',
  });
}

class ParsedItem {
  final String name;
  final double price;

  ParsedItem({required this.name, required this.price});
}

class ReceiptParser {
  // Lines containing these keywords are NOT items
  static const _skipKeywords = [
    'TOPLAM',
    'TOPKDV',
    'KDV',
    'NAKIT',
    'KREDI',
    'KART',
    'BANKA',
    'FATURA',
    'VERGI',
    'FIS',
    'FİŞ',
    'TEL',
    'ADRES',
    'SAAT',
    'KASA',
    'KASIYER',
    'EKU',
    'FI NO',
    'TUTAR',
    'IADE',
    'İADE',
    'INDIRIM',
    'İNDİRİM',
    'PARA USTU',
    'PARA ÜSTÜ',
    'TARIH',
    'MÜŞTERI',
    'MUSTERI',
    'MÜSTERİ',
    'HOSGELDINIZ',
    'HOŞGELDİNİZ',
    'TESEKKUR',
    'TEŞEKKÜR',
    'THANK',
    'VKN',
    'TCKN',
    'VDB',
    'MAH.',
    'SOK.',
    'CAD.',
    'NO:',
    'ARSIV',
    'ARŞİV',
    'E-ARSIV',
    'E-ARŞİV',
    'ETN:',
    'REF.',
    'POS:',
    'ONAY',
    'GARANTI',
    'YAPI KREDI',
    'AKBANK',
    'İŞ BANKASI',
    'ZIRAAT',
    'VAKIF',
    'HALK',
    'DENIZ',
    'QNB',
    'ING',
    'HSBC',
    'MAĞAZA',
    'MAGAZA',
    'BİRLEŞİK',
    'BIRLESIK',
    'BARBAROS',
    'ATAŞEHIR',
    'ATASEHIR',
    'İSTANBUL',
    'ISTANBUL',
    'MÜKELLEF',
    'MUKELLEF',
    'BILGI',
    'BİLGİ',
  ];

  // Date patterns: DD/MM/YYYY or DD.MM.YYYY or DD-MM-YYYY (also 2-digit year)
  static final _dateRegex = RegExp(r'(\d{2})[/.\-](\d{2})[/.\-](\d{2,4})');

  ParsedReceipt parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => _cleanOcrLine(l.trim()))
        .where((l) => l.isNotEmpty)
        .toList();

    final date = _extractDate(lines);
    final items = _extractItems(lines);
    final total = _extractTotal(lines) ?? _sumItems(items);

    return ParsedReceipt(
      date: date,
      items: items,
      total: total,
      rawText: rawText,
    );
  }

  /// Fix common OCR character misreads
  String _cleanOcrLine(String line) {
    var cleaned = line;
    // O → 0 when between digits
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'(?<=\d)O(?=\d)'), (m) => '0');
    // O → 0 after decimal separator
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'(?<=[.,])O'), (m) => '0');
    // O → 0 before decimal separator in numeric context
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'O(?=[.,]\d)'), (m) => '0');
    // l or I → 1 between digits
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'(?<=\d)[lI](?=\d)'), (m) => '1');
    return cleaned;
  }

  DateTime? _extractDate(List<String> lines) {
    for (final line in lines) {
      final match = _dateRegex.firstMatch(line);
      if (match != null) {
        final day = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        var year = int.tryParse(match.group(3)!);
        if (day != null && month != null && year != null) {
          if (year < 100) year += 2000;
          try {
            final date = DateTime(year, month, day);
            if (date.isBefore(DateTime.now().add(const Duration(days: 1)))) {
              return date;
            }
          } catch (_) {
            continue;
          }
        }
      }
    }
    return null;
  }

  double? _extractTotal(List<String> lines) {
    // Look for TOPLAM (but not ARA TOPLAM, TOPKDV, or KDV TOPLAM)
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.contains('TOPLAM') &&
          !upper.contains('ARA') &&
          !upper.contains('KDV') &&
          !upper.contains('TOPKDV')) {
        final price = _extractAnyPrice(line);
        if (price != null && price > 0) return price;
      }
    }
    // Fallback: any TOPLAM line
    for (final line in lines) {
      if (line.toUpperCase().contains('TOPLAM')) {
        final price = _extractAnyPrice(line);
        if (price != null && price > 0) return price;
      }
    }
    return null;
  }

  List<ParsedItem> _extractItems(List<String> lines) {
    final items = <ParsedItem>[];

    for (final line in lines) {
      final upper = line.toUpperCase();

      // Skip non-item lines
      if (_skipKeywords.any((kw) => upper.contains(kw))) continue;

      // Skip short lines (noise)
      if (line.length < 4) continue;

      // Skip lines that are all digits/symbols (metadata, barcodes)
      if (RegExp(r'^[\d\s\-\./:;#*=]+$').hasMatch(line)) continue;

      // Skip quantity/weight lines: "2 ad X 2.75", "0.69 kg X 10.50"
      if (RegExp(
        r'^\d+\.?\d*\s*(ad|AD|Ad|kg|KG|Kg|adet|ADET|lt|LT|gr|GR)\s',
      ).hasMatch(line)) {
        continue;
      }

      // Skip dashed separator lines
      if (RegExp(r'^[\-=_\.]{3,}$').hasMatch(line)) continue;

      final result = _extractPriceAndName(line);
      if (result != null) {
        final (name, price) = result;
        if (name.isNotEmpty && name.length >= 2 && price > 0 && price < 100000) {
          items.add(ParsedItem(name: name, price: price));
        }
      }
    }

    return items;
  }

  /// Try multiple price patterns and extract (name, price).
  (String, double)? _extractPriceAndName(String line) {
    // === PATTERN 1: Star-prefixed price (BIM, A101, ŞOK style) ===
    // Matches: *31.25  *31,25  *1.250,75  *1250.75
    final starMatch = RegExp(
      r'\*(\d{1,6}[.,]\d{2})\s*$',
    ).firstMatch(line);
    if (starMatch != null) {
      final price = _parsePrice(starMatch.group(1)!);
      // Extract name: everything before the tax column or before the price
      var name = line.substring(0, starMatch.start).trim();
      // Remove tax rate column: %1.00, %8.00, %20.00 etc.
      name = name.replaceAll(RegExp(r'%\d+[.,]?\d*\s*$'), '').trim();
      // Remove leading * and whitespace
      name = name.replaceAll(RegExp(r'^[*\s]+'), '').trim();
      if (name.isNotEmpty && price > 0) {
        return (name, price);
      }
    }

    // === PATTERN 2: Turkish comma-decimal (Migros style) ===
    // Matches: 31,25  1.250,75  250,00
    final turkishMatch = RegExp(
      r'[*\s]?(\d{1,3}(?:\.\d{3})*,\d{2})\s*(?:TL|₺)?\s*$',
    ).firstMatch(line);
    if (turkishMatch != null) {
      final price = _parsePrice(turkishMatch.group(1)!);
      var name = line.substring(0, turkishMatch.start).trim();
      name = name.replaceAll(RegExp(r'%\d+[.,]?\d*\s*$'), '').trim();
      name = name.replaceAll(RegExp(r'^[*\s]+'), '').trim();
      if (name.isNotEmpty && price > 0) {
        return (name, price);
      }
    }

    // === PATTERN 3: Plain period-decimal (no star prefix) ===
    // Matches: 31.25  1250.75
    final periodMatch = RegExp(
      r'\s(\d{1,6}\.\d{2})\s*(?:TL|₺)?\s*$',
    ).firstMatch(line);
    if (periodMatch != null) {
      final price = _parsePrice(periodMatch.group(1)!);
      var name = line.substring(0, periodMatch.start).trim();
      name = name.replaceAll(RegExp(r'%\d+[.,]?\d*\s*$'), '').trim();
      name = name.replaceAll(RegExp(r'^[*\s]+'), '').trim();
      if (name.isNotEmpty && price > 0) {
        return (name, price);
      }
    }

    // === PATTERN 4: Spaced decimal (OCR artifact) ===
    // Matches: 31 .25  31. 25  31 , 25
    final spacedMatch = RegExp(
      r'[*]?\s*(\d{1,6})\s*[.,]\s*(\d{2})\s*(?:TL|₺)?\s*$',
    ).firstMatch(line);
    if (spacedMatch != null) {
      final whole = spacedMatch.group(1)!;
      final decimal = spacedMatch.group(2)!;
      final price = double.tryParse('$whole.$decimal') ?? 0.0;
      var name = line.substring(0, spacedMatch.start).trim();
      name = name.replaceAll(RegExp(r'%\d+[.,]?\d*\s*$'), '').trim();
      name = name.replaceAll(RegExp(r'^[*\s]+'), '').trim();
      if (name.isNotEmpty && price > 0) {
        return (name, price);
      }
    }

    return null;
  }

  /// Extract any price from a line (used for totals)
  double? _extractAnyPrice(String line) {
    final result = _extractPriceAndName(line);
    if (result != null) return result.$2;

    // Fallback: find any number that looks like a price
    final match = RegExp(r'[*]?(\d{1,6}[.,]\d{2})').firstMatch(line);
    if (match != null) {
      return _parsePrice(match.group(1)!);
    }
    return null;
  }

  /// Parse a price string handling both comma and period as decimal.
  /// "31.25" → 31.25, "31,25" → 31.25, "1.250,75" → 1250.75
  double _parsePrice(String s) {
    final lastComma = s.lastIndexOf(',');
    final lastPeriod = s.lastIndexOf('.');

    if (lastComma == -1 && lastPeriod == -1) {
      return double.tryParse(s) ?? 0.0;
    }

    if (lastComma > lastPeriod) {
      // Comma is decimal: 1.250,75 → 1250.75
      final whole = s.substring(0, lastComma).replaceAll('.', '');
      final decimal = s.substring(lastComma + 1);
      return double.tryParse('$whole.$decimal') ?? 0.0;
    } else {
      // Period is decimal: 31.25 or 1,250.75 → 1250.75
      final whole = s.substring(0, lastPeriod).replaceAll(',', '');
      final decimal = s.substring(lastPeriod + 1);
      return double.tryParse('$whole.$decimal') ?? 0.0;
    }
  }

  double _sumItems(List<ParsedItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.price);
  }
}
