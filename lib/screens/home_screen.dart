import 'package:flutter/material.dart';
import '../models/charging_session.dart';
import '../models/group.dart';
import '../models/queue_entry.dart';
import '../models/user_role.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../services/whatsapp_service.dart'
    show WhatsappService, WppResult, WppStatus;
import '../theme/app_theme.dart';
import '../widgets/charger_card.dart';
import '../widgets/queue_tile.dart';
import 'settings_screen.dart';
import 'start_session_screen.dart';

class HomeScreen extends StatefulWidget {
  final Group group;
  final UserRole role;
  final UserProfile profile;
  final void Function(Group) onGroupUpdated;
  final VoidCallback onExitPoint;

  const HomeScreen({
    super.key,
    required this.group,
    required this.role,
    required this.profile,
    required this.onGroupUpdated,
    required this.onExitPoint,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  final _wpp = WhatsappService();

  List<ChargingSession?> _sessions = [];
  List<QueueEntry> _queue = [];
  bool _loading = true;

  Group get _group => widget.group;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.group.id != widget.group.id ||
        old.group.numChargers != widget.group.numChargers) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final latestGroup = await _db.getGroupById(_group.id);
    final group = latestGroup ?? _group;
    final activeSessions = await _db.getActiveSessions(group.id);
    final queue = await _db.getQueue(group.id);
    if (!mounted) return;

    final sessionsMap = <int, ChargingSession>{};
    for (final s in activeSessions) {
      sessionsMap[s.chargerId] = s;
    }

    if (latestGroup != null &&
        (latestGroup.numChargers != _group.numChargers ||
            latestGroup.logoAsset != _group.logoAsset ||
            latestGroup.primaryColor != _group.primaryColor)) {
      widget.onGroupUpdated(latestGroup);
    }

    setState(() {
      _sessions = List.generate(group.numChargers, (i) => sessionsMap[i + 1]);
      _queue = queue;
      _loading = false;
    });
  }

