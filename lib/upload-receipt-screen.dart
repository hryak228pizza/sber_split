import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';


class UploadReceiptScreen extends StatefulWidget {
  const UploadReceiptScreen({super.key});
  @override
  UploadReceiptScreenState createState() => UploadReceiptScreenState();
}

class UploadReceiptScreenState extends State<UploadReceiptScreen> {
  File? _receiptImage;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _receiptImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Отсканируйте чек',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Отсканируйте ваш чек, который вы хотите поделить со своими товарищами',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
                      if (pickedFile != null) {
                        setState(() {
                          _receiptImage = File(pickedFile.path);
                        });
                      }
                    },

                    child: _receiptImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              _receiptImage!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: 300,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.receipt_long,
                              size: 100,
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                ),
              ),

              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: (){
                  _pickImage();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Должен быть выбор из галереи')),
                    );
                },
                icon: Icon(Icons.upload_file),
                label: Text('Загрузить из галереи'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87,
                  textStyle: TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Потом будет переход на страницу с чеком')),
                    );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Продолжить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
