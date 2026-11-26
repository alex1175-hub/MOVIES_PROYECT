import 'package:flutter/material.dart';

import 'auth_service.dart';

/// Historial y estadísticas de una máquina, traídos de la base de datos (opción WiFi / en línea).
class HistorialPage extends StatefulWidget {
  final Maquina maquina;
  const HistorialPage({super.key, required this.maquina});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  static const _periodos = {1: '24 h', 7: '7 días', 30: '30 días'};
  int _dias = 7;
  Map<String, dynamic>? _d;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await auth.historialMaquina(widget.maquina.id, _dias);
      if (!mounted) return;
      setState(() {
        _d = d;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _d = null;
        _cargando = false;
      });
    }
  }

  // ------------------------------------------------------------ utilidades
  static double? _n(dynamic v) => v is num ? v.toDouble() : null;
  static int _i(dynamic v) => v is num ? v.toInt() : 0;
  static String _f(double? v, [int d = 0]) => v == null ? '--' : v.toStringAsFixed(d);
  static Map<String, dynamic> _m(dynamic v) => v is Map<String, dynamic> ? v : <String, dynamic>{};
  static List<Map<String, dynamic>> _l(dynamic v) =>
      v is List ? v.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];

  static String _fecha(dynamic f) {
    final t = f?.toString() ?? '';
    return t.length >= 16 ? t.substring(5, 16) : t; // MM-DD HH:MM
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.maquina.nombre ?? widget.maquina.id;
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial · $nombre'),
        actions: [IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final e in _periodos.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _dias == e.key,
                    onSelected: (_) {
                      if (_dias == e.key) return;
                      _dias = e.key;
                      _cargar();
                    },
                  ),
              ],
            ),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final d = _d;
    if (d == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'No se pudo cargar el historial', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final resumen = _m(d['resumen']);
    final lect = _m(d['lecturas']);
    final serie = _l(d['serie']);
    final porDia = _l(d['por_dia']);
    final disp = _l(d['dispensados']);
    final eventos = _l(d['eventos']);
    final intervalo = _i(d['intervalo_lecturas_s']) == 0 ? 30 : _i(d['intervalo_lecturas_s']);
    final minMascota = _i(lect['uhf_lecturas']) * intervalo / 60.0;
    final sinDatos = _i(lect['total']) == 0 && disp.isEmpty && eventos.isEmpty;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (sinDatos)
            const _Caja(
              titulo: 'Sin datos',
              icono: Icons.info_outline,
              hijos: [Text('No hay registros en este periodo. La estación sube datos cada 30 s cuando está conectada.')],
            ),
          _tarjetaResumen('Comida', Icons.pets, _m(resumen['comida']), 'g'),
          _tarjetaResumen('Agua', Icons.water_drop, _m(resumen['agua']), 'ml'),
          _Caja(
            titulo: 'Mascota y niveles',
            icono: Icons.insights,
            hijos: [
              _Fila('Tiempo aprox. con la mascota (UHF)', minMascota < 90 ? '${_f(minMascota)} min' : '${_f(minMascota / 60, 1)} h'),
              _Fila('Lecturas registradas', '${_i(lect['total'])}'),
              _Fila('Nivel promedio del contenedor', '${_f(_n(lect['prom_contenedor_pct']))} %'),
              _Fila('Nivel promedio del tanque', '${_f(_n(lect['prom_tanque_pct']))} %'),
              _Fila('Lecturas con contenedor vacío', '${_i(lect['lecturas_contenedor_vacio'])}'),
              _Fila('Lecturas con tanque vacío', '${_i(lect['lecturas_tanque_vacio'])}'),
            ],
          ),
          _Caja(
            titulo: 'Entregado por día',
            icono: Icons.bar_chart,
            hijos: [
              _GraficaBarras(datos: porDia),
              const SizedBox(height: 6),
              const _Leyenda(items: [('Comida (g)', Colors.orange), ('Agua (ml)', Colors.blue)]),
            ],
          ),
          _Caja(
            titulo: 'Nivel de los depósitos (%)',
            icono: Icons.show_chart,
            hijos: [
              _GraficaLineas(
                serie: serie,
                lineas: const [
                  ('contenedor_pct', Colors.orange),
                  ('tanque_pct', Colors.blue),
                ],
                maximo: 100,
              ),
              const SizedBox(height: 6),
              const _Leyenda(items: [('Contenedor de comida', Colors.orange), ('Tanque de agua', Colors.blue)]),
            ],
          ),
          _Caja(
            titulo: 'Peso en los platos (g)',
            icono: Icons.scale,
            hijos: [
              _GraficaLineas(
                serie: serie,
                lineas: const [
                  ('plato_comida_g', Colors.orange),
                  ('plato_agua_g', Colors.blue),
                ],
              ),
              const SizedBox(height: 6),
              const _Leyenda(items: [('Plato de comida', Colors.orange), ('Plato de agua', Colors.blue)]),
            ],
          ),
          _Caja(
            titulo: 'Últimos dispensados',
            icono: Icons.history,
            hijos: [
              if (disp.isEmpty) const Text('Sin dispensados en este periodo'),
              for (final r in disp) _filaDispensado(r),
            ],
          ),
          _Caja(
            titulo: 'Eventos',
            icono: Icons.list_alt,
            hijos: [
              if (eventos.isEmpty) const Text('Sin eventos en este periodo'),
              for (final e in eventos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${_fecha(e['fecha'])}  ${e['mensaje'] ?? ''}', style: const TextStyle(fontSize: 12.5)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaResumen(String titulo, IconData icono, Map<String, dynamic> r, String unidad) {
    final total = _i(r['total']);
    final completos = _i(r['completos']);
    final entregado = _n(r['entregado']) ?? 0;
    final base = completos + _i(r['incompletos']) + _i(r['cancelados']);
    return _Caja(
      titulo: '$titulo · ${_periodos[_dias]}',
      icono: icono,
      hijos: [
        _Fila('Raciones registradas', '$total'),
        _Fila('Completas', '$completos${total > 0 ? '  (${_f(base == 0 ? null : completos * 100 / base)} %)' : ''}'),
        _Fila('Incompletas / canceladas', '${_i(r['incompletos'])} / ${_i(r['cancelados'])}'),
        _Fila('Omitidas (plato lleno)', '${_i(r['omitidos'])}'),
        _Fila('Pendientes (depósito vacío)', '${_i(r['pendientes'])}'),
        _Fila('Total entregado', '${_f(entregado, 1)} $unidad'),
        _Fila('Promedio por ración', base == 0 ? '--' : '${_f(entregado / base, 1)} $unidad'),
        _Fila('Promedio por día', '${_f(entregado / _dias, 1)} $unidad'),
      ],
    );
  }

  Widget _filaDispensado(Map<String, dynamic> r) {
    final esComida = r['tipo'] == 'comida';
    final u = esComida ? 'g' : 'ml';
    final res = '${r['resultado'] ?? ''}';
    final color = res == 'completo'
        ? Colors.green.shade700
        : (res == 'incompleto' ? Theme.of(context).colorScheme.error : null);
    final detalle = (r['detalle'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(esComida ? Icons.pets : Icons.water_drop, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_f(_n(r['cantidad_entregada']), 1)} de ${_f(_n(r['cantidad_objetivo']), 1)} $u · $res',
                    style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                Text('${_fecha(r['fecha'])} · ${r['origen'] ?? ''}${detalle.isEmpty ? '' : ' · $detalle'}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Widgets de apoyo
// =====================================================================
class _Caja extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> hijos;
  const _Caja({required this.titulo, required this.icono, required this.hijos});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icono, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 10),
            ...hijos,
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final String k;
  final String v;
  const _Fila(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(k)),
          const SizedBox(width: 8),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final List<(String, Color)> items;
  const _Leyenda({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      children: [
        for (final (t, c) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(t, style: const TextStyle(fontSize: 12)),
          ]),
      ],
    );
  }
}

/// Barras agrupadas por día: comida (g) y agua (ml).
class _GraficaBarras extends StatelessWidget {
  final List<Map<String, dynamic>> datos; // {dia, tipo, entregado}
  const _GraficaBarras({required this.datos});

  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty) return const Text('Sin dispensados en este periodo');
    final dias = <String>[];
    final comida = <String, double>{};
    final agua = <String, double>{};
    for (final r in datos) {
      final dia = '${r['dia']}';
      if (!dias.contains(dia)) dias.add(dia);
      final v = (r['entregado'] is num) ? (r['entregado'] as num).toDouble() : 0.0;
      (r['tipo'] == 'comida' ? comida : agua)[dia] = v;
    }
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarrasPainter(
          dias: dias,
          comida: [for (final d in dias) comida[d] ?? 0],
          agua: [for (final d in dias) agua[d] ?? 0],
          texto: Theme.of(context).colorScheme.onSurface,
          ejes: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _BarrasPainter extends CustomPainter {
  final List<String> dias;
  final List<double> comida;
  final List<double> agua;
  final Color texto;
  final Color ejes;
  _BarrasPainter({required this.dias, required this.comida, required this.agua, required this.texto, required this.ejes});

  void _txt(Canvas c, String s, Offset o, {bool derecha = false, bool centro = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: texto, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = o.dx;
    if (derecha) dx -= tp.width;
    if (centro) dx -= tp.width / 2;
    tp.paint(c, Offset(dx, o.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const izq = 38.0, abajo = 18.0, arriba = 6.0;
    final w = size.width - izq, h = size.height - abajo - arriba;
    double maxV = 1;
    for (var i = 0; i < dias.length; i++) {
      if (comida[i] > maxV) maxV = comida[i];
      if (agua[i] > maxV) maxV = agua[i];
    }
    final tope = maxV * 1.1;
    final eje = Paint()..color = ejes..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final y = arriba + h - h * k / 4;
      canvas.drawLine(Offset(izq, y), Offset(size.width, y), eje);
      _txt(canvas, (tope * k / 4).toStringAsFixed(0), Offset(izq - 4, y - 6), derecha: true);
    }
    final grupo = w / dias.length;
    final ancho = (grupo * 0.35).clamp(3.0, 26.0);
    final pC = Paint()..color = Colors.orange;
    final pA = Paint()..color = Colors.blue;
    final cadaN = (dias.length / 6).ceil().clamp(1, 99);
    for (var i = 0; i < dias.length; i++) {
      final cx = izq + grupo * i + grupo / 2;
      final hc = h * comida[i] / tope, ha = h * agua[i] / tope;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(cx - ancho - 1, arriba + h - hc, ancho, hc), const Radius.circular(2)), pC);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(cx + 1, arriba + h - ha, ancho, ha), const Radius.circular(2)), pA);
      if (i % cadaN == 0) {
        final d = dias[i];
        _txt(canvas, d.length >= 10 ? d.substring(5) : d, Offset(cx, size.height - 13), centro: true);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarrasPainter o) => true;
}

/// Líneas de la serie de lecturas (una por clave). Las claves nulas se saltan.
class _GraficaLineas extends StatelessWidget {
  final List<Map<String, dynamic>> serie; // {t, <clave>...}
  final List<(String, Color)> lineas;
  final double? maximo;
  const _GraficaLineas({required this.serie, required this.lineas, this.maximo});

  @override
  Widget build(BuildContext context) {
    if (serie.length < 2) return const Text('Aún no hay suficientes lecturas para dibujar la gráfica');
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineasPainter(
          serie: serie,
          lineas: lineas,
          maximo: maximo,
          texto: Theme.of(context).colorScheme.onSurface,
          ejes: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _LineasPainter extends CustomPainter {
  final List<Map<String, dynamic>> serie;
  final List<(String, Color)> lineas;
  final double? maximo;
  final Color texto;
  final Color ejes;
  _LineasPainter({required this.serie, required this.lineas, required this.maximo, required this.texto, required this.ejes});

  void _txt(Canvas c, String s, Offset o, {bool derecha = false, bool centro = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: texto, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = o.dx;
    if (derecha) dx -= tp.width;
    if (centro) dx -= tp.width / 2;
    tp.paint(c, Offset(dx, o.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const izq = 38.0, abajo = 18.0, arriba = 6.0;
    final w = size.width - izq, h = size.height - abajo - arriba;
    final t0 = (serie.first['t'] as num).toDouble();
    final t1 = (serie.last['t'] as num).toDouble();
    final dt = (t1 - t0) == 0 ? 1.0 : (t1 - t0);

    double minV = 0, maxV = maximo ?? 1;
    if (maximo == null) {
      for (final p in serie) {
        for (final l in lineas) {
          final v = p[l.$1];
          if (v is num) {
            if (v > maxV) maxV = v.toDouble();
            if (v < minV) minV = v.toDouble();
          }
        }
      }
      maxV = maxV * 1.1;
    }
    final rango = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final eje = Paint()..color = ejes..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final y = arriba + h - h * k / 4;
      canvas.drawLine(Offset(izq, y), Offset(size.width, y), eje);
      _txt(canvas, (minV + rango * k / 4).toStringAsFixed(0), Offset(izq - 4, y - 6), derecha: true);
    }
    // Etiquetas de tiempo (inicio, medio, fin)
    String hora(double t) {
      final f = DateTime.fromMillisecondsSinceEpoch((t * 1000).round());
      String d2(int n) => n.toString().padLeft(2, '0');
      return dt > 2 * 86400 ? '${d2(f.day)}/${d2(f.month)}' : '${d2(f.hour)}:${d2(f.minute)}';
    }
    _txt(canvas, hora(t0), Offset(izq, size.height - 13));
    _txt(canvas, hora(t0 + dt / 2), Offset(izq + w / 2, size.height - 13), centro: true);
    _txt(canvas, hora(t1), Offset(size.width, size.height - 13), derecha: true);

    for (final l in lineas) {
      final p = Paint()
        ..color = l.$2
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final ruta = Path();
      var vacia = true;
      for (final pt in serie) {
        final v = pt[l.$1];
        if (v is! num) {
          vacia = true; // hueco en los datos
          continue;
        }
        final x = izq + w * ((pt['t'] as num).toDouble() - t0) / dt;
        final y = arriba + h - h * ((v.toDouble() - minV) / rango).clamp(0.0, 1.0);
        if (vacia) {
          ruta.moveTo(x, y);
          vacia = false;
        } else {
          ruta.lineTo(x, y);
        }
      }
      canvas.drawPath(ruta, p);
    }
  }

  @override
  bool shouldRepaint(covariant _LineasPainter o) => true;
}
