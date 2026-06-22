// lib/pages/register_plant_page.dart

import 'package:flutter/material.dart';
import 'package:irrigador_inteligente/app_bluetooth_service.dart';
import 'package:provider/provider.dart';

class RegisterPlantPage extends StatefulWidget {
  final bool isEditing;
  final String? initialName;
  // Adicione outros campos se precisar preencher na edição
  
  const RegisterPlantPage({
    Key? key,
    this.isEditing = false,
    this.initialName,
  }) : super(key: key);

  @override
  State<RegisterPlantPage> createState() => _RegisterPlantPageState();
}

class _RegisterPlantPageState extends State<RegisterPlantPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _waterAmountController = TextEditingController();
  final _intervalController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _nameController.text = widget.initialName ?? '';
      // Preencher outros campos se necessário
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _waterAmountController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _submitPlantData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final bluetoothService = Provider.of<AppBluetoothService>(context, listen: false);
    
    if (widget.isEditing) {
      // Implementar lógica de edição aqui se necessário
    } else {
      await bluetoothService.createPlant(
        name: _nameController.text,
        waterAmount: int.parse(_waterAmountController.text),
        interval: int.parse(_intervalController.text),
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Planta' : 'Cadastrar Nova Planta'),
        backgroundColor: Colors.green,
      ),
      body: WillPopScope(
        onWillPop: () async => !_isLoading,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  readOnly: widget.isEditing,
                  decoration: InputDecoration(
                    labelText: 'Nome da Planta',
                    border: const OutlineInputBorder(),
                    filled: widget.isEditing,
                    fillColor: Colors.grey[200],
                  ),
                  maxLength: 15,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Insira um nome.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _waterAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade de Água (mm)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || int.tryParse(value) == null) return 'Insira um número válido.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Intervalo de Irrigação (horas)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || int.tryParse(value) == null) return 'Insira um número válido.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitPlantData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.isEditing ? 'Salvar' : 'Cadastrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}