import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/group.dart';
import 'models/user_role.dart';
import 'screens/group_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/point_profile_screen.dart';
import 'screens/vehicles_screen.dart';
import 'screens/reports_screen.dart';
import 'services/database_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  DatabaseService.initFfi();
  runApp(const CarregouApp());
}

class CarregouApp extends StatelessWidget {
  const CarregouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carregou',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(null),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/groups':
            return MaterialPageRoute(
              builder: (_) => const GroupSelectionScreen(),
            );
          case '/main':
            final args = settings.arguments as MainArgs;
            return MaterialPageRoute(
              builder: (_) => _MainScaffold(
                group: args.group,
                role: args.role,
                profile: args.profile,
              ),
            );
        }
        return null;
      },
      home: const _BootScreen(),
    );
  }
}

/// Verifica perfil no primeiro boot e redireciona.
class _BootScreen extends StatefulWidget {
  const _BootScreen();

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final userService = UserService();
    final profile = await userService.getProfile();
    final hasAccount = await userService.hasAccount();
    final isLoggedIn = await userService.isLoggedIn();
    if (!mounted) return;
    if (hasAccount && profile.isComplete && isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/groups');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class MainArgs {
  final Group group;
  final UserRole role;
  final UserProfile profile;
  const MainArgs({
    required this.group,
    required this.role,
    required this.profile,
  });
}

class _MainScaffold extends StatefulWidget {
  final Group group;
  final UserRole role;
  final UserProfile profile;

  const _MainScaffold({
    required this.group,
    required this.role,
    required this.profile,
  });

  @override
  State<_MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<_MainScaffold> {
  int _tab = 0;
  late Group _group;
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _profile = widget.profile;
  }

  void _onGroupUpdated(Group g) => setState(() => _group = g);
  void _onProfileUpdated(UserProfile p) => setState(() => _profile = p);

  void _exitPoint() {
    _confirmExitPoint();
  }

  Future<void> _confirmExitPoint() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do ponto?'),
        content: const Text(
          'Você voltará para a tela inicial de escolha do ponto, sem sair da conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/groups', (_) => false);
  }

  bool get _isAdmin =>
      widget.role == UserRole.groupAdmin || widget.role == UserRole.appAdmin;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        group: _group,
        role: widget.role,
        profile: _profile,
        onGroupUpdated: _onGroupUpdated,
        onExitPoint: _exitPoint,
      ),
      VehiclesScreen(
        group: _group,
        role: widget.role,
        profile: _profile,
        onExitPoint: _exitPoint,
      ),
      if (_isAdmin) ReportsScreen(group: _group, onExitPoint: _exitPoint),
      PointProfileScreen(
        group: _group,
        profile: _profile,
        onProfileUpdated: _onProfileUpdated,
        onExitPoint: _exitPoint,
      ),
    ];

    return Theme(
      data: AppTheme.theme(_group),
      child: Scaffold(
        body: IndexedStack(index: _tab, children: screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.ev_station_outlined),
              selectedIcon: Icon(Icons.ev_station),
              label: 'Início',
            ),
            NavigationDestination(
              icon: const Icon(Icons.directions_car_outlined),
              selectedIcon: const Icon(Icons.directions_car),
              label: _isAdmin ? 'Veículos' : 'Meu Veículo',
            ),
            if (_isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Relatórios',
              ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
