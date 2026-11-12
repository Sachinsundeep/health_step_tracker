import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Health Step Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StepTrackerScreen(),
    );
  }
}

class StepTrackerScreen extends StatefulWidget {
  const StepTrackerScreen({super.key});

  @override
  State<StepTrackerScreen> createState() => _StepTrackerScreenState();
}

class _StepTrackerScreenState extends State<StepTrackerScreen> {
  late Stream<StepCount> _stepCountStream;
  late Stream<PedestrianStatus> _pedestrianStatusStream;

  String _status = 'Stationary';
  int _totalDeviceSteps = 0;
  int? _initialStepOffset; // Used to track steps taken during the current app session
  bool _isPermissionGranted = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _requestPermissionAndInit();
  }

  Future<void> _requestPermissionAndInit() async {
    // Android requires Activity Recognition, iOS automatically prompts on first CMPedometer call
    PermissionStatus status = await Permission.activityRecognition.request();

    if (status.isGranted) {
      setState(() => _isPermissionGranted = true);
      _initPedometer();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _errorMessage = 'Permission permanently denied. Enable it in system settings.';
      });
      openAppSettings();
    } else {
      setState(() {
        _errorMessage = 'Physical activity permission is required to track steps.';
      });
    }
  }

  void _initPedometer() {
    // 1. Hardware Step Counter Stream
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
      cancelOnError: false,
    );

    // 2. Movement Status Stream (walking, stopped, unknown)
    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;
    _pedestrianStatusStream.listen(
      _onPedestrianStatusChanged,
      onError: _onPedestrianStatusError,
      cancelOnError: false,
    );
  }

  void _onStepCount(StepCount event) {
    setState(() {
      _totalDeviceSteps = event.steps;

      // Calculate baseline offset for this session
      _initialStepOffset ??= event.steps;
    });
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    setState(() {
      _status = event.status; // 'walking', 'stopped', or 'unknown'
    });
  }

  void _onStepCountError(dynamic error) {
    setState(() {
      _errorMessage = 'Step Count Sensor Error: $error';
    });
  }

  void _onPedestrianStatusError(dynamic error) {
    setState(() {
      _status = 'Status unavailable';
    });
  }

  void _resetSessionSteps() {
    setState(() {
      _initialStepOffset = _totalDeviceSteps;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionSteps = _initialStepOffset != null ? (_totalDeviceSteps - _initialStepOffset!) : 0;
    final estimatedDistanceM = (sessionSteps * 0.762).toStringAsFixed(1); // 0.762m avg stride
    final estimatedKcal = (sessionSteps * 0.04).toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Pedometer'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Pedometer Dial
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _status == 'walking' ? const Color(0xFF10B981) : Colors.grey.shade700,
                    width: 6,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _status == 'walking' ? Icons.directions_walk : Icons.accessibility_new,
                      size: 48,
                      color: _status == 'walking' ? const Color(0xFF10B981) : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$sessionSteps',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'SESSION STEPS',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Status and Secondary Metrics
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: _status == 'walking' ? Colors.green : Colors.orange,
                  radius: 5,
                ),
                label: Text('Status: ${_status.toUpperCase()}'),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MetricTile(label: 'Distance', value: '$estimatedDistanceM m'),
                  _MetricTile(label: 'Active Burn', value: '$estimatedKcal kcal'),
                  _MetricTile(label: 'Hardware Total', value: '$_totalDeviceSteps'),
                ],
              ),

              const SizedBox(height: 36),

              ElevatedButton.icon(
                onPressed: _resetSessionSteps,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Session Counter'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w640)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
