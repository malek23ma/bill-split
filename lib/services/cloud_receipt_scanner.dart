import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'receipt_parser.dart';

class CloudReceiptScanner {
  final String apiKey;

  CloudReceiptScanner({required this.apiKey});

  Future<ParsedReceipt> scanAndParse(String imagePath) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final ext = imagePath.toLowerCase().split('.').last;
    final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
        'max_tokens': 2048,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mediaType;base64,$base64Image',
                },
              },
              {
                'type': 'text',
                'text':
                    'Bu bir fiş/makbuz fotoğrafı. Tüm satın alınan ürünleri çıkar.\n'
                    'SADECE geçerli JSON döndür, başka metin yok.\n\n'
                    'Format:\n'
                    '{\n'
                    '  "date": "DD/MM/YYYY" veya null,\n'
                    '  "category": "groceries",\n'
                    '  "items": [{"name": "ÜRÜN ADI", "price": 0.00}, ...],\n'
                    '  "total": 0.00\n'
                    '}\n\n'
                    'Kategori şunlardan biri olmalı: groceries, restaurant, utilities, rent, transport, health, entertainment, shopping, other\n\n'
                    'Kurallar:\n'
                    '- Her satın alınan ürünü ve toplam fiyatını dahil et\n'
                    '- Miktar/ağırlık satırlarını atla (örn. "2 ad X 2.75") - toplam zaten ürün satırında\n'
                    '- Vergi, ara toplam, ödeme bilgisi satırlarını atla\n'
                    '- Fiyatlar sayı olmalı (string değil)\n'
                    '- Her ürün için satır sonundaki nihai fiyatı kullan\n'
                    '- TOPLAM satırındaki değeri "total" olarak kullan\n'
                    '- Fişin türüne göre doğru kategoriyi seç (market=groceries, restoran=restaurant, vb.)',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final text = data['choices'][0]['message']['content'] as String;

    final jsonStr = _extractJson(text);
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

    final items = (parsed['items'] as List).map((item) {
      return ParsedItem(
        name: item['name'] as String,
        price: (item['price'] as num).toDouble(),
      );
    }).toList();

    DateTime? date;
    if (parsed['date'] != null && parsed['date'] is String) {
      final dateStr = parsed['date'] as String;
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          try {
            date = DateTime(year, month, day);
          } catch (_) {}
        }
      }
    }

    final category = parsed['category'] as String? ?? 'other';
    final validCategories = [
      'groceries', 'restaurant', 'utilities', 'rent',
      'transport', 'health', 'entertainment', 'shopping', 'other',
    ];

    return ParsedReceipt(
      date: date,
      items: items,
      total: (parsed['total'] as num?)?.toDouble() ??
          items.fold(0.0, (s, i) => s + i.price),
      rawText: text,
      category: validCategories.contains(category) ? category : 'other',
    );
  }

  String _extractJson(String text) {
    final codeBlock =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (codeBlock != null) return codeBlock.group(1)!.trim();

    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jsonMatch != null) return jsonMatch.group(0)!;

    return text;
  }
}