  Future<void> _startSession(int chargerId) async {
    final Vehicle? vehicle = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StartSessionScreen(
          chargerId: chargerId,
          group: _group,
          role: widget.role,
          profile: widget.profile,
          onExitPoint: widget.onExitPoint,
        ),
      ),
    );

    if (vehicle == null || !mounted) return;

    final inQueue = await _db.isVehicleInQueue(_group.id, vehicle.id);
    if (inQueue) await _db.cancelQueueByVehicle(_group.id, vehicle.id);

    final session = ChargingSession(
      groupId: _group.id,
      vehicleId: vehicle.id,
      chargerId: chargerId,
    );
    await _db.insertSession(session);
    session.vehicle = vehicle;

    final message = _wpp.buildStartMessage(session, vehicle);
    final result = await _wpp.sendMessage(message, _group);

    if (!mounted) return;
    _showWppSnackbar(result);
    await _load();
  }

  Future<void> _releaseCharger(int chargerId, ChargingSession session) async {
    final primary = AppTheme.primary(_group);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Liberar carregador?'),
        content: Text(
          'Encerrar sessão de ${session.vehicle?.nomeProprietario ?? "—"}?\n'
          'Duração atual: ${session.durationFormatted}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final completed = await _db.endSession(session.id);
    final vehicle = completed.vehicle ?? session.vehicle;

    WppResult? result;
    if (vehicle != null) {
      final message = _wpp.buildEndMessage(completed, vehicle);
      result = await _wpp.sendMessage(message, _group);
    }

    if (!mounted) return;
    if (result != null) _showWppSnackbar(result);
    await _load();

    if (!mounted) return;
    if (_queue.isNotEmpty) _showQueueAlert(_queue.first);
  }

  void _showWppSnackbar(WppResult result) {
    final isError =
        result.status == WppStatus.error ||
        result.status == WppStatus.configMissing;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.snackbarText),
        backgroundColor: result.status == WppStatus.sent
            ? Colors.green
            : isError
            ? Colors.orange
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showQueueAlert(QueueEntry next) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: AppTheme.primary(_group)),
            const SizedBox(width: 8),
            const Text('Próximo na fila'),
          ],
        ),
        content: Text(
          '${next.vehicle?.nomeProprietario ?? "—"} (${next.vehicle?.placa ?? "—"}) '
          'está aguardando na fila.\n\n'
          'Apto: ${next.vehicle?.blocoApto ?? "—"}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addToQueue(Vehicle vehicle) async {
    final alreadyIn = await _db.isVehicleInQueue(_group.id, vehicle.id);
    if (alreadyIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este veículo já está na fila.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    await _db.addToQueue(_group.id, vehicle.id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${vehicle.nomeProprietario} adicionado à fila na posição ${_queue.length}.',
          ),
          backgroundColor: AppTheme.primary(_group),
        ),
      );
    }
  }

  bool get _isAdmin =>
      widget.role == UserRole.groupAdmin || widget.role == UserRole.appAdmin;

  Future<void> _showJoinQueueDialog() async {
    final vehicles = _isAdmin
        ? await _db.getVehiclesForGroupAndOwner(
            _group.id,
            widget.profile.userId,
          )
        : await _db.getVehiclesByOwner(_group.id, widget.profile.userId);
    if (!mounted) return;

    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre um veículo antes de entrar na fila.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Vehicle? selected;
    final primary = AppTheme.primary(_group);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Entrar na fila'),
          content: DropdownButtonFormField<Vehicle>(
            hint: const Text('Selecione o veículo'),
            items: vehicles
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text('${v.placa} — ${v.nomeProprietario}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setS(() => selected = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _addToQueue(selected!);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Entrar na fila'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _allBusy => _sessions.every((s) => s != null);

  Future<void> _openPointSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          group: _group,
          role: widget.role,
          onGroupUpdated: widget.onGroupUpdated,
          onExitPoint: widget.onExitPoint,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primary(_group);
    final chargerCount = _sessions.isNotEmpty
        ? _sessions.length
        : _group.numChargers;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(child: Text(_group.name, overflow: TextOverflow.ellipsis)),
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Configurações do ponto',
                onPressed: _openPointSettings,
              ),
          ],
        ),
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
      body: Stack(
        children: [
          if (_group.logoAsset != null)
            Positioned(
              top: 22,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: FractionallySizedBox(
                  widthFactor: 0.62,
                  child: Opacity(
                    opacity: 0.28,
                    child: Image.asset(
                      _group.logoAsset!,
                      height: 126,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      _group.logoAsset != null ? 162 : 16,
                      16,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_allBusy)
                          _AllBusyBanner(onJoinQueue: _showJoinQueueDialog),
                        if (_allBusy) const SizedBox(height: 16),
                        _SectionLabel('Carregadores'),
                        const SizedBox(height: 10),
                        ...List.generate(chargerCount, (i) {
                          final id = i + 1;
                          final session = _sessions.length > i
                              ? _sessions[i]
                              : null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ChargerCard(
                              chargerId: id,
                              activeSession: session,
                              primaryColor: primary,
                              onStart: session == null
                                  ? () => _startSession(id)
                                  : null,
                              onRelease: session != null
                                  ? () => _releaseCharger(id, session)
                                  : null,
                            ),
                          );
                        }),
                        if (_queue.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _SectionLabel('Fila de espera (${_queue.length})'),
                          const SizedBox(height: 6),
                          Card(
                            child: Column(
                              children: _queue
                                  .map(
                                    (e) => QueueTile(
                                      entry: e,
                                      onRemove: () async {
                                        await _db.removeFromQueue(e.id);
                                        _load();
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButton: _allBusy
          ? FloatingActionButton.extended(
              onPressed: _showJoinQueueDialog,
              icon: const Icon(Icons.queue),
              label: const Text('Entrar na fila'),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _AllBusyBanner extends StatelessWidget {
  final VoidCallback onJoinQueue;
  const _AllBusyBanner({required this.onJoinQueue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Todos os carregadores estão em uso.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onJoinQueue,
            child: const Text('Entrar na fila'),
          ),
        ],
      ),
    );
  }
}
