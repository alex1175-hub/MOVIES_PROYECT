import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'auth_pages.dart';
import 'auth_service.dart';
import 'ble_service.dart';
import 'calculadora_page.dart';
import 'historial_page.dart';

final PetStationService servicio = PetStationService();

final GlobalKey<NavigatorState> navegador = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> mensajero = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await auth.iniciar();
  // Avisos de la estación (orden rechazada, dispensado omitido o pendiente) como mensaje en pantalla
  servicio.aviso.addListener(() {
    final t = servicio.aviso.value;
    if (t == null) return;
    mensajero.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Estación: $t'), duration: const Duration(seconds: 6)));
  });
  // Al cerrar sesión (o vencer): se corta el Bluetooth y se vuelve a la pantalla de inicio de sesión
  auth.addListener(() {
    if (!auth.logueado) {
      servicio.desconectar();
      navegador.currentState?.popUntil((r) => r.isFirst);
    }
  });
  runApp(const PetStationApp());
}

class PetStationApp extends StatelessWidget {
  const PetStationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navegador,
      scaffoldMessengerKey: mensajero,
      title: 'PetStation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true, brightness: Brightness.dark),
      home: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => auth.logueado ? const MenuPage() : const LoginPage(),
      ),
    );
  }
}

// =====================================================================
// PANTALLA 1: buscar y conectar
// =====================================================================
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _todos = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _escanear());
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<bool> _permisos() async {
    final r = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final android12 = r[Permission.bluetoothScan]?.isGranted == true &&
        r[Permission.bluetoothConnect]?.isGranted == true;
    final android11 = r[Permission.locationWhenInUse]?.isGranted == true;
    return android12 || android11;
  }

  Future<void> _escanear() async {
    if (!await _permisos()) {
      _aviso('Se necesitan los permisos de Bluetooth para buscar la estación');
      return;
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {}
    }
    try {
      await FlutterBluePlus.startScan(
        withServices: _todos ? <Guid>[] : [PetStationService.serviceUuid],
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      _aviso('No se pudo escanear: $e');
    }
  }

  String _nombre(ScanResult r) {
    final n = r.advertisementData.advName;
    if (n.isNotEmpty) return n;
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    return 'Sin nombre';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: servicio,
      builder: (context, _) {
        final conectando = servicio.estado == EstadoConexion.conectando;
        return Scaffold(
          appBar: AppBar(
            title: const Text('PetStation'),
            actions: [
              IconButton(
                tooltip: 'Buscar de nuevo',
                icon: const Icon(Icons.refresh),
                onPressed: conectando ? null : _escanear,
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'maquinas') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MaquinasPage()));
                  } else if (v == 'salir') {
                    auth.logout();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(enabled: false, child: Text('Usuario: ${auth.usuario ?? ''}')),
                  const PopupMenuItem(value: 'maquinas', child: Text('Mis máquinas')),
                  const PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              StreamBuilder<bool>(
                stream: FlutterBluePlus.isScanning,
                initialData: false,
                builder: (context, snap) => (snap.data ?? false) || conectando
                    ? const LinearProgressIndicator()
                    : const SizedBox(height: 4),
              ),
              if (servicio.ultimoError != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.all(12),
                  child: Text(servicio.ultimoError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                ),
              SwitchListTile(
                title: const Text('Mostrar todos los dispositivos'),
                subtitle: const Text('Por defecto solo aparece "PetStation"'),
                value: _todos,
                onChanged: conectando
                    ? null
                    : (v) {
                        setState(() => _todos = v);
                        _escanear();
                      },
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  initialData: const [],
                  builder: (context, snap) {
                    final lista = [...(snap.data ?? <ScanResult>[])]
                      ..sort((a, b) => b.rssi.compareTo(a.rssi));
                    if (lista.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Buscando la estación PetStation...\n'
                            'Verifica que el ESP32 esté encendido y cerca.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = lista[i];
                        final esNuestra = _nombre(r) == 'PetStation';
                        return ListTile(
                          leading: Icon(esNuestra ? Icons.pets : Icons.bluetooth),
                          title: Text(_nombre(r)),
                          subtitle: Text('${r.device.remoteId.str}   ${r.rssi} dBm'),
                          trailing: FilledButton(
                            onPressed: conectando ? null : () => servicio.conectar(r.device),
                            child: const Text('Conectar'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// PANTALLA 2: monitoreo y control
// =====================================================================
double? _n(Map<String, dynamic>? m, String k) {
  final v = m?[k];
  return v is num ? v.toDouble() : null;
}

String _fmt(double? v, [int d = 1]) => v == null ? '--' : v.toStringAsFixed(d);

String _duracion(num? segundos) {
  if (segundos == null) return '--';
  final s = segundos.round();
  if (s >= 3600 && s % 3600 == 0) return '${s ~/ 3600} h';
  if (s >= 60 && s % 60 == 0) return '${s ~/ 60} min';
  if (s >= 60) return '${s ~/ 60} min ${s % 60} s';
  return '$s s';
}

/// Fila "Plato" + aviso en rojo si el sensor de peso (HX711) no está detectado,
/// igual que con los sensores ultrasónicos.
List<Widget> _filaPlato(Map<String, dynamic>? m, String claveGramos, String claveOk) {
  final estado = m?[claveOk]; // true / false / null (sin dato: firmware o servidor antiguo)
  final sinSensor = estado == false;
  final String texto;
  final int tipo; // 0 = ok, 1 = error, 2 = neutro
  if (estado == false) {
    texto = 'Sensor de peso no detectado / sin lectura';
    tipo = 1;
  } else if (estado == true) {
    texto = 'Sensor de peso detectado';
    tipo = 0;
  } else if (m == null) {
    texto = 'Esperando datos del sensor...';
    tipo = 2;
  } else {
    texto = 'Estado del sensor desconocido (actualiza firmware / base de datos)';
    tipo = 2;
  }
  return [
    _Fila('Plato', sinSensor ? '--' : '${_fmt(_n(m, claveGramos))} g'),
    _AlertaSensor(texto, tipo),
  ];
}

class _AlertaSensor extends StatelessWidget {
  final String texto;
  final int tipo;
  const _AlertaSensor(this.texto, this.tipo);

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final color = tipo == 1 ? esquema.error : (tipo == 0 ? Colors.green.shade700 : esquema.outline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: servicio,
      builder: (context, _) {
        final s = servicio.sensores;
        final p = servicio.programacion;
        final nombre = (servicio.wifi?['nombre'] ?? servicio.dispositivo?.platformName ?? '').toString();
        final tornilloOn = s?['puerta'] == 'ABIERTA';
        final bombaOn = s?['bomba'] == 'ON';
        final uhf = s?['uhf'] == true;

        return Scaffold(
          appBar: AppBar(
            title: Text(nombre.isEmpty ? 'PetStation' : nombre),
            actions: [
              IconButton(
                tooltip: 'Calculadora de programas',
                icon: const Icon(Icons.calculate),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CalculadoraPage(
                    aplicar: (tipo, cantidad, intervaloMin) async {
                      final ok = await servicio.configurar(tipo, cantidad, intervaloMin);
                      return ok ? null : 'No se pudo enviar el programa por Bluetooth';
                    },
                  ),
                )),
              ),
              IconButton(
                tooltip: 'Vincular a mi cuenta',
                icon: const Icon(Icons.link),
                onPressed: () => _vincular(context),
              ),
              IconButton(
                tooltip: 'Desconectar',
                icon: const Icon(Icons.bluetooth_disabled),
                onPressed: servicio.desconectar,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Tarjeta(
                icono: Icons.bluetooth_connected,
                titulo: 'Estación',
                hijos: [
                  _Fila('Estado', servicio.estadoEstacion ?? 'conectado por Bluetooth'),
                  _Fila('Mascota (RFID UHF)', uhf ? 'Detectada' : 'No detectada'),
                  _Fila('Última lectura', s == null ? 'esperando datos...' : _hora(servicio.ultimaActualizacion)),
                ],
              ),
              _tarjetaWifi(context, servicio.wifi),
              _Tarjeta(
                icono: Icons.pets,
                titulo: 'Comida',
                hijos: [
                  _Nivel(
                    etiqueta: 'Contenedor',
                    pct: _n(s, 'contenedor_pct'),
                    alerta: s?['contenedor_vacio'] == true,
                    textoAlerta: s?['contenedor_ok'] == false ? 'Sin lectura del sensor' : 'Contenedor vacío',
                  ),
                  ..._filaPlato(s, 'plato_comida_g', 'plato_comida_ok'),
                  _Fila('Tornillo sin fin', tornilloOn ? 'Girando' : 'Detenido'),
                  _Fila('Modo', '${s?['modo_puerta'] ?? '--'}'),
                  _Botones(
                    onEncender: () => servicio.setTornillo(true),
                    onApagar: () => servicio.setTornillo(false),
                  ),
                ],
              ),
              _Tarjeta(
                icono: Icons.water_drop,
                titulo: 'Agua',
                hijos: [
                  _Nivel(
                    etiqueta: 'Tanque',
                    pct: _n(s, 'tanque_pct'),
                    alerta: s?['tanque_vacio'] == true,
                    textoAlerta: s?['tanque_ok'] == false ? 'Sin lectura del sensor' : 'Tanque vacío',
                  ),
                  ..._filaPlato(s, 'plato_agua_g', 'plato_agua_ok'),
                  _Fila('Bomba', bombaOn ? 'Encendida' : 'Apagada'),
                  _Fila('Modo', '${s?['modo_bomba'] ?? '--'}'),
                  _Botones(
                    onEncender: () => servicio.setBomba(true),
                    onApagar: () => servicio.setBomba(false),
                  ),
                ],
              ),
              _tarjetaPrograma(context, 'comida', 'Programa de comida', Icons.schedule, p),
              _tarjetaPrograma(context, 'agua', 'Programa de agua', Icons.schedule, p),
              const _ConsolaCard(),
            ],
          ),
        );
      },
    );
  }

  // Guarda esta estación en la cuenta del usuario (usa la dirección Bluetooth como ID de máquina)
  Future<void> _vincular(BuildContext context) async {
    final d = servicio.dispositivo;
    if (d == null) return;
    final id = (servicio.wifi?['id'] ?? d.remoteId.str).toString();
    final nombreEst = (servicio.wifi?['nombre'] ?? d.platformName).toString();
    final nombre = nombreEst.isEmpty ? null : nombreEst;
    String mensaje;
    try {
      await auth.agregarMaquina(id, nombre);
      mensaje = 'Estación $id vinculada a tu cuenta';
    } on ApiException catch (e) {
      mensaje = e.mensaje;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  static String _hora(DateTime? h) {
    if (h == null) return '--';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(h.hour)}:${dos(h.minute)}:${dos(h.second)}';
  }

  Widget _tarjetaWifi(BuildContext context, Map<String, dynamic>? w) {
    final conectado = w?['conectado'] == true;
    final probando = w?['probando'] == true;
    final ssid = (w?['ssid'] ?? '').toString();
    return _Tarjeta(
      icono: conectado ? Icons.wifi : Icons.wifi_off,
      titulo: 'WiFi de la estación',
      hijos: [
        _Fila('Red', ssid.isEmpty ? '--' : ssid),
        _Fila('Estado', probando ? 'Probando red nueva...' : (w == null ? '--' : (conectado ? 'Conectado' : 'Sin conexión'))),
        _Fila('IP', conectado ? '${w?['ip']}' : '--'),
        _Fila('Señal', conectado ? '${w?['rssi']} dBm' : '--'),
        _Fila('Servidor MQTT', w == null ? '--' : (w['mqtt'] == true ? 'Conectado' : 'Sin conexión')),
        _Fila('Nombre de la estación', '${w?['nombre'] ?? '--'}'),
        _Fila('ID de la estación', '${w?['id'] ?? '--'}'),
        _Fila('Base de datos', '${w?['nube'] ?? '--'}'),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('Configurar WiFi'),
            onPressed: probando ? null : () => _configurarWifi(context),
          ),
        ),
      ],
    );
  }

  Future<void> _configurarWifi(BuildContext context) async {
    final idMaquina = (servicio.wifi?['id'] ?? '').toString();
    final usuarioId = auth.usuarioId;
    if (idMaquina.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La estación aún no envió su ID. Espera unos segundos e inténtalo de nuevo.')));
      return;
    }
    if (usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se conoce tu ID de usuario. Cierra sesión y vuelve a entrar.')));
      return;
    }

    final nombreC = TextEditingController(text: (servicio.wifi?['nombre'] ?? '').toString());
    final ssid = TextEditingController();
    final clave = TextEditingController();
    final apiC = TextEditingController(text: auth.servidor);
    var ver = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Configurar estación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreC,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Nombre de la estación', helperText: 'Ej. Comedero de Max'),
                ),
                TextField(
                  controller: ssid,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Red WiFi (SSID)',
                    helperText: 'Déjalo vacío para cambiar solo el nombre',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: clave,
                  obscureText: !ver,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Contraseña del WiFi',
                    helperText: 'De 8 a 63 caracteres. Vacía si la red es abierta.',
                    suffixIcon: IconButton(
                      icon: Icon(ver ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => ver = !ver),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: apiC,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de la base de datos (API)',
                    helperText: 'La que usará la estación: http://IP-DE-TU-PC/petstation_api',
                    helperMaxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
          ],
        ),
      ),
    );
    final nombre = nombreC.text.trim();
    final red = ssid.text.trim();
    final pass = clave.text;
    var api = apiC.text.trim();
    nombreC.dispose();
    ssid.dispose();
    clave.dispose();
    apiC.dispose();
    if (ok != true || !context.mounted) return;

    while (api.endsWith('/')) {
      api = api.substring(0, api.length - 1);
    }
    String? error;
    if (nombre.isEmpty || nombre.length > 40) {
      error = 'Escribe el nombre de la estación (máximo 40 caracteres)';
    } else if (red.length > 32) {
      error = 'El nombre de la red admite máximo 32 caracteres';
    } else if (red.isNotEmpty && pass.isNotEmpty && (pass.length < 8 || pass.length > 63)) {
      error = 'La contraseña debe tener de 8 a 63 caracteres';
    } else if (!api.startsWith('http://') && !api.startsWith('https://')) {
      error = 'La dirección de la API debe empezar con http://';
    } else if (RegExp(r'//(localhost|127\.0\.0\.1|10\.0\.2\.2)([:/]|$)').hasMatch(api)) {
      error = 'La estación no puede usar localhost ni 10.0.2.2: escribe la IP de tu PC (ej. http://192.168.1.50/petstation_api)';
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    bool enviado;
    try {
      // 1) El servidor vincula la estación a tu cuenta y entrega la clave con la que enviará sus datos
      final prov = await auth.provisionarMaquina(idMaquina, nombre);
      // 2) Todo se manda a la estación por Bluetooth: nombre, ID de usuario, base de datos y WiFi
      final cfg = <String, dynamic>{
        'nombre': nombre,
        'usuario_id': prov['usuario_id'] ?? usuarioId,
        'api': api,
        'clave': prov['clave'],
        if (red.isNotEmpty) 'ssid': red,
        if (red.isNotEmpty) 'password': pass,
      };
      enviado = await servicio.configurarEstacion(cfg);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(enviado
          ? (red.isEmpty
              ? 'Enviado. La estación guardó el nombre y los datos de tu cuenta.'
              : 'Enviado. La estación probará la red unos 20 s; si conecta, empezará a enviar sus datos a la base de datos.')
          : 'No se pudo enviar la configuración por Bluetooth'),
    ));
  }

  Widget _tarjetaPrograma(BuildContext context, String clave, String titulo, IconData icono, Map<String, dynamic>? p) {
    final d = p?[clave] is Map<String, dynamic> ? p![clave] as Map<String, dynamic> : null;
    final unidad = d?['unidad'] ?? (clave == 'comida' ? 'g' : 'ml');
    final dispensando = d?['dispensando'] == true;
    return _Tarjeta(
      icono: icono,
      titulo: titulo,
      hijos: [
        _Fila('Cantidad', d == null ? '--' : '${_fmt(_n(d, 'cantidad'))} $unidad'),
        _Fila('Cada', _duracion(_n(d, 'intervalo_s'))),
        _Fila('Siguiente en', dispensando ? 'Dispensando ahora...' : _duracion(_n(d, 'proximo_s'))),
        _Fila('Último entregado', d == null ? '--' : '${_fmt(_n(d, 'ultimo_entregado'))} $unidad'),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Cambiar programa'),
            onPressed: () => _editarPrograma(context, clave, titulo, d),
          ),
        ),
      ],
    );
  }

  Future<void> _editarPrograma(BuildContext context, String clave, String titulo, Map<String, dynamic>? actual) async {
    final unidad = clave == 'comida' ? 'g' : 'ml';
    final cantidad = TextEditingController(text: _n(actual, 'cantidad')?.toStringAsFixed(0) ?? '');
    final intervaloS = _n(actual, 'intervalo_s');
    final intervalo = TextEditingController(
        text: intervaloS == null ? '' : (intervaloS / 60).toStringAsFixed(intervaloS % 60 == 0 ? 0 : 1));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cantidad,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cantidad por ración ($unidad)',
                helperText: clave == 'comida' ? 'De 5 a 200 g' : 'De 20 a 500 ml',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: intervalo,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Intervalo (minutos)',
                helperText: 'De 0.5 min a 1440 min (24 h)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final c = double.tryParse(cantidad.text.trim().replaceAll(',', '.'));
    final i = double.tryParse(intervalo.text.trim().replaceAll(',', '.'));
    if (c == null || i == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe números válidos')));
      return;
    }
    await servicio.configurar(clave, c, i);
  }
}

// ---------------------------------------------------------------- widgets
class _Tarjeta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final List<Widget> hijos;
  const _Tarjeta({required this.icono, required this.titulo, required this.hijos});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icono),
              const SizedBox(width: 8),
              Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            for (final h in hijos) ...[h, const SizedBox(height: 8)],
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _Fila(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta),
        Flexible(child: Text(valor, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
  }
}

class _Nivel extends StatelessWidget {
  final String etiqueta;
  final double? pct;
  final bool alerta;
  final String textoAlerta;
  const _Nivel({required this.etiqueta, required this.pct, required this.alerta, required this.textoAlerta});

  @override
  Widget build(BuildContext context) {
    final color = alerta ? Theme.of(context).colorScheme.error : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etiqueta),
            Text('${_fmt(pct, 0)} %', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: ((pct ?? 0) / 100).clamp(0.0, 1.0),
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
          color: color,
        ),
        if (alerta)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(textoAlerta, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _Botones extends StatelessWidget {
  final VoidCallback onEncender;
  final VoidCallback onApagar;
  const _Botones({required this.onEncender, required this.onApagar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onEncender,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Encender'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onApagar,
            icon: const Icon(Icons.stop),
            label: const Text('Apagar'),
          ),
        ),
      ],
    );
  }
}

class _ConsolaCard extends StatefulWidget {
  const _ConsolaCard();

  @override
  State<_ConsolaCard> createState() => _ConsolaCardState();
}

class _ConsolaCardState extends State<_ConsolaCard> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final linea = _texto.text;
    if (linea.trim().isEmpty) return;
    final ok = await servicio.enviarLinea(linea);
    if (ok) _texto.clear();
  }

  @override
  Widget build(BuildContext context) {
    final eventos = servicio.eventos.take(40).toList();
    return _Tarjeta(
      icono: Icons.terminal,
      titulo: 'Eventos y comandos',
      hijos: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _texto,
                decoration: const InputDecoration(
                  hintText: 'puerta ON  /  bomba OFF  /  comida {"cantidad":40}',
                  isDense: true,
                ),
                onSubmitted: (_) => _enviar(),
              ),
            ),
            IconButton(onPressed: _enviar, icon: const Icon(Icons.send)),
          ],
        ),
        if (eventos.isEmpty)
          const Text('Sin eventos todavía')
        else
          for (final e in eventos)
            Text(e, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      ],
    );
  }
}


