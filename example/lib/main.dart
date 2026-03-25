import 'package:flutter/material.dart';
import 'package:local_network_rwx/local_network_rwx.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  LocalNetworkStatusRWX _status = LocalNetworkStatusRWX.unknown;
  bool _checking = false;

  Future<void> _checkPermission() async {
    setState(() => _checking = true);

    // Optional: send a UDP primer to increase reliability on older iOS versions.
    final broadcast = await LocalNetworkPermissionRWX.getBroadcastAddress();
    await LocalNetworkPermissionRWX.sendUdpPrimer(broadcastAddress: broadcast);

    // Request / check the permission via NWBrowser.
    // Replace '_myapp._tcp' with your own Bonjour service type.
    // It must also be listed in your Info.plist under NSBonjourServices.
    final status = await LocalNetworkPermissionRWX.requestPermission(
      serviceType: '_myapp._tcp',
    );

    setState(() {
      _status = status;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Local Network Permission')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _status == LocalNetworkStatusRWX.granted
                    ? Icons.check_circle
                    : _status == LocalNetworkStatusRWX.denied
                        ? Icons.cancel
                        : Icons.help_outline,
                size: 64,
                color: _status == LocalNetworkStatusRWX.granted
                    ? Colors.green
                    : _status == LocalNetworkStatusRWX.denied
                        ? Colors.red
                        : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Status: ${_status.name}',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _checking ? null : _checkPermission,
                child: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check Permission'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => LocalNetworkPermissionRWX.openSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
