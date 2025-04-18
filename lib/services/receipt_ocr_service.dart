import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ReceiptOcrService {
  static const String _serverUrl = 'http://176.57.213.28:8000/ocr';

  Future<Map<String, dynamic>> sendReceiptImage(File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_serverUrl));
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        // преобразуем строку в Map
        final Map<String, dynamic> jsonResponse = json.decode(responseBody);
        
        // преобразуем giga_reply (строкy) в Map
        final Map<String, dynamic> gigaReply = json.decode(jsonResponse['giga_reply']);
        return gigaReply;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}