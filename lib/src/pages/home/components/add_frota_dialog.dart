// lib/src/pages/home/components/add_frota_dialog.dart
import 'package:flutter/material.dart';

class AddFrotaDialog extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles;
  final Map<String, dynamic>? frotaToEdit;

  const AddFrotaDialog({super.key, required this.vehicles, this.frotaToEdit});

  @override
  State<AddFrotaDialog> createState() => _AddFrotaDialogState();
}

class _AddFrotaDialogState extends State<AddFrotaDialog> {
  final TextEditingController frotaNameController = TextEditingController();
  Map<String, List<int>> vehicleChannels = {};
  late List<Map<String, dynamic>> filteredVehicles;
  ScrollController scrollController = ScrollController();
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredVehicles = widget.vehicles;

    if (widget.frotaToEdit != null) {
      frotaNameController.text = widget.frotaToEdit!['nome'] ?? '';
      final List<dynamic> vehiclesInFrota = widget.frotaToEdit!['vehicles'] ?? [];
      for (var v in vehiclesInFrota) {
        final deviceSerial = v['deviceSerial'];
        final canais = List<int>.from(v['canais'] ?? []);
        vehicleChannels[deviceSerial] = canais;
      }
    }
  }

  void toggleChannel(String vehicleId, int channel, bool isSelected) {
    setState(() {
      vehicleChannels.putIfAbsent(vehicleId, () => []);
      if (isSelected) {
        vehicleChannels[vehicleId]?.add(channel);
      } else {
        vehicleChannels[vehicleId]?.remove(channel);
      }
    });
  }

  void filterVehicles(String query) {
    setState(() {
      filteredVehicles = widget.vehicles.where((vehicle) => (vehicle['plate'] as String).toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _saveFrota() {
    if (frotaNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nome da frota não pode ser vazio!'),
          backgroundColor: Color(0xFF0794bc),
        ),
      );
      return;
    }
    if (vehicleChannels.isEmpty || vehicleChannels.values.every((list) => list.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um veículo e um canal!'),
          backgroundColor: Color(0xFF0794bc),
        ),
      );
      return;
    }

    final selectedVehicles = widget.vehicles
        .where((v) =>
            v['deviceSerial'] != null && // Garante que deviceSerial existe
            vehicleChannels.containsKey(v['deviceSerial'])) // Verifica diretamente a string
        .map((v) {
      // === CORREÇÃO AQUI: Acessa 'deviceSerial' diretamente ===
      final deviceSerial = v['deviceSerial'];
      // ========================================================
      return {
        'plate': v['plate'],
        'canais': vehicleChannels[deviceSerial] ?? [],
        'deviceSerial': deviceSerial,
        'status': v['status'],
      };
    }).toList();

    Navigator.pop(context, {
      'nome': frotaNameController.text,
      'vehicles': selectedVehicles,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.frotaToEdit != null ? 'Editar Frota' : 'Adicionar Frota', style: TextStyle(color: Colors.white)),
            SizedBox(
              height: 100,
              width: 100,
              child: Image.asset('assets/logo-login-alessat-dark.png'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1e262d),
        content: SizedBox(
          width: 500,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              TextField(
                controller: frotaNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da frota',
                  labelStyle: TextStyle(color: Colors.white),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 1),
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Colors.white, width: 1),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Colors.red, width: 1),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar veículo',
                  labelStyle: TextStyle(color: Colors.white),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 1),
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Colors.white, width: 1),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Colors.red, width: 1),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: filterVehicles,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredVehicles.length,
                  itemBuilder: (context, index) {
                    final v = filteredVehicles[index];
                    // === CORREÇÃO AQUI: Acessa 'deviceSerial' diretamente ===
                    final id = v['deviceSerial'];
                    // ========================================================
                    final selected = vehicleChannels[id] ?? [];

                    return ExpansionTile(
                      title: Row(
                        children: [
                          Icon(Icons.directions_car, color: v['status'] == 'connected' ? Colors.green : Colors.red),
                          const SizedBox(width: 8),
                          Text(v['plate'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      children: [
                        CheckboxListTile(
                          title: const Text('Todos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          value: selected.length == 6,
                          onChanged: (val) {
                            if (val == true) {
                              for (int i = 1; i <= 6; i++) {
                                toggleChannel(id, i, true);
                              }
                            } else {
                              for (int i = 1; i <= 6; i++) {
                                toggleChannel(id, i, false);
                              }
                            }
                          },
                        ),
                        ...List.generate(6, (i) {
                          final ch = i + 1;
                          return CheckboxListTile(
                            title: Text('Canal $ch', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            value: selected.contains(ch),
                            onChanged: (val) => toggleChannel(id, ch, val ?? false),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white))),
          TextButton(onPressed: _saveFrota, child: const Text('Salvar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
