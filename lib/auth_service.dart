import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String mensaje;
  final int? codigo; // código HTTP; null si no hubo conexión
  ApiException(this.mensaje, [this.codigo]);

  @override
  String toString() => mensaje;
}

class Maquina {
  final String id;
  final String? nombre;
  Maquina(this.id, this.nombre);

  factory Maquina.fromJson(Map<String, dynamic> j) =>
      Maquina(j['id_maquina'].toString(), j['nombre']?.toString());
}

/// Registro, inicio de sesión y máquinas del usuario (API PHP + MySQL).
class AuthService extends ChangeNotifier {
  static const _kServidor = 'servidor';
  static const _kToken = 'token';
  static const _kUsuario = 'usuario';
  static const _kUsuarioId = 'usuario_id';

  /// 10.0.2.2 es el PC visto desde el emulador de Android.
  /// En un celular real usa la IP de tu PC, por ejemplo http://192.168.1.50/petstation_api
  static const servidorDefecto = 'http://10.0.2.2/petstation_api';

  String servidor = servidorDefecto;
  String? token;
  String? usuario;
  int? usuarioId; // ID del usuario en la base de datos (se envía a la estación)
  SharedPreferences? _prefs;

  bool get logueado => token != null && usuario != null;

  /// Carga la sesión guardada y comprueba que siga vigente.
  Future<void> iniciar() async {
    _prefs = await SharedPreferences.getInstance();
    servidor = _prefs!.getString(_kServidor) ?? servidorDefecto;
    token = _prefs!.getString(_kToken);
    usuario = _prefs!.getString(_kUsuario);
    usuarioId = _prefs!.getInt(_kUsuarioId);
    if (logueado) {
      try {
        final d = await _llamar('GET', 'me.php');
        final u = d['usuario'];
        if (u is Map) {
          usuarioId = int.tryParse('${u['id']}');
          if (usuarioId != null) await _prefs?.setInt(_kUsuarioId, usuarioId!);
        }
      } on ApiException {
        // Sin conexión: se conserva la sesión. Si el servidor responde 401, _llamar la cierra.
      }
    }
  }

