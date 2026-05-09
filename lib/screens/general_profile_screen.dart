import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/phone_mask.dart';
import 'register_vehicle_screen.dart';

class GeneralProfileScreen extends StatefulWidget {
  const GeneralProfileScreen({super.key});

  @override
  State<GeneralProfileScreen> createState() => _GeneralProfileScreenState();
}

class _GeneralProfileScreenState extends State<GeneralProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();
  final _userSvc = UserService();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  UserProfile? _profile;
  List<Vehicle> _vehicles = [];
  String _originalEmail = '';
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await _userSvc.getProfile();
    final email = await _userSvc.getCurrentEmail();
    final vehicles = await _db.getAllVehiclesByOwner(profile.userId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _vehicles = vehicles;
      _nameCtrl.text = profile.name;
      _phoneCtrl.text = formatBrazilPhone(profile.phone);
      _emailCtrl.text = email;
      _originalEmail = email;
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _profile == null) return;
    setState(() => _saving = true);
    try {
      final updated = _profile!.copyWith(
        name: _nameCtrl.text.trim(),
        phone: formatBrazilPhone(_phoneCtrl.text),
      );
      await _userSvc.saveProfile(updated);
      final emailChanged = await _userSvc.requestEmailChange(_emailCtrl.text);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailChanged
                ? 'Perfil salvo. Confirme o novo e-mail pelo link enviado.'
                : 'Perfil salvo.',
          ),
        ),
      );
      if (emailChanged) _originalEmail = _emailCtrl.text.trim();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _emailCtrl.text = _originalEmail;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível alterar o e-mail agora.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openVehicle({Vehicle? vehicle}) async {
    final profile = _profile;
    if (profile == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterVehicleScreen(
          vehicle: vehicle,
          role: UserRole.standard,
          profile: profile,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover veículo?'),
        content: Text('Deseja remover ${vehicle.placa}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteVehicle(vehicle.id);
    if (mounted) _load();
  }

  Future<String?> _promptDeletePassword() async {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var showPassword = false;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar exclusão'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Digite sua senha para excluir a conta. Os dados pessoais serão removidos.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordCtrl,
                      autofocus: true,
                      obscureText: !showPassword,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setDialogState(
                            () => showPassword = !showPassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Informe sua senha';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (formKey.currentState?.validate() == true) {
                          Navigator.pop(
                            dialogContext,
                            passwordCtrl.text.trim(),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) return;
                    Navigator.pop(dialogContext, passwordCtrl.text.trim());
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Excluir'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordCtrl.dispose();
    return password;
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text(
          'Essa ação remove seu acesso e apaga seus dados pessoais. Não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final password = await _promptDeletePassword();
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _userSvc.deleteAccount(password: password);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      final message =
          (e.code == 'wrong-password' || e.code == 'invalid-credential')
          ? 'Senha incorreta.'
          : e.code == 'ownership-transfer-required'
          ? 'Cadastre outro administrador antes de excluir a conta.'
          : e.code == 'no-current-user'
          ? 'Faça login novamente.'
          : 'Não foi possível excluir a conta.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível excluir a conta agora.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: AppTheme.defaultPrimary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Dados gerais'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nome completo *',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Informe seu nome'
                              : null,
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail de login',
                            prefixIcon: Icon(Icons.mail_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final email = v?.trim() ?? '';
                            if (email.isEmpty) return 'Informe o e-mail';
                            if (!email.contains('@')) return 'E-mail inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveProfile,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Salvar perfil'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.defaultPrimary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(child: _SectionTitle('Veículos')),
                      TextButton.icon(
                        onPressed: () => _openVehicle(),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_vehicles.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('Nenhum veículo cadastrado.'),
                      ),
                    )
                  else
                    ..._vehicles.map(
                      (vehicle) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8F5E9),
                            child: Icon(
                              Icons.electric_car,
                              color: AppTheme.defaultPrimary,
                            ),
                          ),
                          title: Text(
                            vehicle.placa,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              vehicle.marca,
                              vehicle.modelo,
                              if (vehicle.groupId.isNotEmpty) vehicle.blocoApto,
                            ].where((item) => item.isNotEmpty).join(' - '),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openVehicle(vehicle: vehicle);
                              } else if (value == 'delete') {
                                _deleteVehicle(vehicle);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Remover'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_saving || _deleting) ? null : _deleteAccount,
                      icon: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFC62828),
                              ),
                            )
                          : const Icon(Icons.delete_forever_outlined),
                      label: const Text('Excluir conta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFC62828)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Remove seu acesso e seus dados pessoais.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
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
        color: AppTheme.defaultPrimary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
