import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/group.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class CreateGroupScreen extends StatefulWidget {
  final Group? group;
  final String? ownerId;

  const CreateGroupScreen({super.key, this.group, this.ownerId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _colorCtrl;
  late int _numChargers;
  bool _saving = false;

  bool get _isEdit => widget.group != null;

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    _nameCtrl = TextEditingController(text: group?.name ?? '');
    _colorCtrl = TextEditingController(text: group?.primaryColor ?? '#2E7D32');
    _numChargers = group?.numChargers ?? 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final group = Group(
      id: widget.group?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      primaryColor: _colorCtrl.text.trim(),
      numChargers: _numChargers,
      logoAsset: widget.group?.logoAsset,
      accessCode: widget.group?.accessCode ?? '',
      createdAt: widget.group?.createdAt ?? DateTime.now(),
      ownerId: widget.group?.ownerId ?? widget.ownerId ?? '',
    );

    final savedGroup = _isEdit
        ? await _db.updateGroup(group)
        : await _db.insertGroup(group);

    if (mounted) Navigator.pop(context, savedGroup);
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppTheme.defaultPrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar ponto' : 'Novo ponto de carregamento'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('Identificação'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do ponto *',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe o nome'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _colorCtrl,
              decoration: const InputDecoration(
                labelText: 'Cor principal (hex, ex: #2E7D32)',
                prefixIcon: Icon(Icons.palette_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a cor';
                }
                final hex = value.trim().replaceAll('#', '');
                if (hex.length != 6) return 'Use o formato #RRGGBB';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _sectionLabel('Carregadores'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Número de carregadores:',
                  style: TextStyle(fontSize: 15),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _numChargers > 1
                      ? () => setState(() => _numChargers--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_numChargers',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _numChargers < 20
                      ? () => setState(() => _numChargers++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Salvar alterações' : 'Criar ponto'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.grey.shade600,
      ),
    );
  }
}
