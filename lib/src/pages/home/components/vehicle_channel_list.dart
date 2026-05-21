// lib/src/pages/home/components/vehicle_channel_list.dart
import 'package:flutter/material.dart';

class VehicleChannelList extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles;
  final Function(Map<String, dynamic> vehicle, int channel, bool isSelected) onChannelToggle;
  final Map<String, List<int>> selectedChannels;

  const VehicleChannelList({
    super.key,
    required this.vehicles,
    required this.onChannelToggle,
    required this.selectedChannels,
  });

  @override
  State<VehicleChannelList> createState() => _VehicleChannelListState();
}

class _VehicleChannelListState extends State<VehicleChannelList> {
  late List<Map<String, dynamic>> filteredVehicles;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredVehicles = widget.vehicles;
    searchController.addListener(() {
      filterVehicles(searchController.text);
    });
  }

  @override
  void didUpdateWidget(covariant VehicleChannelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicles != widget.vehicles) {
      filterVehicles(searchController.text);
    }
  }

  void filterVehicles(String query) {
    setState(() {
      filteredVehicles = widget.vehicles.where((vehicle) => (vehicle['plate'] as String).toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar veículo por placa',
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
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredVehicles.length,
            itemBuilder: (context, index) {
              final vehicle = filteredVehicles[index];
              final id = vehicle['deviceSerial'];
              final selected = widget.selectedChannels[id] ?? [];

              return ExpansionTile(
                title: Row(
                  children: [
                    Icon(Icons.directions_car, color: vehicle['status'] == 'connected' ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    Text(vehicle['plate'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                children: [
                  // --- LINHAS REMOVIDAS ---
                  CheckboxListTile(
                    title: const Text('Todos os Canais', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    value: selected.length == 6, // Assumindo 6 canais
                    onChanged: (bool? val) {
                      for (int i = 1; i <= 6; i++) {
                        widget.onChannelToggle(vehicle, i, val ?? false);
                      }
                    },
                    checkColor: Colors.white,
                    activeColor: const Color(0xFF0794bc),
                  ),
                  // ------------------------
                  ...List.generate(6, (i) {
                    final channel = i + 1;
                    return CheckboxListTile(
                      title: Text('Canal $channel', style: const TextStyle(color: Colors.white)),
                      value: selected.contains(channel),
                      onChanged: (bool? val) {
                        widget.onChannelToggle(vehicle, channel, val ?? false);
                      },
                      checkColor: Colors.white,
                      activeColor: const Color(0xFF0794bc),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
