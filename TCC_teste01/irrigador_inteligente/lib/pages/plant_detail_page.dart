import 'package:flutter/material.dart';
import 'package:irrigador_inteligente/app_bluetooth_service.dart';
import 'package:irrigador_inteligente/models.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class PlantDetailPage extends StatefulWidget {
  final Plant plant;
  const PlantDetailPage({Key? key, required this.plant}) : super(key: key);

  @override
  State<PlantDetailPage> createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Inicia um timer para atualizar os dados da planta periodicamente
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        Provider.of<AppBluetoothService>(context, listen: false).requestPlantsList();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _deletePlant(BuildContext context, AppBluetoothService service) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir a planta "${widget.plant.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (shouldDelete == true) {
      await service.deletePlant(widget.plant.name);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plant.name),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deletePlant(context, Provider.of<AppBluetoothService>(context, listen: false)),
          ),
        ],
      ),
      body: Consumer<AppBluetoothService>(
        builder: (context, bluetoothService, child) {
          // Encontra a planta mais atualizada na lista do serviço
          final currentPlant = bluetoothService.plants.firstWhere(
            (p) => p.name == widget.plant.name,
            orElse: () => widget.plant, // Se não encontrar, usa a planta inicial
          );

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildInfoCard(
                icon: Icons.water_drop,
                title: 'Umidade do Solo',
                value: '${currentPlant.humidityPercentage.toStringAsFixed(1)}%',
                color: Colors.blue,
              ),
              _buildInfoCard(
                icon: Icons.timer,
                title: 'Próxima Irrigação',
                value: currentPlant.formattedTimeUntilNextIrrigation,
                color: Colors.green,
              ),
              _buildInfoCard(
                icon: Icons.calendar_today,
                title: 'Última Irrigação',
                value: currentPlant.formattedLastIrrigation,
                color: Colors.purple,
              ),
              _buildInfoCard(
                icon: Icons.opacity,
                title: 'Quantidade de Água',
                value: '${currentPlant.waterAmountMm} mm',
                color: Colors.teal,
              ),
              _buildInfoCard(
                icon: Icons.power,
                title: 'Status da Válvula',
                value: currentPlant.isIrrigating ? 'Irrigando...' : 'Desligada',
                color: currentPlant.isIrrigating ? Colors.redAccent : Colors.grey,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}