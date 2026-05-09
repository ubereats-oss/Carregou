import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/queue_entry.dart';

class QueueTile extends StatelessWidget {
  final QueueEntry entry;
  final VoidCallback? onRemove;

  const QueueTile({super.key, required this.entry, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    final vehicle = entry.vehicle;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          '${entry.position}º',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        vehicle?.nomeProprietario ?? '—',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: vehicle != null
          ? Text('${vehicle.placa}  •  ${vehicle.blocoApto}  •  aguardando desde ${fmt.format(entry.createdAt)}')
          : null,
      trailing: onRemove != null
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              tooltip: 'Remover da fila',
              onPressed: onRemove,
            )
          : null,
    );
  }
}
