  import 'package:flutter/material.dart';
  import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
  import 'package:hive_flutter/hive_flutter.dart';
  import 'dart:async';

  class SmartwatchSyncPage extends StatefulWidget {
    const SmartwatchSyncPage({super.key});

    @override
    State<SmartwatchSyncPage> createState() => _SmartwatchSyncPageState();
  }

  class _SmartwatchSyncPageState extends State<SmartwatchSyncPage> {
    final FlutterReactiveBle _ble = FlutterReactiveBle();

    List<DiscoveredDevice> _devices = [];
    String? _connectedDeviceId;

    int _steps = 0;
    double _heartRate = 0;
    double _bpSystolic = 0;
    double _bpDiastolic = 0;
    double _hydration = 0;

    bool _scanning = false;
    bool _connecting = false;

    late Box _healthBox;

    StreamSubscription? _scanSub;

    // UUIDs
    final Uuid _stepsService = Uuid.parse("00001816-0000-1000-8000-00805f9b34fb");
    final Uuid _stepsCharacteristic =
        Uuid.parse("00002A5B-0000-1000-8000-00805f9b34fb");

    final Uuid _heartRateService =
        Uuid.parse("0000180D-0000-1000-8000-00805f9b34fb");
    final Uuid _heartRateCharacteristic =
        Uuid.parse("00002A37-0000-1000-8000-00805f9b34fb");

    final Uuid _bpService = Uuid.parse("00001810-0000-1000-8000-00805f9b34fb");
    final Uuid _bpCharacteristic =
        Uuid.parse("00002A35-0000-1000-8000-00805f9b34fb");

    final Uuid _hydrationService =
        Uuid.parse("0000181F-0000-1000-8000-00805f9b34fb");
    final Uuid _hydrationCharacteristic =
        Uuid.parse("00002A5F-0000-1000-8000-00805f9b34fb");

    @override
    void initState() {
      super.initState();
      _initHive();
    }

    Future<void> _initHive() async {
      if (!Hive.isBoxOpen('aayutrack_health')) {
        await Hive.openBox('aayutrack_health');
      }
      _healthBox = Hive.box('aayutrack_health');
      _startScan();
    }

    void _startScan() {
      setState(() {
        _scanning = true;
        _devices.clear();
      });

      _scanSub = _ble.scanForDevices(
          withServices: [], scanMode: ScanMode.lowLatency).listen((device) {
        if (!_devices.any((d) => d.id == device.id)) {
          setState(() => _devices.add(device));
        }
      });

      Future.delayed(const Duration(seconds: 5), () {
        _scanSub?.cancel();
        setState(() => _scanning = false);
      });
    }

    Future<void> _connectToDevice(String deviceId) async {
      setState(() => _connecting = true);

      try {
        await _ble.connectToDevice(id: deviceId).listen((state) {
          if (state.connectionState == DeviceConnectionState.connected) {
            setState(() {
              _connectedDeviceId = deviceId;
              _connecting = false;
            });
            _subscribeToMetrics(deviceId);
          }
        }).asFuture();
      } catch (e) {
        setState(() => _connecting = false);
      }
    }

    void _subscribeToMetrics(String deviceId) {
      _ble
          .subscribeToCharacteristic(
        QualifiedCharacteristic(
          characteristicId: _stepsCharacteristic,
          serviceId: _stepsService,
          deviceId: deviceId,
        ),
      )
          .listen((data) {
        setState(() => _steps = data.isNotEmpty ? data[0] : 0);
        _saveData();
      });

      _ble
          .subscribeToCharacteristic(
        QualifiedCharacteristic(
          characteristicId: _heartRateCharacteristic,
          serviceId: _heartRateService,
          deviceId: deviceId,
        ),
      )
          .listen((data) {
        setState(() => _heartRate = data.isNotEmpty ? data[0].toDouble() : 0);
        _saveData();
      });

      _ble
          .subscribeToCharacteristic(
        QualifiedCharacteristic(
          characteristicId: _bpCharacteristic,
          serviceId: _bpService,
          deviceId: deviceId,
        ),
      )
          .listen((data) {
        setState(() {
          _bpSystolic = data.isNotEmpty ? data[0].toDouble() : 0;
          _bpDiastolic = data.length > 1 ? data[1].toDouble() : 0;
        });
        _saveData();
      });

      _ble
          .subscribeToCharacteristic(
        QualifiedCharacteristic(
          characteristicId: _hydrationCharacteristic,
          serviceId: _hydrationService,
          deviceId: deviceId,
        ),
      )
          .listen((data) {
        setState(
            () => _hydration = data.isNotEmpty ? data[0].toDouble() / 1000 : 0);
        _saveData();
      });
    }

    void _saveData() {
      if (_connectedDeviceId == null) return;

      _healthBox.put(_connectedDeviceId!, {
        'steps': _steps,
        'heartRate': _heartRate,
        'bpSystolic': _bpSystolic,
        'bpDiastolic': _bpDiastolic,
        'hydration': _hydration,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    Widget _dataTile(String label, String value, IconData icon, Color color) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      if (_connectedDeviceId == null) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text("Available Smartwatches",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_scanning) const Center(child: CircularProgressIndicator()),
            ..._devices.map((d) => Card(
                  child: ListTile(
                    title: Text(d.name.isEmpty ? "Unknown Device" : d.name),
                    subtitle: Text(d.id),
                    trailing: ElevatedButton(
                      onPressed:
                          _connecting ? null : () => _connectToDevice(d.id),
                      child: const Text("Connect"),
                    ),
                  ),
                )),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _startScan,
              child: const Text("Rescan"),
            ),
          ],
        );
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _dataTile(
              "Steps", _steps.toString(), Icons.directions_walk, Colors.blue),
          _dataTile("Heart Rate", "${_heartRate.toStringAsFixed(0)} bpm",
              Icons.favorite, Colors.red),
          _dataTile(
              "Blood Pressure",
              "${_bpSystolic.toStringAsFixed(0)}/${_bpDiastolic.toStringAsFixed(0)} mmHg",
              Icons.monitor_heart,
              Colors.orange),
          _dataTile("Hydration", "${_hydration.toStringAsFixed(2)} L",
              Icons.local_drink, Colors.teal),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              setState(() => _connectedDeviceId = null);
              _startScan();
            },
            child: const Text("Disconnect / Rescan"),
          )
        ],
      );
    }
  }
