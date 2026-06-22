import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:irrigador_inteligente/app_bluetooth_service.dart';
import 'package:provider/provider.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({Key? key}) : super(key: key);

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppBluetoothService>(context, listen: false).startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Dispositivo'),
        backgroundColor: Colors.blue,
      ),
      body: Consumer<AppBluetoothService>(
        builder: (context, bluetoothService, child) {
          if (bluetoothService.isConnected) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: bluetoothService.startScan,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Procurar Novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: bluetoothService.availableDevices.length,
                  itemBuilder: (context, index) {
                    fbp.BluetoothDevice device = bluetoothService.availableDevices[index];
                    return ListTile(
                      title: Text(device.platformName),
                      subtitle: Text(device.remoteId.toString()),
                      trailing: ElevatedButton(
                        child: const Text('Conectar'),
                        onPressed: () => bluetoothService.connectToDevice(device),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}