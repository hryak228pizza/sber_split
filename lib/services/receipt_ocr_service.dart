import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/receipt_item.dart';

class ReceiptOcrService {
  static const String _serverUrl = 'http://176.57.213.28:8000/ocr';

  Future<List<ReceiptItem>> sendReceiptImage(File imageFile) async {
    try {
        var request = http.MultipartRequest('POST', Uri.parse(_serverUrl));
        request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

        var response = await request.send();
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
        final serverResponse = json.decode(responseBody);
        final gigaReplyString = serverResponse['giga_reply'] as String;
        
        final cleanJson = gigaReplyString
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .replaceAll(r'\', r'\\')  
            .trim();
        
        final gigaReply = json.decode(cleanJson) as Map<String, dynamic>;
        
        return gigaReply.entries
            .where((entry) {
                // Исключаем "Итого" и записи с null значениями
                if (entry.key == "Итого") return false;
                final value = entry.value as List?;
                return value != null && 
                    value.length >= 2 && 
                    value[0] != null && 
                    value[1] != null;
            })
            .map((entry) {
                final value = entry.value as List;
                return ReceiptItem(
                name: entry.key,
                price: (value[0] as num).toDouble(),
                quantity: (value[1] as num).toInt(),
                );
            })
            .toList();
        } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
        }
    } catch (e) {
        throw Exception('Ошибка при обработке чека: $e');
    }
    }
}