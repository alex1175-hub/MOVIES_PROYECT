import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Resultado de la calculadora: programa sugerido de comida y de agua.
class SugerenciaPrograma {
  final String etapa; // Cachorro / Gatito / Adulto / Senior
  final double kcalDia;
  final double kcalPorKg; // energía del alimento usada
  // Comida
  final double comidaDiaG;
  final int comidaRaciones;
  final double comidaRacionG;
  final double comidaIntervaloMin;
  // Agua
  final double aguaDiaMl;
  final int aguaRaciones;
  final double aguaRacionMl;
  final double aguaIntervaloMin;
  final List<String> avisos;

  const SugerenciaPrograma({
    required this.etapa,
    required this.kcalDia,
    required this.kcalPorKg,
    required this.comidaDiaG,
    required this.comidaRaciones,
    required this.comidaRacionG,
    required this.comidaIntervaloMin,
    required this.aguaDiaMl,
    required this.aguaRaciones,
    required this.aguaRacionMl,
    required this.aguaIntervaloMin,
    required this.avisos,
  });
}

/// Estimación basada en la energía en reposo (RER = 70 × kg^0.75) por un factor según especie,
/// etapa de vida y tamaño. Es una guía general, no sustituye al veterinario.
///
/// [tamano]: 'chica', 'mediana' o 'grande' (solo se usa en perros). [meses]: edad en meses.
SugerenciaPrograma calcularPrograma({
  required bool gato,
  required String tamano,
  required double meses,
  required double kg,
  double? kcalPorKg,
}) {
  final avisos = <String>[];

  // ---- Etapa de vida y factor de energía
  String etapa;
  double factor;
  if (gato) {
    if (meses < 4) {
      etapa = 'Gatito (menos de 4 meses)';
      factor = 2.5;
    } else if (meses < 12) {
      etapa = 'Gatito (crecimiento)';
      factor = 2.0;
    } else if (meses >= 132) {
      etapa = 'Gato senior';
      factor = 1.1;
    } else {
      etapa = 'Gato adulto';
      factor = 1.2;
    }
  } else {
    final madurez = tamano == 'chica' ? 10 : (tamano == 'mediana' ? 12 : 18); // meses
    final senior = tamano == 'chica' ? 120 : (tamano == 'mediana' ? 96 : 72); // meses
    if (meses < 4) {
      etapa = 'Cachorro (menos de 4 meses)';
      factor = 3.0;
    } else if (meses < madurez) {
      etapa = 'Cachorro (crecimiento)';
      factor = tamano == 'grande' ? 1.8 : 2.0; // razas grandes: crecer más despacio protege las articulaciones
    } else if (meses >= senior) {
      etapa = 'Perro senior';
      factor = 1.4;
    } else {
      etapa = 'Perro adulto';
      factor = 1.6;
    }
  }
  final joven = meses < 12;

  // ---- Energía y comida
  final double rer = 70 * math.pow(kg, 0.75).toDouble();
  final kcalDia = rer * factor;
  final energia = (kcalPorKg != null && kcalPorKg >= 2000 && kcalPorKg <= 5000) ? kcalPorKg : (gato ? 3800.0 : 3500.0);
  final comidaDia = kcalDia / energia * 1000; // g/día

  int raciones;
  if (meses < 4) {
    raciones = 4;
  } else if (joven) {
    raciones = 3;
  } else {
    raciones = gato ? 3 : 2;
  }
  // La estación acepta de 5 a 200 g por ración
  while (comidaDia / raciones > 200 && raciones < 8) {
    raciones++;
  }
  while (comidaDia / raciones < 5 && raciones > 1) {
    raciones--;
  }
  var racionG = (comidaDia / raciones).roundToDouble();
  if (racionG < 5) {
    racionG = 5;
    avisos.add('La ración calculada es menor al mínimo de la estación (5 g); se usó 5 g.');
  }
  if (racionG > 200) {
    racionG = 200;
    avisos.add('La ración calculada supera el máximo de la estación (200 g); se usó 200 g. Considera dar más comida a mano.');
  }

  // ---- Agua
  final mlPorKg = gato ? (joven ? 60.0 : 50.0) : (joven ? 80.0 : 60.0);
  final aguaDia = kg * mlPorKg;
  int recargas = 6;
  while (aguaDia / recargas < 20 && recargas > 1) {
    recargas--;
  }
  while (aguaDia / recargas > 500 && recargas < 12) {
    recargas++;
  }
  var racionMl = ((aguaDia / recargas) / 5).round() * 5.0;
  if (racionMl < 20) {
    racionMl = 20;
    avisos.add('La recarga de agua calculada es menor al mínimo de la estación (20 ml); se usó 20 ml.');
  }
  if (racionMl > 500) racionMl = 500;

  if (joven) {
    avisos.add('Está en crecimiento: vuelve a calcular cada mes o dos, porque sus necesidades cambian rápido.');
  }
  if (!gato && tamano == 'grande' && joven) {
    avisos.add('En cachorros de raza grande no conviene sobrealimentar: el exceso afecta huesos y articulaciones.');
  }

  return SugerenciaPrograma(
    etapa: etapa,
    kcalDia: kcalDia,
    kcalPorKg: energia,
    comidaDiaG: comidaDia,
    comidaRaciones: raciones,
    comidaRacionG: racionG,
    comidaIntervaloMin: 1440.0 / raciones,
    aguaDiaMl: aguaDia,
    aguaRaciones: recargas,
    aguaRacionMl: racionMl,
    aguaIntervaloMin: 1440.0 / recargas,
    avisos: avisos,
  );
}