// =====================================================================
// MENÚ PRINCIPAL (después de iniciar sesión)
// =====================================================================
class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('PetStation'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: auth.logout,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 26, child: Icon(Icons.person, size: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hola,'),
                      Text(auth.usuario ?? '',
                          style: Theme.of(context).textTheme.headlineSmall, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _OpcionMenu(
              icono: Icons.bluetooth,
              titulo: 'Configuración por Bluetooth',
              descripcion: 'Conéctate a la estación que tienes cerca para verla en vivo, controlarla y configurar su WiFi.',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BluetoothFlow())),
            ),
            const SizedBox(height: 12),
            _OpcionMenu(
              icono: Icons.cloud,
              titulo: 'Configuración en línea',
              descripcion: 'Elige una de tus máquinas y consulta desde el servidor los datos que ha guardado.',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnlineMaquinasPage())),
            ),
            const SizedBox(height: 12),
            _OpcionMenu(
              icono: Icons.calculate,
              titulo: 'Calculadora de programas',
              descripcion: 'Calcula cuánta comida y agua sugerir según si es perro o gato, su tamaño, edad y peso.',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalculadoraPage())),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionMenu extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;
  const _OpcionMenu({required this.icono, required this.titulo, required this.descripcion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icono, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(descripcion),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opción 1: la pantalla de búsqueda o, ya conectado, el panel en vivo.
class BluetoothFlow extends StatelessWidget {
  const BluetoothFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: servicio,
      builder: (context, _) =>
          servicio.estado == EstadoConexion.conectado ? const DashboardPage() : const ScanPage(),
    );
  }
}

