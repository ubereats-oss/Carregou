import 'package:uuid/uuid.dart';
import 'vehicle.dart';

class ChargingSession {
  final String id;
  final String groupId;
  final String vehicleId;
  final int chargerId;
  final DateTime horaInicio;
  final DateTime? horaFim;
  final String status; // 'active', 'completed'
  Vehicle? vehicle;

  ChargingSession({
    String? id,
    required this.groupId,
    required this.vehicleId,
    required this.chargerId,
    DateTime? horaInicio,
    this.horaFim,
    this.status = 'active',
    this.vehicle,
  })  : id = id ?? const Uuid().v4(),
        horaInicio = horaInicio ?? DateTime.now();

  factory ChargingSession.fromMap(Map<String, dynamic> map) {
    return ChargingSession(
      id: map['id'] as String,
      groupId: (map['group_id'] as String?) ?? '',
      vehicleId: map['vehicle_id'] as String,
      chargerId: map['charger_id'] as int,
      horaInicio: DateTime.parse(map['hora_inicio'] as String),
      horaFim: map['hora_fim'] != null
          ? DateTime.parse(map['hora_fim'] as String)
          : null,
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'vehicle_id': vehicleId,
      'charger_id': chargerId,
      'hora_inicio': horaInicio.toIso8601String(),
      'hora_fim': horaFim?.toIso8601String(),
      'status': status,
    };
  }

  Duration get duration {
    final end = horaFim ?? DateTime.now();
    return end.difference(horaInicio);
  }

  String get durationFormatted {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}
