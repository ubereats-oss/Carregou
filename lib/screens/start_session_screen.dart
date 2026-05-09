import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/user_role.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'register_vehicle_screen.dart';

class StartSessionScreen extends StatefulWidget {
  final int chargerId;
  final Group group;
  final UserRole role;
  final UserProfile profile;
  final VoidCallback onExitPoint;

  const StartSessionScreen({
    super.key,
    required this.chargerId,
    required this.group,
    required this.role,
    required this.profile,
    required this.onExitPoint,
  });

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();
  List<Vehicle> _all = [];
  List<Vehicle> _filtered = [];
  bool _loading = true;

  bool get _isAdmin =>
      widget.role == UserRole.groupAdmin || widget.role == UserRole.appAdmin;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final vehicles = _isAdmin
        ? await _db.getVehiclesForGroupAndOwner(
            widget.group.id,
            widget.profile.userId,
          )
        : await _db.getVehiclesByOwner(widget.group.id, widget.profile.userId);
    setState(() {
      _all = vehicles;
      _filtered = vehicles;
      _loading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((v) {
        return v.nomeProprietario.toLowerCase().contains(q) ||
            v.placa.toLowerCase().contains(q) ||
            v.apto.toLowerCase().contains(q) ||
            (v.bloco?.toLowerCase().contains(q) ?? false);
      }).toList();
    });
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterVehicleScreen(
          group: widget.group,
          role: widget.role,
          profile: widget.profile,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primary(widget.group);

    return Scaffold(
      appBar: AppBar(
        title: Text('Carregador ${widget.chargerId} — Selecionar Veículo'),
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
      body: Column(
        children: [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por nome, placa ou apto...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
              ),
            ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_car_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isAdmin
                          ? 'Nenhum veículo encontrado.'
                          : 'Você não tem veículo cadastrado.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _openRegister,
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar veículo'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final v = _filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primary.withValues(alpha: 0.12),
                      child: Icon(Icons.directions_car, color: primary),
                    ),
                    title: Text(
                      _isAdmin ? v.nomeProprietario : v.placa,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _isAdmin ? '${v.placa}  •  ${v.blocoApto}' : v.blocoApto,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, v),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegister,
        icon: const Icon(Icons.add),
        label: const Text('Novo veículo'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
