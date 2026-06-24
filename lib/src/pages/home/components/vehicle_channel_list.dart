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

  void _showOfflineWarning(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Este veículo parece offline. A câmera pode não carregar.'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Buscar veículo por placa',
              labelStyle: const TextStyle(color: Colors.white),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        searchController.clear();
                      },
                    )
                  : null,
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 1),
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                borderSide: BorderSide(color: Colors.white, width: 1),
              ),
              errorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                borderSide: BorderSide(color: Colors.red, width: 1),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        Expanded(
          child: filteredVehicles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            color: Colors.white54,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum veículo encontrado para a busca atual. Verifique a placa digitada.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          if (searchController.text.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                searchController.clear();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0794bc),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: const Text('Limpar busca'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = filteredVehicles[index];
                    final id = vehicle['deviceSerial'];
                    final selected = widget.selectedChannels[id] ?? [];

                    final isOnline = vehicle['status'] == 'connected';
                    return ExpansionTile(
                      title: Row(
                        children: [
                          Icon(
                            Icons.local_shipping, 
                            color: isOnline ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              vehicle['plate'] ?? 'N/A', 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold,
                                fontSize: 14.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: isOnline 
                                  ? Colors.green.withOpacity(0.15) 
                                  : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(
                                color: isOnline 
                                    ? Colors.green.withOpacity(0.3) 
                                    : Colors.red.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: isOnline ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 10.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        // --- LINHAS REMOVIDAS ---
                        CheckboxListTile(
                          title: Text(
                            'Todos os Canais',
                            style: TextStyle(
                              color: selected.length == 6 ? const Color(0xFF0794bc) : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: selected.length == 6, // Assumindo 6 canais
                          selected: selected.length == 6,
                          selectedTileColor: Colors.white.withOpacity(0.06),
                          onChanged: (bool? val) {
                            for (int i = 1; i <= 6; i++) {
                              widget.onChannelToggle(vehicle, i, val ?? false);
                            }
                            if (val == true && vehicle['status'] != 'connected') {
                              _showOfflineWarning(context);
                            }
                          },
                          checkColor: Colors.white,
                          activeColor: const Color(0xFF0794bc),
                        ),
                        // ------------------------
                        ...List.generate(6, (i) {
                          final channel = i + 1;
                          final isChannelSelected = selected.contains(channel);
                          return CheckboxListTile(
                            title: Text(
                              'Canal $channel',
                              style: TextStyle(
                                color: isChannelSelected ? const Color(0xFF0794bc) : Colors.white,
                                fontWeight: isChannelSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            value: isChannelSelected,
                            selected: isChannelSelected,
                            selectedTileColor: Colors.white.withOpacity(0.06),
                            onChanged: (bool? val) {
                              widget.onChannelToggle(vehicle, channel, val ?? false);
                              if (val == true && vehicle['status'] != 'connected') {
                                _showOfflineWarning(context);
                              }
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
