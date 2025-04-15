import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import 'package:vibration/vibration.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  late io.Socket socket;
  Position? _currentPosition;
  String _connectionStatus = 'Офлайн';
  String _bumpStatus = 'No bump detected';
  bool _isShaking = false;
  DateTime? _shakeStartTime;
  List<double> _accelerationHistory = [];
  static const Duration requiredShakeDuration = Duration(milliseconds: 500);
  
  final String _userId = 'user_${Random().nextInt(9000) + 1000}';
  String? _lastBumpedUserId;
  double? _lastBumpDistance;

  @override
  void initState() {
    super.initState();
    _initSocketConnection();
    _initLocation();
    _initAccelerometer();
  }

  void _initSocketConnection() {
    socket = io.io(
      'https://bump-server-7eq2.onrender.com',
      io.OptionBuilder()
        .setTransports(['websocket'])
        .enableReconnection()
        .setQuery({'userId': _userId})
        .build(),
    );

    socket.onConnect((_) {
      setState(() => _connectionStatus = 'Онлайн');
      socket.emit('register', _userId);
    });

    socket.onDisconnect((_) => setState(() => _connectionStatus = 'Офлайн'));

    socket.on('bump_event', (data) => _handleIncomingBump(data));
  }

  void _handleIncomingBump(Map<String, dynamic> data) {
    setState(() {
      _lastBumpedUserId = data['senderId'];
      _lastBumpDistance = data['distance'];
    });

    Vibration.vibrate(duration: 500);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Успешный бамп!'),
        content: Text(
          'Соединение с ${data['senderId']}\n'
          'Расстояние: ${data['distance']?.toStringAsFixed(1) ?? 'N/A'} м'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendBumpToServer() async {
    if (_currentPosition == null) return;

    socket.emit('bump', {
      'senderId': _userId,
      'timestamp': DateTime.now().toIso8601String(),
      'lat': _currentPosition!.latitude,
      'lng': _currentPosition!.longitude,
      'accuracy': _currentPosition!.accuracy,
      'speed': _currentPosition!.speed,
    });
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      
      setState(() => _currentPosition = position);

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        )
      ).listen((position) {
        setState(() => _currentPosition = position);
      });
    } catch (e) {
      print('Location error: $e');
    }
  }

  void _initAccelerometer() {
    accelerometerEvents.listen((event) {
      final acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      _accelerationHistory.add(acceleration);
      if (_accelerationHistory.length > 10) {
        _accelerationHistory.removeAt(0);
      }
      
      _detectBump(acceleration);
    });
  }

  void _detectBump(double currentAcceleration) {
    if (_accelerationHistory.length < 5) return;
    
    final average = _accelerationHistory.reduce((a, b) => a + b) / _accelerationHistory.length;
    const threshold = 15.0;
    
    if (currentAcceleration > threshold && (currentAcceleration - average) > 5.0) {
      if (!_isShaking) {
        setState(() {
          _shakeStartTime = DateTime.now();
          _isShaking = true;
        });
      } else if (DateTime.now().difference(_shakeStartTime!) >= requiredShakeDuration) {
        _onShakeDetected();
      }
    }
  }

  Future<void> _onShakeDetected() async {
    setState(() {
      _bumpStatus = 'BUMP! (${DateTime.now().toLocal().toString().substring(11, 19)})';
      _isShaking = false;
    });
    
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 800);
    }
    
    await _sendBumpToServer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bump Detection'),
        actions: [
          Chip(
            label: Text(_connectionStatus),
            backgroundColor: _connectionStatus == 'Онлайн' 
              ? Colors.green[100] 
              : Colors.red[100],
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ваш ID: $_userId',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            if (_lastBumpedUserId != null) ...[
              const SizedBox(height: 20),
              Text(
                'Последний бамп: $_lastBumpedUserId',
                style: const TextStyle(color: Colors.green),
              ),
              Text(
                'Расстояние: ${_lastBumpDistance?.toStringAsFixed(1) ?? 'N/A'} м',
              ),
            ],
            
            const SizedBox(height: 20),
            Text(
              _bumpStatus,
              style: TextStyle(
                color: _bumpStatus.startsWith('BUMP') ? Colors.green : Colors.black,
                fontSize: 16,
              ),
            ),
            
            if (_isShaking)
              LinearProgressIndicator(
                value: (DateTime.now().difference(_shakeStartTime!).inMilliseconds / 
                       requiredShakeDuration.inMilliseconds,
                minHeight: 10,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }
}