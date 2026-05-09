import 'package:flutter/material.dart';
import '../main.dart' show MainArgs;
import '../models/group.dart';
import '../models/user_role.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'create_group_screen.dart';
import 'general_profile_screen.dart';

class GroupSelectionScreen extends StatefulWidget {
  const GroupSelectionScreen({super.key});

  @override
  State<GroupSelectionScreen> createState() => _GroupSelectionScreenState();
}

class _GroupSelectionScreenState extends State<GroupSelectionScreen> {
  final _db = DatabaseService();
  final _userSvc = UserService();
  List<Group> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final groups = await _db.getGroups();
      if (!mounted) return;
      setState(() => _groups = groups);
    } catch (_) {
      if (!mounted) return;
      setState(() => _groups = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar os pontos.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Entrada no grupo ──────────────────────────────────────────────────────

  Future<void> _enter(Group group) async {
    final profile = await _userSvc.getProfile();
    final isAppAdmin = await _userSvc.isAppAdmin();
    var role = UserRole.standard;

    final userIsAdmin = isAppAdmin || group.ownerId == profile.userId;
    if (isAppAdmin) {
      role = UserRole.appAdmin;
    } else if (userIsAdmin) {
      role = UserRole.groupAdmin;
    }

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/main',
      arguments: MainArgs(group: group, role: role, profile: profile),
    );
  }

  // ── Gestão de grupos ──────────────────────────────────────────────────────

  Future<void> _openCreate() async {
    if (!mounted) return;
    final profile = await _userSvc.getProfile();
    if (!mounted) return; // Added null check before context use
    final newGroup = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(ownerId: profile.userId),
      ),
    );
    if (!mounted) return;

    if (newGroup is Group) {
      final profile = await _userSvc.getProfile();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/main',
        arguments: MainArgs(
          group: newGroup,
          role: UserRole.groupAdmin,
          profile: profile,
        ),
      );
    } else {
      _load();
    }
  }

  Future<void> _openJoinByCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Entrar com código'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código de acesso',
            hintText: 'Ex.: ABCD-EFGH',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;

    final group = await _db.joinGroupByCode(code);
    if (!mounted) return;

    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código inválido ou expirado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _load();
    if (!mounted) return;
    _enter(group);
  }

  Future<void> _edit(Group group) async {
    // For editing, we still want to ensure the user has admin rights for the specific group.
    // This part of the logic might need to be refined if 'groupAdmin' is not sufficient for editing all group properties.
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateGroupScreen(group: group)),
    );
    _load();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do sistema?'),
        content: const Text('Você voltará para a tela de login.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    await _userSvc.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GeneralProfileScreen()),
    );
    if (mounted) _load();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: AppTheme.defaultPrimary,
                  foregroundColor: Colors.white,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.person_outline),
                      tooltip: 'Perfil',
                      onPressed: _openProfile,
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Sair',
                      onPressed: _logout,
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'Carregou',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.defaultPrimary,
                                AppTheme.defaultPrimary.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.ev_station,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _groups.isEmpty
                          ? 'Gerencie seus pontos de carregamento' // Changed text
                          : 'Selecione ou gerencie seus pontos de carregamento', // Changed text
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _openCreate,
                            icon: const Icon(Icons.add),
                            label: const Text(
                              'Criar novo ponto de carregamento',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.defaultPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openJoinByCode,
                            icon: const Icon(Icons.vpn_key_outlined),
                            label: const Text('Entrar com código'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.defaultPrimary,
                              side: const BorderSide(
                                color: AppTheme.defaultPrimary,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 40, thickness: 1), // Separator
                      ],
                    ),
                  ),
                ),
                if (_groups.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_off_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Você ainda não possui pontos cadastrados ou entrou em nenhum.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          // The buttons above now handle these actions
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _GroupCard(
                        group: _groups[i],
                        onEnter: () => _enter(_groups[i]),
                        onEdit: () => _edit(_groups[i]),
                      ),
                      childCount: _groups.length,
                    ),
                  ),
              ],
            ),
      floatingActionButton: null, // Removed FAB as actions are now in the body
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onEnter;
  final VoidCallback onEdit;

  const _GroupCard({
    required this.group,
    required this.onEnter,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primary(group);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
              child: Row(
                children: [
                  _GroupLogo(asset: group.logoAsset, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${group.numChargers} carregador${group.numChargers != 1 ? 'es' : ''}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Editar ponto',
                    color: Colors.grey.shade400,
                    onPressed: onEdit,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onEnter,
                  icon: const Icon(Icons.login),
                  label: const Text(
                    'Entrar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLogo extends StatelessWidget {
  final String? asset;
  final Color color;

  const _GroupLogo({required this.asset, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: asset == null
          ? Icon(Icons.ev_station, color: color, size: 28)
          : Image.asset(
              asset!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.ev_station, color: color, size: 28),
            ),
    );
  }
}
