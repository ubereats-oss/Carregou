import 'package:uuid/uuid.dart';
import 'vehicle.dart';

class QueueEntry {
  final String id;
  final String groupId;
  final String vehicleId;
  final int position;
  final DateTime createdAt;
  final String status; // 'waiting', 'cancelled'
  Vehicle? vehicle;

  QueueEntry({
    String? id,
    required this.groupId,
    required this.vehicleId,
    required this.position,
    DateTime? createdAt,
    this.status = 'waiting',
    this.vehicle,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory QueueEntry.fromMap(Map<String, dynamic> map) {
    return QueueEntry(
      id: map['id'] as String,
      groupId: (map['group_id'] as String?) ?? '',
      vehicleId: map['vehicle_id'] as String,
      position: map['position'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'vehicle_id': vehicleId,
      'position': position,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }
}
