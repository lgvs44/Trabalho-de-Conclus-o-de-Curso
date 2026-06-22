import 'package:flutter/material.dart';
import 'package:irrigador_inteligente/app_bluetooth_service.dart';
import 'package:irrigador_inteligente/pages/plant_detail_page.dart';
import 'package:provider/provider.dart';

class PlantsListPage extends StatelessWidget {
  const PlantsListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Plantas'),
        backgroundColor: Colors.orange,
      ),
      body: Consumer<AppBluetoothService>(
        builder: (context, bluetoothService, child) {
          if (bluetoothService.plants.isEmpty) {
            return const Center(child: Text('Nenhuma planta cadastrada.'));
          }
          return ListView.builder(
            itemCount: bluetoothService.plants.length,
            itemBuilder: (context, index) {
              final plant = bluetoothService.plants[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(plant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Intervalo: ${plant.irrigationIntervalHours} horas'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PlantDetailPage(plant: plant)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}