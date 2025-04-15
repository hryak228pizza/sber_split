import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sber_split/screens/%D1%81rop_order_screen.dart';
import '../providers/order_provider.dart';
import 'bump.dart';

class UploadReceiptScreen extends StatelessWidget {
  const UploadReceiptScreen({super.key});

 @override
  Widget build(BuildContext context) {
  final provider = Provider.of<ReceiptProvider>(context);
  final image = provider.image;

  return Scaffold(
    appBar: AppBar(title: Text('Upload Receipt')),
    body: Center( 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          image != null
              ? Image.file(image, height: 200)
              : Icon(Icons.receipt_long, size: 100, color: Colors.grey),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => provider.loadFromGallery(),
            icon: Icon(Icons.image),
            label: Text("Выбрать из галереи"),
          ),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => provider.loadFromCamera(),
            icon: Icon(Icons.camera_alt),
            label: Text("Сделать фото"),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: image != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CropReceiptScreen(image: image),
                      ),
                    );
                  }
                : null,
            child: Text('Обрезать изображение'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<ReceiptProvider>(context, listen: false).setAdmin(false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SensorPage()),
              );
            },
            child: const Text('Перейти к бампу как участник'),
          ),
        ],
      ),
    ),
  );
}
}