// =====================================================================
// OPCIÓN 2: CONFIGURACIÓN EN LÍNEA (datos traídos del servidor / base de datos)
// =====================================================================
class OnlineMaquinasPage extends StatefulWidget {
  const OnlineMaquinasPage({super.key});

  @override
  State<OnlineMaquinasPage> createState() => _OnlineMaquinasPageState();
}

class _OnlineMaquinasPageState extends State<OnlineMaquinasPage> {
  late Future<List<Maquina>> _futuro = auth.maquinas();

  void _recargar() => setState(() => _futuro = auth.maquinas());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis máquinas'),
        actions: [IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _recargar)],
      ),
      body: FutureBuilder<List<Maquina>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _recargar, child: const Text('Reintentar')),
                  ],
                ),
              ),
            );
          }
          final lista = snap.data ?? [];
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no tienes máquinas.\nConfigura una estación por Bluetooth para vincularla a tu cuenta.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.separated(
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = lista[i];
                return ListTile(
                  leading: const Icon(Icons.pets),
                  title: Text(m.nombre ?? m.id),
                  subtitle: Text(m.id),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => OnlineDashboardPage(maquina: m))),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Misma información que el panel Bluetooth, pero leída de la base de datos (solo lectura).
class OnlineDashboardPage extends StatefulWidget {
  final Maquina maquina;
  const OnlineDashboardPage({super.key, required this.maquina});

