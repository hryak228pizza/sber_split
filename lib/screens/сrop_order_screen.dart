import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';

class CropReceiptScreen extends StatefulWidget {
  final File image;

  const CropReceiptScreen({super.key, required this.image});

  @override
  _CropReceiptScreenState createState() => _CropReceiptScreenState();
}

class _CropReceiptScreenState extends State<CropReceiptScreen> {
  late File _image;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
  }

  Future<void> _cropImage() async {
    // Используем image_cropper для обрезки изображения
    final cropped = await ImageCropper().cropImage(
      sourcePath: _image.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio4x3,
      ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Обрезка изображения',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          minimumAspectRatio: 1.0,
        ),
      ],
    );

    if (cropped != null) {
      setState(() {
        // Преобразуем CroppedFile в File
        _image = File(cropped.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Обрезать изображение')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.file(_image, height: 300),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _cropImage,
              child: Text('Обрезать изображение'),
            ),
          ],
        ),
      ),
    );
  }
}