/// Calculadora de programas de comida y agua según especie, tamaño, edad y peso.
///
/// Si se pasa [aplicar], aparecen los botones para enviar la sugerencia a la estación.
/// Debe devolver null si todo salió bien, o el texto del error.
class CalculadoraPage extends StatefulWidget {
  final Future<String?> Function(String tipo, double cantidad, double intervaloMin)? aplicar;
  const CalculadoraPage({super.key, this.aplicar});

  @override
  State<CalculadoraPage> createState() => _CalculadoraPageState();
}

class _CalculadoraPageState extends State<CalculadoraPage> {
  bool _gato = false;
  String _tamano = 'mediana';
  final _edad = TextEditingController();
  final _peso = TextEditingController();
  final _kcal = TextEditingController();
  SugerenciaPrograma? _r;
  String? _error;
  bool _aplicando = false;

  @override
  void dispose() {
    _edad.dispose();
    _peso.dispose();
    _kcal.dispose();
    super.dispose();
  }

  static double? _num(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

  void _calcular() {
    FocusScope.of(context).unfocus();
    final meses = _num(_edad.text);
    final kg = _num(_peso.text);
    final kcal = _kcal.text.trim().isEmpty ? null : _num(_kcal.text);
    final maxKg = _gato ? 12.0 : 90.0;
    String? error;
    if (meses == null || meses < 0 || meses > 300) {
      error = 'Escribe la edad en meses (de 0 a 300).';
    } else if (kg == null || kg < 0.5 || kg > maxKg) {
      error = _gato ? 'El peso del gato debe estar entre 0.5 y 12 kg.' : 'El peso del perro debe estar entre 0.5 y 90 kg.';
    } else if (_kcal.text.trim().isNotEmpty && (kcal == null || kcal < 2000 || kcal > 5000)) {
      error = 'Las kcal por kg del alimento deben estar entre 2000 y 5000 (viene en la bolsa).';
    }
    if (error != null) {
      setState(() {
        _error = error;
        _r = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _r = calcularPrograma(gato: _gato, tamano: _tamano, meses: meses!, kg: kg!, kcalPorKg: kcal);
    });
  }

  static String _cada(double min) {
    if (min >= 60) {
      final h = min / 60;
      return 'cada ${h == h.roundToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(1)} h';
    }
    return 'cada ${min.toStringAsFixed(0)} min';
  }

  Future<void> _aplicar(String tipo, double cantidad, double intervaloMin) async {
    final f = widget.aplicar;
    if (f == null) return;
    setState(() => _aplicando = true);
    final error = await f(tipo, cantidad, intervaloMin);
    if (!mounted) return;
    setState(() => _aplicando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Programa de ${tipo == 'comida' ? 'comida' : 'agua'} enviado.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora de programas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Indica los datos de tu mascota y la app te sugiere cuánto y cada cuánto darle de comer y de beber.'),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Perro'), icon: Icon(Icons.pets)),
              ButtonSegment(value: true, label: Text('Gato'), icon: Icon(Icons.cruelty_free)),
            ],
            selected: {_gato},
            onSelectionChanged: (s) => setState(() {
              _gato = s.first;
              _r = null;
            }),
          ),
          if (!_gato) ...[
            const SizedBox(height: 12),
            const Text('Tamaño de la raza'),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'chica', label: Text('Chica')),
                ButtonSegment(value: 'mediana', label: Text('Mediana')),
                ButtonSegment(value: 'grande', label: Text('Grande')),
              ],
              selected: {_tamano},
              onSelectionChanged: (s) => setState(() {
                _tamano = s.first;
                _r = null;
              }),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _edad,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Edad (en meses)',
              helperText: 'Meses reales de vida, por ejemplo 18 para año y medio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _peso,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _gato ? 'Peso del gato (kg)' : 'Peso del perro (kg)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kcal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Energía del alimento (kcal por kg) — opcional',
              helperText: 'Viene en la bolsa. Si lo dejas vacío se usa ${_gato ? 3800 : 3500} kcal/kg',
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _calcular, icon: const Icon(Icons.calculate), label: const Text('Calcular')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          ],
          if (r != null) ...[
            const SizedBox(height: 16),
            Text(r.etapa, style: Theme.of(context).textTheme.titleMedium),
            Text('Necesita unas ${r.kcalDia.toStringAsFixed(0)} kcal al día (alimento de ${r.kcalPorKg.toStringAsFixed(0)} kcal/kg).'),
            const SizedBox(height: 8),
            _resultado(
              icono: Icons.pets,
              titulo: 'Programa de comida sugerido',
              linea1: '${r.comidaRacionG.toStringAsFixed(0)} g ${_cada(r.comidaIntervaloMin)}',
              linea2: '${r.comidaRaciones} raciones al día · total ≈ ${(r.comidaRacionG * r.comidaRaciones).toStringAsFixed(0)} g/día',
              onAplicar: widget.aplicar == null || _aplicando
                  ? null
                  : () => _aplicar('comida', r.comidaRacionG, r.comidaIntervaloMin),
            ),
            _resultado(
              icono: Icons.water_drop,
              titulo: 'Programa de agua sugerido',
              linea1: '${r.aguaRacionMl.toStringAsFixed(0)} ml ${_cada(r.aguaIntervaloMin)}',
              linea2: '${r.aguaRaciones} recargas al día · total ≈ ${(r.aguaRacionMl * r.aguaRaciones).toStringAsFixed(0)} ml/día',
              onAplicar: widget.aplicar == null || _aplicando
                  ? null
                  : () => _aplicar('agua', r.aguaRacionMl, r.aguaIntervaloMin),
            ),
            for (final a in r.avisos)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $a', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 4),
            const Text(
              'Es una estimación general (energía en reposo × factor de edad y tamaño). Cada animal es distinto: '
              'ajusta según su condición corporal, actividad y si está esterilizado, y consulta a tu veterinario. '
              'El agua debe estar siempre disponible; la recarga del plato es la cantidad que la estación repone en cada ciclo.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultado({
    required IconData icono,
    required String titulo,
    required String linea1,
    required String linea2,
    required VoidCallback? onAplicar,
  }) {
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
            const SizedBox(height: 8),
            Text(linea1, style: Theme.of(context).textTheme.headlineSmall),
            Text(linea2),
            if (widget.aplicar != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onAplicar,
                  icon: const Icon(Icons.send),
                  label: const Text('Usar este programa'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
