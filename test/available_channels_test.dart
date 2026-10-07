import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_alessat_app/src/models/available_channels.dart';
import 'package:grupo_alessat_app/src/pages/home/components/vehicle_channel_list.dart';

void main() {
  test('usa register.channels e ignora aliases de canais inexistentes', () {
    final entry = {
      'deviceSerial': '123',
      'device': [
        {
          'register': {
            'channels': [1, 2, 3, 4, 5, 9, 10],
            'channelsAlias': {
              '1': 'Canal 1',
              '6': 'Canal 6',
            },
          },
        },
      ],
    };

    expect(availableChannelsFromDevice(entry), [1, 2, 3, 4, 5, 9, 10]);
  });

  test('aceita o primeiro registro com canais disponíveis', () {
    final entry = {
      'device': [
        {
          'register': {'channels': <int>[]}
        },
        {
          'register': {
            'channels': [5, 1, 5]
          }
        },
      ],
    };

    expect(availableChannelsFromDevice(entry), [1, 5]);
  });

  testWidgets('lista e seleciona somente canais informados pelo veículo',
      (tester) async {
    final toggled = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VehicleChannelList(
          vehicles: const [
            {
              'plate': 'ABC1234',
              'status': 'connected',
              'deviceSerial': '123',
              'channels': [1, 2, 5, 9],
            },
          ],
          selectedChannels: const {},
          onChannelToggle: (_, channel, selected) {
            if (selected) toggled.add(channel);
          },
        ),
      ),
    ));

    await tester.tap(find.text('ABC1234'));
    await tester.pumpAndSettle();
    expect(find.text('Canal 5'), findsOneWidget);
    expect(find.text('Canal 9'), findsOneWidget);
    expect(find.text('Canal 6'), findsNothing);

    await tester.tap(find.text('Todos os Canais'));
    expect(toggled, [1, 2, 5, 9]);
  });
}
