import 'package:flutter_test/flutter_test.dart';

import 'package:petstation_app/ble_service.dart';
import 'package:petstation_app/main.dart';
import 'package:petstation_app/auth_service.dart';

void main() {
  test('Maquina.fromJson tolera campos nulos', () {
    final maquina =
        Maquina.fromJson({'id_maquina': null, 'nombre': 'Comedero'});

    expect(maquina.id, isEmpty);
    expect(maquina.nombre, 'Comedero');
  });

  testWidgets('PetStation dashboard renders when connected', (tester) async {
    servicio.estado = EstadoConexion.conectado;
    auth.token = 'test-token';
    auth.usuario = 'test-user';
    addTearDown(() {
      servicio.estado = EstadoConexion.desconectado;
      auth.token = null;
      auth.usuario = null;
    });

    await tester.pumpWidget(const PetStationApp());
    await tester.tap(find.text('Configuración por Bluetooth'));
    await tester.pumpAndSettle();

    expect(find.text('PetStation'), findsOneWidget);
    expect(find.text('WiFi de la estación'), findsOneWidget);
  });
}
