import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/phone_mask.dart';

class UserProfileScreen extends StatefulWidget {
  final UserProfile? existing;
  final bool isFirstLaunch;

  const UserProfileScreen({
    super.key,
    this.existing,
    this.isFirstLaunch = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = UserService();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _blocoCtrl;
  late final TextEditingController _aptoCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nomeCtrl = TextEditingController(text: p?.name ?? '');
    _phoneCtrl = TextEditingController(text: formatBrazilPhone(p?.phone ?? ''));
    _blocoCtrl = TextEditingController(text: p?.bloco ?? '');
    _aptoCtrl = TextEditingController(text: p?.apto ?? '');
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _phoneCtrl.dispose();
    _blocoCtrl.dispose();
    _aptoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final current = await _svc.getProfile();
    final updated = current.copyWith(
      name: _nomeCtrl.text.trim(),
      phone: formatBrazilPhone(_phoneCtrl.text),
      bloco: _blocoCtrl.text.trim(),
      apto: _aptoCtrl.text.trim(),
    );
    await _svc.saveProfile(updated);

    if (!mounted) return;
    if (widget.isFirstLaunch) {
      await _svc.setLoggedIn(true);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/groups', (_) => false);
    } else {
      Navigator.pop(context, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isFirstLaunch
          ? null
          : AppBar(
              title: const Text('Meu perfil'),
              backgroundColor: AppTheme.defaultPrimary,
              foregroundColor: Colors.white,
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isFirstLaunch) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: Icon(
                      Icons.electric_car,
                      size: 72,
                      color: AppTheme.defaultPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Bem-vindo ao Carregou!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Preencha seus dados para começar.',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                Text(
                  'SEUS DADOS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nomeCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe seu nome'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [BrazilPhoneInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '(11)98765-4321',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _blocoCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Bloco',
                          hintText: 'Ex: A',
                          prefixIcon: Icon(Icons.apartment_outlined),
                          border: OutlineInputBorder(),
                        ),
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
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe o apto'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.defaultPrimary,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
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
                        : Text(
                            widget.isFirstLaunch ? 'Continuar' : 'Salvar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
