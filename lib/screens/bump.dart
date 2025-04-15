import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import 'package:vibration/vibration.dart'; 
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  // местоположение
  Position? _currentPosition;
  String _locationStatus = 'Waiting...';
  // акселерометр
  String _accelerometerData = 'No data yet';
  List<double> _accelerationHistory = [];
  // детекция тряха
  String _bumpStatus = 'No bump detected';
  DateTime? _lastBumpTime;
  bool _isShaking = false;
  DateTime? _shakeStartTime;
  int _inactiveCount = 0;
  static const Duration requiredShakeDuration = Duration(milliseconds: 500);

  late io.Socket socket;
  String _connectionStatus = 'Офлайн';

  final String _userId = 'user_${Random().nextInt(9000) + 1000}';
  String? _lastBumpedUserId;

  @override
  void initState() {
    super.initState();
    _initSocketConnection();
    _initLocation();
    _initAccelerometer();
    _checkVibrationSupport();
  }

  void _initSocketConnection() {
    socket = io.io('http://192.168.0.10:5000', {
      'transports': ['websocket'],
      'query': {'userId': _userId}
    });

    socket.onConnect((_) {
      setState(() => _connectionStatus = 'Онлайн');
      
      // Регистрация пользователя
      socket.emit('register', _userId);

      // Событие тряски от другого устройства
      socket.on('bump_event', (data) {
        _handleIncomingBump(data);
      });
    });

    socket.onDisconnect((_) => setState(() => _connectionStatus = 'Офлайн'));
  }

  void _handleIncomingBump(String otherUserId) {
    setState(() {
      _lastBumpedUserId = otherUserId;
    });
    
    Vibration.vibrate(duration: 500);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Успешный бамп!'),
        content: Text('Вы соединились с пользователем $otherUserId'),
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

    final bumpData = {
      'senderId': _userId,
      'timestamp': DateTime.now().toIso8601String(),
      'lat': _currentPosition!.latitude,
      'lng': _currentPosition!.longitude,
      'accuracy': _currentPosition!.accuracy,
      'speed': _currentPosition!.speed,
    };

    socket.emit('bump', bumpData);


    // Implement your server communication here
    // You would typically send:
    // - Current timestamp
    // - Device ID or user ID
    // - Current location (_currentPosition)
    print('Bump detected at ${_currentPosition?.toJson()}');
    
    // In a real app, you would use something like:
    // final response = await http.post(
    //   Uri.parse('your-server-endpoint'),
    //   body: jsonEncode({
    //     'userId': 'user123',
    //     'timestamp': DateTime.now().toIso8601String(),
    //     'location': _currentPosition?.toJson(),
    //   }),
    // );

  }

  Future<void> _checkVibrationSupport() async {
    if (await Vibration.hasVibrator() ?? false) {
      print('Устройство поддерживает вибрацию');
    } else {
      print('Устройство не поддерживает вибрацию');
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationStatus = 'Location services are disabled.';
      });
      return;
    }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      setState(() {
        _locationStatus = 'Location permissions are denied';
      });
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    setState(() {
      _locationStatus = 'Location permissions are permanently denied';
    });
    return;
  }

  // для версии geolocator 10.1.1+
  final locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );
    
  Geolocator.getPositionStream(locationSettings: locationSettings)
    .listen((Position position) {
      setState(() {
        _currentPosition = position;
        _locationStatus = 'Location updated';
      });
    });

  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = position;
      _locationStatus = 'Got initial location';
    });
  } catch (e) {
    setState(() {
      _locationStatus = 'Error getting location: $e';
    });
  }
}

  void _initAccelerometer() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      // Calculate the magnitude of acceleration
      double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Keep a short history for bump detection
      _accelerationHistory.add(acceleration);
      if (_accelerationHistory.length > 10) {
        _accelerationHistory.removeAt(0);
      }
      
      // Detect bump (shake)
      _detectBump(acceleration);
      
      setState(() {
        _accelerometerData = 'X: ${event.x.toStringAsFixed(2)}\n'
                            'Y: ${event.y.toStringAsFixed(2)}\n'
                            'Z: ${event.z.toStringAsFixed(2)}\n'
                            'Magnitude: ${acceleration.toStringAsFixed(2)}';
      });
    });
  }

  void _detectBump(double currentAcceleration) {
    // Simple bump detection algorithm
    if (_accelerationHistory.length < 5) return;
    
    // Get average of the last few readings
    double average = _accelerationHistory.reduce((a, b) => a + b) / _accelerationHistory.length;
    
    // Threshold for bump detection (adjust as needed)
    const double bumpThreshold = 15.0;  // минимальная
    const double differenceThreshold = 5.0; // Насколько текущее ускорение должно превышать среднее
    
    // Check if current acceleration is significantly higher than average
    if (currentAcceleration > bumpThreshold && 
        (currentAcceleration - average) > differenceThreshold) {
      
      if (!_isShaking) {
        // shaking start
        setState(() {
          _shakeStartTime = DateTime.now();
          _isShaking = true;
          _inactiveCount = 0;
        });
      } else {
        // check shaking duration
        if (DateTime.now().difference(_shakeStartTime!) >= requiredShakeDuration) {
          _onShakeDetected();
        }
      }
    } else {
      // Grace period for intermittent shaking
      if (currentAcceleration < bumpThreshold * 0.7) {
        _inactiveCount++;
        if (_inactiveCount > 3) {
          setState(() => _isShaking = false);
        }
      } else {
        _inactiveCount = 0;
      }
    }
  }

  Future<void> _onShakeDetected() async {
    setState(() {
      _bumpStatus = 'BUMP! (${DateTime.now().toLocal().toString().substring(11, 19)})';
      _isShaking = false;
    });
    
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 1000);
    }
    
    await _sendBumpToServer();
    _lastBumpTime = DateTime.now();
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              'Your ID: $_userId',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Location Section
            const Text(
              'Location Data:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Status: $_locationStatus'),
            Text('Latitude: ${_currentPosition?.latitude ?? 'N/A'}'),
            Text('Longitude: ${_currentPosition?.longitude ?? 'N/A'}'),
            Text('Accuracy: ${_currentPosition?.accuracy?.toStringAsFixed(2) ?? 'N/A'}m'),
            Text('Speed: ${_currentPosition?.speed?.toStringAsFixed(2) ?? 'N/A'} m/s'),
            const SizedBox(height: 20),
            
            // Accelerometer Section
            const Text(
              'Accelerometer Data:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_accelerometerData),
            const SizedBox(height: 20),
            
            // Bump Detection Section
            const Text(
              'Bump Detection:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _bumpStatus,
              style: TextStyle(
                fontSize: 16,
                color: _bumpStatus.startsWith('BUMP') ? Colors.green : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            
            // progress-bar (debug)
            LinearProgressIndicator(
              value: _isShaking 
                ? (DateTime.now().difference(_shakeStartTime!).inMilliseconds / 
                   requiredShakeDuration.inMilliseconds).clamp(0.0, 1.0)
                : 0,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _isShaking ? Colors.blue : Colors.grey,
              ),
            ),

            const SizedBox(height: 8),
            Text(
              _isShaking 
                ? 'Shake harder! (${(DateTime.now().difference(_shakeStartTime!).inMilliseconds / 1000).toStringAsFixed(1)} s)'
                : 'Shake your phone for 0.5s',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            // Instructions
            const Text(
              'How to use:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text('Shake your phone to simulate a bump. The app will detect sudden movements.'),
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