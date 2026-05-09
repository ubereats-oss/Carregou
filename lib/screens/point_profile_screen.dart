import 'package:flutter/material.dart';

import '../models/group.dart';
import '../models/user_role.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/phone_mask.dart';
import 'register_vehicle_screen.dart';
import 'user_profile_screen.dart';

class PointProfileScreen extends StatefulWidget {
  final Group group;
  final UserProfile profile;
  final void Function(UserProfile) onProfileUpdated;
  final VoidCallback onExitPoint;

  const PointProfileScreen({
    super.key,
    required this.group,
    required this.profile,
    required this.onProfileUpdated,
    required this.onExitPoint,
  });

  @override
  State<PointProfileScreen> createState() => _PointProfileScreenState();
}

class _PointProfileScreenState extends State<PointProfileScreen> {
  final _userSvc = UserService();
  final _db = DatabaseService();

  List<Vehicle> _vehicles = [];
  bool _loadingVehicles = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void didUpdateWidget(PointProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id ||
        oldWidget.profile.userId != widget.profile.userId) {
      _loadVehicles();
    }
  }

  Future<void> _loadVehicles() async {
    setState(() => _loadingVehicles = true);
    final vehicles = await _db.getVehiclesByOwner(
      widget.group.id,
      widget.profile.userId,
    );
    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _loadingVehicles = false;
    });
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            UserProfileScreen(existing: widget.profile, isFirstLaunch: false),
      ),
    );
    if (!mounted) return;
    final profile = updated ?? await _userSvc.getProfile();
    widget.onProfileUpdated(profile);
  }

  Future<void> _openVehicle({Vehicle? vehicle}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterVehicleScreen(
          vehicle: vehicle,
          group: widget.group,
          role: UserRole.standard,
          profile: widget.profile,
        ),
      ),
    );
    if (mounted) _loadVehicles();
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
    if (mounted) _loadVehicles();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primary(widget.group);
    final profile = widget.profile;
    final phone = formatBrazilPhone(profile.phone);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
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
          _SectionTitle('Dados neste ponto'),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primary.withValues(alpha: 0.12),
                    child: Icon(Icons.person_outline, color: primary),
                  ),
                  title: Text(
                    profile.name.isNotEmpty ? profile.name : '(sem nome)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(widget.group.name),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Telefone'),
                  subtitle: Text(phone.isNotEmpty ? phone : 'Não informado'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: const Text('Unidade'),
                  subtitle: Text(
                    profile.bloco.isNotEmpty
                        ? 'Bloco ${profile.bloco} / Apto ${profile.apto}'
                        : 'Apto ${profile.apto}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar dados neste ponto'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: _SectionTitle('Veículos neste ponto')),
              TextButton.icon(
                onPressed: () => _openVehicle(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingVehicles)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_vehicles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Nenhum veículo neste ponto.'),
              ),
            )
          else
            ..._vehicles.map(
              (vehicle) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primary.withValues(alpha: 0.12),
                    child: Icon(Icons.electric_car, color: primary),
                  ),
                  title: Text(
                    vehicle.placa,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      vehicle.nomeProprietario,
                      vehicle.blocoApto,
                      if (vehicle.marca.isNotEmpty) vehicle.marca,
                      if (vehicle.modelo.isNotEmpty) vehicle.modelo,
                    ].join(' • '),
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
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Remover')),
                    ],
                  ),
                ),
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
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
