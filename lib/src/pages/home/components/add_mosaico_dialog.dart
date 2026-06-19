// add_mosaico_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Importar Riverpod
import 'package:grupo_alessat_app/src/pages/home/components/add_frota_dialog.dart';
import 'package:grupo_alessat_app/src/providers/mosaics_provider.dart'; // Importar provedor

class AddMosaicoDialog extends ConsumerStatefulWidget {
  // Mudar para ConsumerStatefulWidget
  final List<Map<String, dynamic>> vehicles;
  final Future<void> Function() onSave;
  final Map<String, dynamic>? mosaicToEdit;

  const AddMosaicoDialog({
    super.key,
    required this.vehicles,
    required this.onSave,
    this.mosaicToEdit,
  });

  @override
  ConsumerState<AddMosaicoDialog> createState() => _AddMosaicoDialogState(); // Mudar o estado
}

class _AddMosaicoDialogState extends ConsumerState<AddMosaicoDialog> {
  // Mudar para ConsumerState
  final TextEditingController mosaicNameController = TextEditingController();
  final List<Map<String, dynamic>> frotasSalvas = [];

  bool _isEditing = false;
  String _originalMosaicName = ''; // Para identificar o mosaico a ser editado

  @override
  void initState() {
    super.initState();
    if (widget.mosaicToEdit != null) {
      _isEditing = true;
      mosaicNameController.text = widget.mosaicToEdit!['nome'] ?? '';
      _originalMosaicName = widget.mosaicToEdit!['nome'] ?? '';

      final List<dynamic> frotas = widget.mosaicToEdit!['frotas'] ?? [];
      for (var frota in frotas) {
        final List<Map<String, dynamic>> vehiclesInFrota = [];
        final Map<String, Map<String, dynamic>> groupedVehicles = {};

        for (var item in (frota['itens'] as List)) {
          final String deviceSerial = item['veiculo']['deviceSerial'];
          final int canal = item['canal'];

          if (!groupedVehicles.containsKey(deviceSerial)) {
            groupedVehicles[deviceSerial] = {
              'plate': item['veiculo']['plate'],
              'canais': <int>[],
              'deviceSerial': deviceSerial,
              'status': item['veiculo']['status'],
            };
          }
          (groupedVehicles[deviceSerial]!['canais'] as List<int>).add(canal);
        }
        vehiclesInFrota.addAll(groupedVehicles.values);

        frotasSalvas.add({
          'nome': frota['nome'],
          'vehicles': vehiclesInFrota,
        });
      }
    }
  }

  void _openAddFrotaDialog({Map<String, dynamic>? frotaToEdit}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddFrotaDialog(
        vehicles: widget.vehicles,
        frotaToEdit: frotaToEdit,
      ),
    );

    if (result != null) {
      setState(() {
        if (frotaToEdit != null) {
          final index = frotasSalvas.indexOf(frotaToEdit);
          if (index != -1) {
            frotasSalvas[index] = result;
          }
        } else {
          frotasSalvas.add(result);
        }
      });
    }
  }

  void _deleteFrota(int index) {
    setState(() {
      frotasSalvas.removeAt(index);
    });
  }

  void _saveMosaic() async {
    final nome = mosaicNameController.text.trim();
    if (nome.isEmpty || frotasSalvas.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha o nome e adicione pelo menos uma frota')),
        );
      }
      return;
    }

    final mosaicoFormatado = {
      'nome': nome,
      'frotas': frotasSalvas.map((frota) {
        final List itens = [];

        for (var veiculo in frota['vehicles']) {
          final plate = veiculo['plate'];
          final deviceSerial = veiculo['deviceSerial'];
          final canais = veiculo['canais'] ?? [];
          final status = veiculo['status'];

          for (var canal in canais) {
            itens.add({
              'canal': canal,
              'veiculo': {
                'plate': plate,
                'deviceSerial': deviceSerial,
                'status': status,
              }
            });
          }
        }

        return {
          'nome': frota['nome'],
          'itens': itens,
        };
      }).toList(),
    };

    if (_isEditing) {
      // Chamar o notifier para atualizar o mosaico
      await ref.read(mosaicsProvider.notifier).updateMosaic(_originalMosaicName, mosaicoFormatado);
    } else {
      // Chamar o notifier para adicionar o mosaico
      await ref.read(mosaicsProvider.notifier).addMosaic(mosaicoFormatado);
    }

    if (context.mounted) {
      Navigator.pop(context);
    }

    widget.onSave(); // Notifica a HomePage para recarregar os dados (que agora são carregados pelo provider)
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_isEditing ? 'Editar Mosaico' : 'Adicionar Mosaico', style: const TextStyle(color: Colors.white)),
          SizedBox(
            height: 100,
            width: 100,
            child: Image.asset('assets/logo-login-alessat-dark.png'),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1e262d),
      content: SizedBox(
        width: 600,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            TextField(
              controller: mosaicNameController,
              decoration: const InputDecoration(
                labelText: 'Nome do mosaico',
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
            ElevatedButton.icon(
              onPressed: () => _openAddFrotaDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Frotas'),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(const Color(0xFF0794bc)),
                foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: frotasSalvas.length,
                itemBuilder: (context, index) {
                  final frota = frotasSalvas[index];
                  return Card(
                    color: const Color(0xFF2a333a),
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ExpansionTile(
                      title: Text('Frota: ${frota['nome']}', style: const TextStyle(color: Colors.white)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => _openAddFrotaDialog(frotaToEdit: frota),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _deleteFrota(index),
                          ),
                        ],
                      ),
                      children: (frota['vehicles'] as List).map<Widget>((v) {
                        final plate = v['plate'];
                        final canais = (v['canais'] as List).join(', ');
                        return ListTile(
                          title: Text('Veículo: $plate', style: const TextStyle(color: Colors.white)),
                          subtitle: Text('Canais: $canais', style: const TextStyle(color: Colors.grey)),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white))),
        TextButton(onPressed: _saveMosaic, child: const Text('Salvar', style: TextStyle(color: Colors.white))),
      ],
    );
  }
}