  Future<void> cambiarServidor(String url) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isEmpty) u = servidorDefecto;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    servidor = u;
    await _prefs?.setString(_kServidor, servidor);
    notifyListeners();
  }

  Future<void> login(String nombre, String password) => _autenticar('login.php', nombre, password);

  Future<void> registrar(String nombre, String password) => _autenticar('register.php', nombre, password);

  Future<void> _autenticar(String archivo, String nombre, String password) async {
    final d = await _llamar('POST', archivo, cuerpo: {'nombre': nombre, 'password': password});
    final t = d['token']?.toString();
    if (t == null) throw ApiException('Respuesta inválida del servidor');
    token = t;
    usuario = (d['usuario'] is Map ? (d['usuario'] as Map)['nombre']?.toString() : null) ?? nombre;
    usuarioId = d['usuario'] is Map ? int.tryParse('${(d['usuario'] as Map)['id']}') : null;
    await _prefs?.setString(_kToken, token!);
    await _prefs?.setString(_kUsuario, usuario!);
    if (usuarioId != null) await _prefs?.setInt(_kUsuarioId, usuarioId!);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _llamar('POST', 'logout.php');
    } catch (_) {}
    await _cerrarLocal();
  }

  Future<void> _cerrarLocal() async {
    token = null;
    usuario = null;
    usuarioId = null;
    await _prefs?.remove(_kToken);
    await _prefs?.remove(_kUsuario);
    await _prefs?.remove(_kUsuarioId);
    notifyListeners();
  }

  // ------------------------------------------------------------ máquinas
  Future<List<Maquina>> maquinas() async {
    final d = await _llamar('GET', 'maquinas.php');
    final lista = d['maquinas'];
    if (lista is! List) return [];
    return lista.whereType<Map<String, dynamic>>().map(Maquina.fromJson).toList();
  }

  Future<void> agregarMaquina(String id, String? nombre) async {
    await _llamar('POST', 'maquinas.php', cuerpo: {'id_maquina': id, 'nombre': nombre ?? ''});
  }

  /// Vincula la estación a la cuenta y devuelve {clave, usuario_id, ...}.
  /// La clave es la que la estación usará para enviar sus datos a la base de datos.
  Future<Map<String, dynamic>> provisionarMaquina(String id, String nombre) =>
      _llamar('POST', 'provisionar.php', cuerpo: {'id_maquina': id, 'nombre': nombre});

  /// Estado guardado en el servidor de una de tus máquinas (lectura, programa, raciones, eventos).
  Future<Map<String, dynamic>> estadoMaquina(String id) =>
      _llamar('GET', 'estado.php', query: {'id_maquina': id});

  /// Historial y estadísticas de una máquina en los últimos [dias] días.
  Future<Map<String, dynamic>> historialMaquina(String id, int dias) =>
      _llamar('GET', 'historial.php', query: {'id_maquina': id, 'dias': '$dias'});

  /// Cambia el programa de una máquina en el servidor. La estación lo recibe en su próxima
  /// consulta (cada minuto); si no hubo cambios, conserva el que tiene.
  Future<void> guardarPrograma(String idMaquina, String tipo, double cantidad, int intervaloS) async {
    await _llamar('POST', 'programa_editar.php', cuerpo: {
      'id_maquina': idMaquina,
      'tipo': tipo,
      'cantidad': cantidad,
      'intervalo_s': intervaloS,
    });
  }

  Future<void> eliminarMaquina(String id) async {
    await _llamar('DELETE', 'maquinas.php', query: {'id_maquina': id});
  }

  // ------------------------------------------------------------ HTTP
  Future<Map<String, dynamic>> _llamar(
    String metodo,
    String archivo, {
    Map<String, dynamic>? cuerpo,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$servidor/$archivo').replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'X-Auth-Token': token!,
    };

    http.Response r;
    try {
      const espera = Duration(seconds: 10);
      switch (metodo) {
        case 'GET':
          r = await http.get(uri, headers: headers).timeout(espera);
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: headers).timeout(espera);
          break;
        default:
          r = await http.post(uri, headers: headers, body: jsonEncode(cuerpo ?? {})).timeout(espera);
      }
    } catch (e) {
      final detalle = e.toString();
      String pista;
      if (e is TimeoutException) {
        pista = 'El servidor no respondió a tiempo: casi siempre es el Firewall de Windows (permite Apache, puerto 80) '
            'o que el celular y la PC no están en la misma red.';
      } else if (detalle.toLowerCase().contains('cleartext')) {
        pista = 'Android bloquea HTTP: falta android:usesCleartextTraffic="true" en la etiqueta <application> '
            'del AndroidManifest.xml (hay que volver a compilar).';
      } else if (detalle.toLowerCase().contains('refused')) {
        pista = 'La PC rechazó la conexión: Apache no está encendido o usa otro puerto (por ejemplo 8080).';
      } else if (detalle.toLowerCase().contains('lookup') || detalle.toLowerCase().contains('unreachable')) {
        pista = 'No se encuentra la dirección: revisa la IP y que estén en la misma red.';
      } else if (detalle.toLowerCase().contains('permission')) {
        pista = 'Falta el permiso INTERNET en el AndroidManifest.xml (hay que volver a compilar).';
      } else {
        pista = 'Revisa la dirección y que Apache esté encendido.';
      }
      throw ApiException('No se pudo conectar con el servidor ($servidor).\n$pista\n\nDetalle técnico: $detalle');
    }

    Map<String, dynamic> datos;
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      datos = d is Map<String, dynamic> ? d : <String, dynamic>{};
    } catch (_) {
      throw ApiException('Respuesta inválida del servidor (código ${r.statusCode}). ¿La dirección es correcta?', r.statusCode);
    }

    if (r.statusCode >= 400) {
      // Sesión vencida o inválida: se cierra para volver al inicio de sesión
      if (r.statusCode == 401 && archivo != 'login.php' && archivo != 'register.php' && token != null) {
        await _cerrarLocal();
      }
      throw ApiException(datos['error']?.toString() ?? 'Error ${r.statusCode}', r.statusCode);
    }
    return datos;
  }
}

final AuthService auth = AuthService();
