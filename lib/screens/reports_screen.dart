import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/group.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  final Group group;
  final VoidCallback onExitPoint;
  const ReportsScreen({
    super.key,
    required this.group,
    required this.onExitPoint,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseService();
  List<UsageReport> _report = [];
  bool _loading = true;

  Group get _group => widget.group;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ReportsScreen old) {
    super.didUpdateWidget(old);
    if (old.group.id != widget.group.id) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.getUsageReport(_group.id);
    setState(() {
      _report = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primary(_group);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Uso'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart_outlined, size: 70, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Sem dados de uso ainda.',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryRow(report: _report, primary: primary),
                        const SizedBox(height: 24),
                        if (_report.any((r) => r.sessionCount > 0)) ...[
                          _SectionHeader('Top usuários por sessões'),
                          const SizedBox(height: 12),
                          _BarChartCard(report: _report, primary: primary),
                          const SizedBox(height: 24),
                        ],
                        _SectionHeader('Ranking completo'),
                        const SizedBox(height: 8),
                        ..._report.asMap().entries.map(
                              (e) => _RankingTile(
                                rank: e.key + 1,
                                report: e.value,
                                primary: primary,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<UsageReport> report;
  final Color primary;
  const _SummaryRow({required this.report, required this.primary});

  @override
  Widget build(BuildContext context) {
    final totalSessions = report.fold<int>(0, (sum, r) => sum + r.sessionCount);
    final totalMin = report.fold<int>(0, (sum, r) => sum + r.totalMinutes);
    final totalH = totalMin ~/ 60;
    final totalM = totalMin.remainder(60);
    final activeVehicles = report.where((r) => r.sessionCount > 0).length;

    return Row(
      children: [
        _StatCard(
          icon: Icons.electric_bolt,
          label: 'Sessões',
          value: '$totalSessions',
          color: primary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.access_time,
          label: 'Tempo total',
          value: '${totalH}h ${totalM}min',
          color: Colors.blue,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.directions_car,
          label: 'Veículos',
          value: '$activeVehicles',
          color: Colors.orange,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  final List<UsageReport> report;
  final Color primary;
  const _BarChartCard({required this.report, required this.primary});

  @override
  Widget build(BuildContext context) {
    final top = report.where((r) => r.sessionCount > 0).take(5).toList();
    final maxY =
        top.fold<int>(0, (m, r) => r.sessionCount > m ? r.sessionCount : m).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY + 1,
              barGroups: top.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.sessionCount.toDouble(),
                      color: primary,
                      width: 22,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= top.length) return const Text('');
                      final name =
                          top[idx].vehicle.nomeProprietario.split(' ').first;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(name,
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int rank;
  final UsageReport report;
  final Color primary;

  const _RankingTile({
    required this.rank,
    required this.report,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final hasUsage = report.sessionCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rank <= 3
              ? primary.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          child: Text(
            '$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: rank <= 3 ? primary : Colors.grey,
            ),
          ),
        ),
        title: Text(report.vehicle.nomeProprietario,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${report.vehicle.placa}  •  ${report.vehicle.blocoApto}'),
        trailing: hasUsage
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${report.sessionCount} sessões',
                    style: TextStyle(fontWeight: FontWeight.bold, color: primary),
                  ),
                  Text(report.totalFormatted,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              )
            : const Text('Sem uso',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
      ),
    );
  }
}
