import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String _baseUrl = 'http://176.57.213.28:8000/docs';

  Future<Map<String, dynamic>> processReceipt(File image) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/ocr'));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseData);
      } else {
        throw Exception('Failed to process receipt: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('API call failed: $e');
    }
  }
}