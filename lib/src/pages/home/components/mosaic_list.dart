// src/pages/home/components/mosaic_list.dart
import 'package:flutter/material.dart';

class MosaicList extends StatefulWidget {
  final List<Map<String, dynamic>> mosaics;
  final void Function(Map<String, dynamic>) onLoad;
  final void Function(int) onDelete;
  final void Function(Map<String, dynamic> mosaic) onEdit; // Novo callback para edição

  const MosaicList({
    super.key,
    required this.mosaics,
    required this.onLoad,
    required this.onDelete,
    required this.onEdit, // Requerer o novo callback
  });

  @override
  State<MosaicList> createState() => _MosaicListState();
}

class _MosaicListState extends State<MosaicList> {
  int? expandedIndex;
  int? expandedFrotaIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: widget.mosaics.length,
            itemBuilder: (context, index) {
              final mosaic = widget.mosaics[index];
              final isExpanded = expandedIndex == index;

              return Card(
                color: const Color(0xFF2a333a),
                margin: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        mosaic['nome'] ?? 'Sem nome',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                            onPressed: () => widget.onEdit(mosaic),
                          ),
                          IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                expandedIndex = isExpanded ? null : index;
                                expandedFrotaIndex = null;
                              });
                            },
                          ),
                          IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () => widget.onDelete(index),
                          ),
                        ],
                      ),
                    ),
                    if (isExpanded)
                      ...List.generate((mosaic['frotas'] as List).length, (frotaIndex) {
                        final frota = (mosaic['frotas'] as List)[frotaIndex];
                        return ExpansionTile(
                          title: Text(
                            frota['nome'] ?? 'Frota sem nome',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                          collapsedIconColor: Colors.white70,
                          iconColor: Colors.white70,
                          leading: const Icon(Icons.directions_car, color: Colors.white54),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                            onPressed: () => widget.onLoad(frota),
                          ),
                          onExpansionChanged: (expanded) {
                            setState(() {
                              expandedFrotaIndex = expanded ? frotaIndex : null;
                            });
                          },
                          children: [
                            ...(frota['itens'] as List).map<Widget>((item) {
                              final veiculo = item['veiculo'];
                              final canal = item['canal'];
                              return ListTile(
                                title: Text(
                                  veiculo['plate'] ?? 'Veículo sem nome',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  'Canal $canal',
                                  style: const TextStyle(color: Colors.white60),
                                ),
                                leading: Icon(Icons.local_shipping, color: veiculo['status'] != 'disconnected' ? Colors.green : Colors.red),
                              );
                            })
                          ],
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
