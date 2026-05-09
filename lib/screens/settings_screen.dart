import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group.dart';
import '../models/user_role.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/access_code.dart';

class SettingsScreen extends StatefulWidget {
  final Group group;
  final UserRole role;
  final void Function(Group) onGroupUpdated;
  final VoidCallback onExitPoint;

  const SettingsScreen({
    super.key,
    required this.group,
    required this.role,
    required this.onGroupUpdated,
    required this.onExitPoint,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseService();

  late Group _group;
  late int _numChargers;
  String _accessCode = '';
  bool _saving = false;
  bool _loadingAccessCode = false;

  bool get _isAdmin =>
      widget.role == UserRole.groupAdmin || widget.role == UserRole.appAdmin;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _numChargers = _group.numChargers;
    _accessCode = _group.accessCode;
    if (_isAdmin) {
      _loadAccessCode();
    }
  }

  @override
  void didUpdateWidget(SettingsScreen old) {
    super.didUpdateWidget(old);
    if (old.group.id != widget.group.id ||
        old.group.numChargers != widget.group.numChargers ||
        old.group.accessCode != widget.group.accessCode) {
      _group = widget.group;
      _numChargers = _group.numChargers;
      _accessCode = _group.accessCode;
    }
  }

  Future<void> _loadAccessCode() async {
    if (!mounted || !_isAdmin) return;
    setState(() => _loadingAccessCode = true);
    try {
      final updated = await _db.ensureGroupAccessCode(_group);
      if (!mounted) return;
      _group = updated;
      widget.onGroupUpdated(updated);
      setState(() {
        _accessCode = updated.accessCode;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível gerar o código de acesso.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingAccessCode = false);
      }
    }
  }

  Future<void> _copyAccessCode() async {
    final code = formatAccessCode(_accessCode);
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado.')),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final updated = _group.copyWith(
      numChargers: _numChargers,
      accessCode: _accessCode,
    );
    await _db.updateGroup(updated);
    _group = updated;
    widget.onGroupUpdated(updated);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Configurações salvas.'),
        backgroundColor: AppTheme.primary(updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primary(_group);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações do ponto'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sair do ponto',
            onPressed: widget.onExitPoint,
            icon: const Icon(Icons.exit_to_app_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isAdmin) ...[
            _SectionTitle('Carregadores'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quantidade de carregadores instalados'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _numChargers > 1
                              ? () => setState(() => _numChargers--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: primary,
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '$_numChargers',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _numChargers < 20
                              ? () => setState(() => _numChargers++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          color: primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Código de acesso'),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text(
                  _loadingAccessCode
                      ? 'Gerando código...'
                      : (_accessCode.isEmpty
                            ? 'Sem código'
                            : formatAccessCode(_accessCode)),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Compartilhe este código para liberar acesso ao ponto.',
                ),
                trailing: IconButton(
                  tooltip: 'Copiar código',
                  onPressed: _loadingAccessCode || _accessCode.isEmpty
                      ? null
                      : _copyAccessCode,
                  icon: const Icon(Icons.copy),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_saving || _loadingAccessCode) ? null : _save,
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ] else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Apenas administradores podem alterar este ponto.'),
              ),
            ),
        ],
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
