import 'package:flutter/material.dart';
import 'package:irrigador_inteligente/app_bluetooth_service.dart';
import 'package:irrigador_inteligente/pages/connect_page.dart';
import 'package:irrigador_inteligente/pages/register_plant_page.dart';
import 'package:irrigador_inteligente/pages/plants_list_page.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Irrigador Inteligente'),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: Consumer<AppBluetoothService>(
        builder: (context, bluetoothService, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (bluetoothService.statusMessage != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(bluetoothService.statusMessage!)));
              bluetoothService.clearStatusMessage();
            }
          });

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: bluetoothService.isConnected ? Colors.green[100] : Colors.red[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Status: ${bluetoothService.isConnected ? 'Conectado' : 'Desconectado'}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: bluetoothService.isConnected ? Colors.green[800] : Colors.red[800],
                          ),
                        ),
                        if (bluetoothService.isConnected) ...[
                          Text(
                            'Dispositivo: ${bluetoothService.deviceName}',
                            style: TextStyle(fontSize: 14, color: Colors.green[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status RTC: ${bluetoothService.isRtcOk ? 'OK' : 'Falha Detectada!'}',
                            style: TextStyle(
                              fontSize: 16,
                              color: bluetoothService.isRtcOk ? Colors.green[700] : Colors.red[700],
                              fontWeight: bluetoothService.isRtcOk ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildMenuButton(
                        context,
                        icon: bluetoothService.isConnected ? Icons.bluetooth_disabled : Icons.bluetooth,
                        label: bluetoothService.isConnected ? 'Desconectar' : 'Conectar',
                        onPressed: () {
                          if (bluetoothService.isConnected) {
                            bluetoothService.disconnect();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ConnectPage()),
                            );
                          }
                        },
                        color: bluetoothService.isConnected ? Colors.red : Colors.blue,
                      ),
                      _buildMenuButton(
                        context,
                        icon: Icons.add_circle_outline,
                        label: 'Cadastrar Planta',
                        onPressed: bluetoothService.isConnected
                            ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPlantPage()))
                            : null,
                        color: Colors.green,
                      ),
                      _buildMenuButton(
                        context,
                        icon: Icons.grass,
                        label: 'Ver Plantas',
                        onPressed: bluetoothService.isConnected
                            ? () {
                                bluetoothService.requestPlantsList();
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlantsListPage()));
                              }
                            : null,
                        color: Colors.orange,
                      ),
                      _buildMenuButton(
                        context,
                        icon: Icons.access_time_filled,
                        label: 'Sincronizar RTC',
                        onPressed: bluetoothService.isConnected
                            ? () => bluetoothService.configureRtc()
                            : null,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: onPressed == null ? Colors.grey[300] : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: onPressed == null ? Colors.grey : color),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onPressed == null ? Colors.grey[600] : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}