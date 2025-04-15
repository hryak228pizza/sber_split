import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_service.dart';

class ReceiptProvider extends ChangeNotifier {
  final ImageService _imageService;
  File? _image;
  bool _isAdmin = false;

  ReceiptProvider(this._imageService);

  File? get image => _image;
  bool get isAdmin => _isAdmin;

  void setAdmin(bool value) {
    _isAdmin = value;
    notifyListeners();
  }

  Future<void> loadFromGallery() async {
    _image = await _imageService.pickFromGallery();
    notifyListeners();
  }

  Future<void> loadFromCamera() async {
    _image = await _imageService.pickFromCamera();
    notifyListeners();
  }
}
