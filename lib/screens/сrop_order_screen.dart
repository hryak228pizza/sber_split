import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'bump.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../models/receipt_item.dart';
import 'split_receipt_screen.dart';

class CropReceiptScreen extends StatefulWidget {
  final File image;

  const CropReceiptScreen({super.key, required this.image});

  @override
  _CropReceiptScreenState createState() => _CropReceiptScreenState();
}

class _CropReceiptScreenState extends State<CropReceiptScreen> {
  late File _image;
  final GlobalKey _imageKey = GlobalKey();
  Rect _cropRect = Rect.zero;
  Offset _startDrag = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
  }

  Future<void> _cropImage() async {
    if (_cropRect.isEmpty) return;

    final RenderRepaintBoundary boundary =
        _imageKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Декодируем изображение для обработки
    final decodedImage = img.decodeImage(buffer)!;
    
    // Вычисляем координаты обрезки
    final cropX = (_cropRect.left * image.width / boundary.size.width).round();
    final cropY = (_cropRect.top * image.height / boundary.size.height).round();
    final cropWidth = (_cropRect.width * image.width / boundary.size.width).round();
    final cropHeight = (_cropRect.height * image.height / boundary.size.height).round();

    // Выполняем обрезку
    final croppedImage = img.copyCrop(
      decodedImage,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    // Сохраняем результат
    final croppedFile = File('${_image.path}_cropped.png')
      ..writeAsBytesSync(img.encodePng(croppedImage));
    
    setState(() {
      _image = croppedFile;
      _cropRect = Rect.zero;
    });
  }

  void _startCrop(Offset position) {
    setState(() {
      _startDrag = position;
      _cropRect = Rect.fromPoints(position, position);
      _isDragging = true;
    });
  }

  void _updateCrop(Offset position) {
    if (!_isDragging) return;
    
    setState(() {
      _cropRect = Rect.fromPoints(_startDrag, position);
    });
  }

  void _endCrop() {
    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Обрезать изображение')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onPanStart: (details) => _startCrop(details.localPosition),
                onPanUpdate: (details) => _updateCrop(details.localPosition),
                onPanEnd: (_) => _endCrop(),
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _imageKey,
                      child: Image.file(_image, fit: BoxFit.contain),
                    ),
                    if (_cropRect != Rect.zero)
                      Positioned.fromRect(
                        rect: _cropRect,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: _cropImage,
                child: const Text('Применить обрезку'),
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.all(20.0),
            //   child: ElevatedButton(
            //     onPressed: () {
            //       Provider.of<ReceiptProvider>(context, listen: false).setAdmin(true);
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //           builder: (context) => const SensorPage(),
            //         ),
            //       );
            //     },
            //     child: const Text('Разделить счет'),
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: () {
                  // Тестовые данные чека (в реальном приложении будет OCR)
                  final testItems = [
                    ReceiptItem(name: 'Кофе', price: 150.0),
                    ReceiptItem(name: 'Бургер', price: 250.0),
                    ReceiptItem(name: 'Картофель фри', price: 120.0),
                    ReceiptItem(name: 'Кофе', price: 150.0),
                    ReceiptItem(name: 'Салат', price: 180.0),
                  ];
                  
                  Provider.of<ReceiptProvider>(context, listen: false)
                      .setReceiptItems(testItems);
                      
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SplitReceiptScreen()),
                  );
                },
                child: const Text('Распознать чек'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}