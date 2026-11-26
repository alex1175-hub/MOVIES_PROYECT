import 'package:flutter/material.dart';

import 'auth_service.dart';

// =====================================================================
// INICIO DE SESIÓN / REGISTRO
// =====================================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usuario = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  late final TextEditingController _servidor = TextEditingController(text: auth.servidor);

  bool _registro = false;
  bool _ver = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _pass.dispose();
    _pass2.dispose();
    _servidor.dispose();
    super.dispose();
  }

  String? _validar(String nombre, String pass) {
    if (nombre.isEmpty || pass.isEmpty) return 'Escribe usuario y contraseña';
    if (!_registro) return null;
    if (!RegExp(r'^[A-Za-z0-9_.-]{3,50}$').hasMatch(nombre)) {
      return 'El usuario debe tener de 3 a 50 caracteres (letras, números, _ . -)';
    }
    if (pass.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
    if (pass.length > 72) return 'La contraseña admite máximo 72 caracteres';
    if (pass != _pass2.text) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> _enviar() async {
    final nombre = _usuario.text.trim();
    final pass = _pass.text;
    final problema = _validar(nombre, pass);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _error = null;
      _cargando = true;
    });
    try {
      await auth.cambiarServidor(_servidor.text);
      if (_registro) {
        await auth.registrar(nombre, pass);
      } else {
        await auth.login(nombre, pass);
      }
      // Al iniciar sesión, la pantalla principal reemplaza a esta automáticamente.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.pets, size: 64, color: esquema.primary),
                  const SizedBox(height: 8),
                  Text('PetStation', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Iniciar sesión')),
                      ButtonSegment(value: true, label: Text('Registrarse')),
                    ],
                    selected: {_registro},
                    onSelectionChanged: _cargando
                        ? null
                        : (s) => setState(() {
                              _registro = s.first;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usuario,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: !_ver,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: _registro ? TextInputAction.next : TextInputAction.done,
                    onSubmitted: (_) => _registro ? null : _enviar(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _ver = !_ver),
                      ),
                    ),
                  ),
                  if (_registro) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass2,
                      obscureText: !_ver,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(
                        labelText: 'Repite la contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                        helperText: 'Mínimo 8 caracteres',
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: esquema.error, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _cargando ? null : _enviar,
                    child: _cargando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_registro ? 'Crear cuenta' : 'Entrar'),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: const Text('Servidor'),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      TextField(
                        controller: _servidor,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Dirección de la API',
                          helperText: 'Emulador: http://10.0.2.2/petstation_api\n'
                              'Celular: http://IP-DE-TU-PC/petstation_api',
                          helperMaxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// MIS MÁQUINAS
// =====================================================================
class MaquinasPage extends StatefulWidget {
  const MaquinasPage({super.key});

  @override
  State<MaquinasPage> createState() => _MaquinasPageState();
}

class _MaquinasPageState extends State<MaquinasPage> {
  late Future<List<Maquina>> _futuro = auth.maquinas();

  @override
  void initState() {
    super.initState();
    auth.addListener(_vigilarSesion);
  }

  @override
  void dispose() {
    auth.removeListener(_vigilarSesion);
    super.dispose();
  }

  // Si la sesión vence, se vuelve a la pantalla de inicio de sesión
  void _vigilarSesion() {
    if (!auth.logueado && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _recargar() => setState(() => _futuro = auth.maquinas());

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _agregar() async {
    final id = TextEditingController();
    final nombre = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar máquina'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: id,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'ID de la máquina',
                helperText: 'Ej. PS-0001 (de 3 a 32 caracteres)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nombre,
              decoration: const InputDecoration(labelText: 'Nombre (opcional)', helperText: 'Ej. Comedero de Max'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final idTxt = id.text.trim();
    final nombreTxt = nombre.text.trim();
    id.dispose();
    nombre.dispose();
    if (ok != true) return;

    try {
      await auth.agregarMaquina(idTxt, nombreTxt.isEmpty ? null : nombreTxt);
      _aviso('Máquina guardada');
      _recargar();
    } on ApiException catch (e) {
      _aviso(e.mensaje);
    }
  }

  Future<void> _quitar(Maquina m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar máquina'),
        content: Text('Se quitará "${m.nombre ?? m.id}" de tu cuenta y se borrarán sus lecturas guardadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await auth.eliminarMaquina(m.id);
      _recargar();
    } on ApiException catch (e) {
      _aviso(e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis máquinas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
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
                  'Aún no tienes máquinas.\nToca "Agregar", o conéctate a una estación por Bluetooth '
                  'y usa el botón de vincular.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = lista[i];
                return ListTile(
                  leading: const Icon(Icons.pets),
                  title: Text(m.nombre ?? m.id),
                  subtitle: Text(m.id),
                  trailing: IconButton(
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _quitar(m),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
