import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/ev_brands.dart';
import '../models/group.dart';
import '../models/user_role.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

class RegisterVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle;
  final Group? group;
  final UserRole role;
  final UserProfile profile;

  const RegisterVehicleScreen({
    super.key,
    this.vehicle,
    this.group,
    required this.role,
    required this.profile,
  });

  @override
  State<RegisterVehicleScreen> createState() => _RegisterVehicleScreenState();
}

class _RegisterVehicleScreenState extends State<RegisterVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  late final TextEditingController _placaCtrl;
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _blocoCtrl;
  late final TextEditingController _aptoCtrl;

  String? _marca;
  String? _modelo;
  bool _saving = false;

  bool get _isEditing => widget.vehicle != null;
  bool get _isAdmin =>
      widget.role == UserRole.groupAdmin || widget.role == UserRole.appAdmin;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    final p = widget.profile;
    _placaCtrl = TextEditingController(text: v?.placa ?? '');
    _nomeCtrl = TextEditingController(
        text: _isAdmin ? (v?.nomeProprietario ?? '') : p.name);
    _blocoCtrl = TextEditingController(
        text: _isAdmin ? (v?.bloco ?? '') : p.bloco);
    _aptoCtrl = TextEditingController(
        text: _isAdmin ? (v?.apto ?? '') : p.apto);
    _marca = (v?.marca.isNotEmpty == true) ? v!.marca : null;
    _modelo = (v?.modelo.isNotEmpty == true) ? v!.modelo : null;
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _nomeCtrl.dispose();
    _blocoCtrl.dispose();
    _aptoCtrl.dispose();
    super.dispose();
  }

  String get _groupId =>
      widget.vehicle?.groupId ?? widget.group?.id ?? '';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final placa = _placaCtrl.text.trim().toUpperCase();
      if (!_isEditing) {
        final existing = await _db.getVehicleByPlaca(_groupId, placa);
        if (existing != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Já existe um veículo com esta placa neste grupo.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _saving = false);
          return;
        }
      }

      final nome = _isAdmin
          ? _nomeCtrl.text.trim()
          : widget.profile.name;
      final bloco = _isAdmin
          ? (_blocoCtrl.text.trim().isEmpty ? null : _blocoCtrl.text.trim())
          : (widget.profile.bloco.isEmpty ? null : widget.profile.bloco);
      final apto = _isAdmin ? _aptoCtrl.text.trim() : widget.profile.apto;

      if (_isEditing) {
        await _db.updateVehicle(
          widget.vehicle!.copyWith(
            placa: placa,
            nomeProprietario: nome,
            bloco: bloco,
            apto: apto,
            marca: _marca ?? '',
            modelo: _modelo ?? '',
          ),
        );
      } else {
        await _db.insertVehicle(
          Vehicle(
            groupId: _groupId,
            placa: placa,
            nomeProprietario: nome,
            bloco: bloco,
            apto: apto,
            marca: _marca ?? '',
            modelo: _modelo ?? '',
            ownerId: _isAdmin ? '' : widget.profile.userId,
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primary(widget.group);
    final marcaList = evBrands.keys.toList();
    final modeloList = _marca != null ? (evBrands[_marca] ?? []) : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Veículo' : 'Cadastrar Veículo'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('Dados do Veículo'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _placaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Placa *',
                  hintText: 'ABC-1234',
                  prefixIcon: Icon(Icons.directions_car),
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [_PlateFormatter()],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe a placa';
                  if (v.trim().length < 8) return 'Placa inválida (ex: ABC-1234)';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _marca,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  prefixIcon: Icon(Icons.electric_car_outlined),
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Selecione a marca'),
                items: marcaList
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _marca = v;
                  _modelo = null;
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(_marca),
                initialValue: _modelo,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: Icon(Icons.ev_station_outlined),
                  border: OutlineInputBorder(),
                ),
                hint: Text(
                  _marca == null
                      ? 'Selecione a marca primeiro'
                      : 'Selecione o modelo',
                ),
                items: modeloList.isEmpty
                    ? null
                    : modeloList
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                onChanged: modeloList.isEmpty
                    ? null
                    : (v) => setState(() => _modelo = v),
              ),
              const SizedBox(height: 24),
              if (_isAdmin) ...[
                _SectionTitle('Dados do Proprietário'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nomeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Proprietário *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _blocoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bloco',
                          hintText: 'Ex: A, B, 1...',
                          prefixIcon: Icon(Icons.apartment),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _aptoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Apartamento *',
                          hintText: 'Ex: 101',
                          prefixIcon: Icon(Icons.door_front_door_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Informe o apto'
                                : null,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _SectionTitle('Proprietário'),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(widget.profile.name),
                    subtitle: Text(
                      widget.profile.bloco.isNotEmpty
                          ? 'Bloco ${widget.profile.bloco} / Apto ${widget.profile.apto}'
                          : 'Apto ${widget.profile.apto}',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isEditing ? 'Salvar Alterações' : 'Cadastrar Veículo',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _PlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final capped = raw.length > 7 ? raw.substring(0, 7) : raw;
    final formatted = capped.length > 3
        ? '${capped.substring(0, 3)}-${capped.substring(3)}'
        : capped;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
