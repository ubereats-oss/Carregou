import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/user_role.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'register_vehicle_screen.dart';

class VehiclesScreen extends StatefulWidget {
  final Group group;
  final UserRole role;
  final UserProfile profile;
  final VoidCallback onExitPoint;

  const VehiclesScreen({
    super.key,
    required this.group,
    required this.role,
    required this.profile,
    required this.onExitPoint,
  });

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();
  List<Vehicle> _all = [];
  List<Vehicle> _filtered = [];
  bool _loading = true;

  Group get _group => widget.group;
  bool get _isAdmin =>
      widget.role == UserRole.groupAdmin || widget.role == UserRole.appAdmin;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void didUpdateWidget(VehiclesScreen old) {
    super.didUpdateWidget(old);
    if (old.group.id != widget.group.id) _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final vehicles = _isAdmin
        ? await _db.getVehiclesForGroupAndOwner(
            _group.id,
            widget.profile.userId,
          )
        : await _db.getVehiclesByOwner(_group.id, widget.profile.userId);
    setState(() {
      _all = vehicles;
      _filtered = vehicles;
      _loading = false;
    });
    _filter();
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

  Future<void> _delete(Vehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover veículo?'),
        content: Text('Deseja remover ${v.nomeProprietario} (${v.placa})?'),
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
    if (ok == true) {
      await _db.deleteVehicle(v.id);
      _load();
    }
  }

  void _openRegister({Vehicle? vehicle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterVehicleScreen(
          vehicle: vehicle,
          group: _group,
          role: widget.role,
          profile: widget.profile,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primary(_group);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'Veículos Cadastrados' : 'Meu Veículo'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sair do ponto',
            onPressed: widget.onExitPoint,
            icon: const Icon(Icons.exit_to_app_outlined),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
                      size: 70,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isAdmin
                          ? 'Nenhum veículo cadastrado.'
                          : 'Você ainda não cadastrou seu veículo.',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openRegister(),
                      icon: const Icon(Icons.add),
                      label: Text(
                        _isAdmin
                            ? 'Cadastrar veículo'
                            : 'Cadastrar meu veículo',
                      ),
                      style: FilledButton.styleFrom(backgroundColor: primary),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _VehicleTile(
                    vehicle: _filtered[i],
                    primaryColor: primary,
                    showOwner: _isAdmin,
                    onEdit: () => _openRegister(vehicle: _filtered[i]),
                    onDelete: () => _delete(_filtered[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _filtered.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _openRegister(),
              icon: const Icon(Icons.add),
              label: Text(_isAdmin ? 'Cadastrar' : 'Adicionar'),
              backgroundColor: primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final Vehicle vehicle;
  final Color primaryColor;
  final bool showOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VehicleTile({
    required this.vehicle,
    required this.primaryColor,
    required this.showOwner,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: primaryColor.withValues(alpha: 0.12),
        child: Icon(Icons.electric_car, color: primaryColor),
      ),
      title: Text(
        showOwner ? vehicle.nomeProprietario : vehicle.placa,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        showOwner
            ? '${vehicle.placa}  •  ${vehicle.blocoApto}'
                  '${vehicle.marca.isNotEmpty ? '  •  ${vehicle.marca}' : ''}'
            : '${vehicle.blocoApto}'
                  '${vehicle.marca.isNotEmpty ? '  •  ${vehicle.marca}' : ''}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