  @override
  State<OnlineDashboardPage> createState() => _OnlineDashboardPageState();
}

class _OnlineDashboardPageState extends State<OnlineDashboardPage> {
  Map<String, dynamic>? _datos;
  String? _error;
  bool _cargando = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _cargar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    try {
      final d = await auth.estadoMaquina(widget.maquina.id);
      if (!mounted) return;
      setState(() {
        _datos = d;
        _error = null;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  static String _hace(num? s) {
    if (s == null) return '--';
    final n = s.round();
    if (n < 60) return 'hace $n s';
    if (n < 3600) return 'hace ${n ~/ 60} min';
    if (n < 86400) return 'hace ${n ~/ 3600} h';
    return 'hace ${n ~/ 86400} d';
  }

  static String _fechaCorta(dynamic f) {
    final t = f?.toString() ?? '';
    return t.length >= 16 ? t.substring(5, 16) : t;
  }

  Map<String, dynamic>? _mapa(dynamic v) => v is Map<String, dynamic> ? v : null;

  Widget _programa(String tipo, String titulo, Map<String, dynamic>? p, String unidad) {
    return _Tarjeta(
      icono: Icons.schedule,
      titulo: titulo,
      hijos: [
        if (p == null)
          const Text('Sin programa guardado todavía')
        else ...[
          _Fila('Cantidad', '${_fmt(_n(p, 'cantidad'))} $unidad'),
          _Fila('Cada', _duracion(_n(p, 'intervalo_s'))),
          _Fila('Actualizado', _fechaCorta(p['actualizado_en'])),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Cambiar programa'),
            onPressed: () => _editarPrograma(tipo, titulo, p, unidad),
          ),
        ),
      ],
    );
  }

  /// Guarda el programa en el servidor. La estación lo revisa cada minuto y, si cambió, lo actualiza.
  Future<void> _editarPrograma(String tipo, String titulo, Map<String, dynamic>? p, String unidad) async {
    final cantC = TextEditingController(text: _n(p, 'cantidad')?.toStringAsFixed(0) ?? '');
    final intS = _n(p, 'intervalo_s');
    final intC = TextEditingController(
        text: intS == null ? '' : (intS / 60).toStringAsFixed(intS % 60 == 0 ? 0 : 1));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cantC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cantidad por ración ($unidad)',
                  helperText: tipo == 'comida' ? 'De 5 a 200 g' : 'De 20 a 500 ml',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: intC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Intervalo (minutos)',
                  helperText: 'De 0.5 min a 1440 min (24 h)',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'La estación revisa el servidor cada minuto y actualiza su programa si hubo cambios.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final c = double.tryParse(cantC.text.trim().replaceAll(',', '.'));
    final i = double.tryParse(intC.text.trim().replaceAll(',', '.'));
    if (c == null || i == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe números válidos')));
      return;
    }
    try {
      await auth.guardarPrograma(widget.maquina.id, tipo, c, (i * 60).round());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado. La estación lo aplicará en su próxima consulta (hasta 1 min).')));
      await _cargar(silencioso: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _datos;
    final l = _mapa(d?['lectura']);
    final programas = _mapa(d?['programas']);
    final dispensados = d?['dispensados'] is List ? (d!['dispensados'] as List).whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
    final eventos = d?['eventos'] is List ? (d!['eventos'] as List).whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
    final maq = _mapa(d?['maquina']);
    final haceS = _n(l, 'hace_s');
    final enLinea = haceS != null && haceS < 120;
    final nombre = (maq?['nombre'] ?? widget.maquina.nombre ?? widget.maquina.id).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(nombre),
        actions: [
          IconButton(
            tooltip: 'Calculadora de programas',
            icon: const Icon(Icons.calculate),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CalculadoraPage(
                aplicar: (tipo, cantidad, intervaloMin) async {
                  try {
                    await auth.guardarPrograma(widget.maquina.id, tipo, cantidad, (intervaloMin * 60).round());
                    _cargar(silencioso: true);
                    return null;
                  } on ApiException catch (e) {
                    return e.mensaje;
                  }
                },
              ),
            )),
          ),
          IconButton(
            tooltip: 'Historial y estadísticas',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HistorialPage(maquina: widget.maquina)),
            ),
          ),
          IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _cargando && d == null
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'No se pudieron cargar los datos', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('No se pudo actualizar: $_error',
                              style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                      _Tarjeta(
                        icono: Icons.cloud_done,
                        titulo: 'Estación (datos del servidor)',
                        hijos: [
                          _Fila('Nombre', nombre),
                          _Fila('ID', widget.maquina.id),
                          _Fila('Estado', l == null ? 'Sin lecturas guardadas' : (enLinea ? 'En línea' : 'Sin datos recientes')),
                          _Fila('Última lectura', l == null ? '--' : '${_hace(haceS)} (${_fechaCorta(l['fecha'])})'),
                          _Fila('Mascota (RFID UHF)', l?['uhf'] == true ? 'Detectada' : (l == null ? '--' : 'No detectada')),
                          const Text('Vista de solo lectura. Para encender el tornillo o la bomba usa la opción Bluetooth.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      _Tarjeta(
                        icono: Icons.pets,
                        titulo: 'Comida',
                        hijos: [
                          _Nivel(
                            etiqueta: 'Contenedor',
                            pct: _n(l, 'contenedor_pct'),
                            alerta: l?['contenedor_vacio'] == true,
                            textoAlerta: l?['contenedor_ok'] == false ? 'Sin lectura del sensor' : 'Contenedor vacío',
                          ),
                          ..._filaPlato(l, 'plato_comida_g', 'plato_comida_ok'),
                          _Fila('Tornillo sin fin', l == null ? '--' : (l['puerta'] == 'ABIERTA' ? 'Girando' : 'Detenido')),
                          _Fila('Modo', '${l?['modo_puerta'] ?? '--'}'),
                        ],
                      ),
                      _Tarjeta(
                        icono: Icons.water_drop,
                        titulo: 'Agua',
                        hijos: [
                          _Nivel(
                            etiqueta: 'Tanque',
                            pct: _n(l, 'tanque_pct'),
                            alerta: l?['tanque_vacio'] == true,
                            textoAlerta: l?['tanque_ok'] == false ? 'Sin lectura del sensor' : 'Tanque vacío',
                          ),
                          ..._filaPlato(l, 'plato_agua_g', 'plato_agua_ok'),
                          _Fila('Bomba', l == null ? '--' : (l['bomba'] == 'ON' ? 'Encendida' : 'Apagada')),
                          _Fila('Modo', '${l?['modo_bomba'] ?? '--'}'),
                        ],
                      ),
                      _programa('comida', 'Programa de comida', _mapa(programas?['comida']), 'g'),
                      _programa('agua', 'Programa de agua', _mapa(programas?['agua']), 'ml'),
                      _Tarjeta(
                        icono: Icons.history,
                        titulo: 'Últimas raciones',
                        hijos: dispensados.isEmpty
                            ? [const Text('Todavía no hay raciones registradas')]
                            : [
                                for (final r in dispensados)
                                  Text(
                                    '${_fechaCorta(r['fecha'])}  ${r['tipo']}: '
                                    '${_fmt(_n(r, 'cantidad_entregada'))} de ${_fmt(_n(r, 'cantidad_objetivo'))} '
                                    '${r['tipo'] == 'comida' ? 'g' : 'ml'} (${r['resultado']})',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                              ],
                      ),
                      _Tarjeta(
                        icono: Icons.terminal,
                        titulo: 'Eventos recientes',
                        hijos: eventos.isEmpty
                            ? [const Text('Sin eventos')]
                            : [
                                for (final e in eventos)
                                  Text('${_fechaCorta(e['fecha'])}  ${e['mensaje']}',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                              ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
