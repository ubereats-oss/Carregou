import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/charging_session.dart';

class ChargerCard extends StatelessWidget {
  final int chargerId;
  final ChargingSession? activeSession;
  final Color primaryColor;
  final VoidCallback? onStart;
  final VoidCallback? onRelease;

  const ChargerCard({
    super.key,
    required this.chargerId,
    this.activeSession,
    this.primaryColor = const Color(0xFF2E7D32),
    this.onStart,
    this.onRelease,
  });

  bool get isAvailable => activeSession == null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final available = isAvailable;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: available ? primaryColor : colorScheme.error,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  available ? Icons.ev_station : Icons.electric_bolt,
                  color: available ? primaryColor : colorScheme.error,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'Carregador $chargerId',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _StatusBadge(available: available, primaryColor: primaryColor),
              ],
            ),
            if (!available && activeSession != null) ...[
              const Divider(height: 20),
              _SessionInfo(session: activeSession!),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: available
                  ? ElevatedButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar Carregamento'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: onRelease,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Liberar Carregador'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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

class _StatusBadge extends StatelessWidget {
  final bool available;
  final Color primaryColor;
  const _StatusBadge({required this.available, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: available
            ? primaryColor.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        available ? 'Disponível' : 'Em uso',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: available
              ? primaryColor
              : Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

class _SessionInfo extends StatelessWidget {
  final ChargingSession session;
  const _SessionInfo({required this.session});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    final vehicle = session.vehicle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vehicle != null) ...[
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  vehicle.nomeProprietario,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.directions_car_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${vehicle.placa}  •  ${vehicle.blocoApto}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'Desde ${fmt.format(session.horaInicio)}  •  ${session.durationFormatted}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}
