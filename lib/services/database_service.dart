import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/charging_session.dart';
import '../models/group.dart';
import '../models/queue_entry.dart';
import '../models/vehicle.dart';
import '../utils/access_code.dart';

const _arborisId = 'arboris-001';

class UsageReport {
  final Vehicle vehicle;
  final int sessionCount;
  final int totalMinutes;

  UsageReport({
    required this.vehicle,
    required this.sessionCount,
    required this.totalMinutes,
  });

  String get totalFormatted {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static void initFfi() {}

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get _vehicles =>
      _firestore.collection('vehicles');
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection('charging_sessions');
  CollectionReference<Map<String, dynamic>> get _queue =>
      _firestore.collection('queue');
  CollectionReference<Map<String, dynamic>> get _groupMemberships =>
      _firestore.collection('group_memberships');
  CollectionReference<Map<String, dynamic>> get _groupInvites =>
      _firestore.collection('group_invites');

  Map<String, dynamic> _withDocId(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = {...doc.data()};
    data['id'] ??= doc.id;
    return data;
  }

  Future<bool> _isCurrentUserAppAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['app_admin'] == true;
  }

  String _generateAccessCode() {
    final raw = const Uuid().v4().replaceAll('-', '').toUpperCase();
    return raw.substring(0, 8);
  }

  Future<void> _syncInvite(Group group) async {
    final code = normalizeAccessCode(group.accessCode);
    if (code.isEmpty) return;
    await _groupInvites.doc(code).set({
      'group_id': group.id,
      'active': true,
      'created_at': DateTime.now().toIso8601String(),
      'created_by': _auth.currentUser?.uid ?? group.ownerId,
    }, SetOptions(merge: true));
  }

  Future<String> _uniqueAccessCode() async {
    for (var i = 0; i < 10; i++) {
      final code = _generateAccessCode();
      final doc = await _groupInvites.doc(code).get();
      if (!doc.exists) return code;
    }
    return _generateAccessCode();
  }

  Future<Group> ensureGroupAccessCode(Group group) async {
    if (normalizeAccessCode(group.accessCode).isNotEmpty) {
      final normalized = normalizeAccessCode(group.accessCode);
      try {
        await _syncInvite(group.copyWith(accessCode: normalized));
        return group.copyWith(accessCode: normalized);
      } catch (_) {
        final code = await _uniqueAccessCode();
        final updated = group.copyWith(accessCode: code);
        await _groups.doc(group.id).set(
          {'access_code': code},
          SetOptions(merge: true),
        );
        await _syncInvite(updated);
        return updated;
      }
    }

    final code = await _uniqueAccessCode();
    final updated = group.copyWith(accessCode: code);
    await _groups.doc(group.id).set({'access_code': code}, SetOptions(merge: true));
    await _syncInvite(updated);
    return updated;
  }

  // ignore: unused_element
  Future<void> _seedArborisIfNeeded() async {
    final doc = await _groups.doc(_arborisId).get();
    if (doc.exists) return;

    await _groups.doc(_arborisId).set({
      'id': _arborisId,
      'name': 'Condomínio Arboris',
      'primary_color': '#2E7D32',
      'num_chargers': 1,
      'wpp_mode': 'manual',
      'wpp_api_url': '',
      'wpp_api_key': '',
      'wpp_instance': '',
      'wpp_group_jid': '',
      'logo_asset': 'assets/images/arboris_logo.png',
      'access_code': '',
      'created_at': DateTime.now().toIso8601String(),
      'owner_id': _auth.currentUser?.uid ?? '',
    });
  }

  // Groups

  Future<List<Group>> getGroups() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final groups = <Group>[];
    if (await _isCurrentUserAppAdmin()) {
      final snapshot = await _groups.get();
      groups.addAll(
        snapshot.docs.map((doc) => Group.fromMap(_withDocId(doc))),
      );
    } else {
      final ownedSnapshot = await _groups.where('owner_id', isEqualTo: uid).get();
      final membershipSnapshot = await _groupMemberships
          .where('user_id', isEqualTo: uid)
          .get();

      final ids = <String>{
        ...ownedSnapshot.docs.map((doc) => doc.id),
        ...membershipSnapshot.docs
            .map((doc) => doc.data()['group_id'] as String? ?? '')
            .where((id) => id.isNotEmpty),
      };

      for (final id in ids) {
        final group = await getGroupById(id);
        if (group != null) groups.add(group);
      }
    }

    groups.sort((a, b) => a.name.compareTo(b.name));
    return groups;
  }

  Future<Group?> getGroupById(String id) async {
    final doc = await _groups.doc(id).get();
    if (!doc.exists) return null;
    final data = {...doc.data()!};
    data['id'] ??= doc.id;
    return Group.fromMap(data);
  }

  Future<Group> insertGroup(Group g) async {
    final group = normalizeAccessCode(g.accessCode).isNotEmpty
        ? g.copyWith(accessCode: normalizeAccessCode(g.accessCode))
        : g.copyWith(accessCode: await _uniqueAccessCode());
    await _groups.doc(group.id).set(group.toMap());
    await _syncInvite(group);
    return group;
  }

  Future<Group> updateGroup(Group g) async {
    await _groups.doc(g.id).set(g.toMap(), SetOptions(merge: true));
    await _syncInvite(g);
    return g;
  }

  Future<Group?> joinGroupByCode(String rawCode) async {
    final code = normalizeAccessCode(rawCode);
    if (code.isEmpty) return null;

    try {
      final inviteDoc = await _groupInvites.doc(code).get();
      final invite = inviteDoc.data();
      if (invite == null || invite['active'] != true) return null;

      final groupId = invite['group_id'] as String? ?? '';
      if (groupId.isEmpty) return null;

      final group = await getGroupById(groupId);
      final uid = _auth.currentUser?.uid;
      if (group == null || uid == null) return null;

      await _groupMemberships.doc('${groupId}_$uid').set({
        'group_id': groupId,
        'user_id': uid,
        'join_code': code,
        'created_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      return group;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteGroup(String id) async {
    await _groups.doc(id).delete();
  }

  // Vehicles

  Future<void> insertVehicle(Vehicle v) async {
    await _vehicles.doc(v.id).set(v.toMap());
  }

  Future<List<Vehicle>> getVehiclesByOwner(
    String groupId,
    String ownerId,
  ) async {
    final snapshot = await _vehicles
        .where('owner_id', isEqualTo: ownerId)
        .get();
    final vehicles = snapshot.docs
        .map((doc) => Vehicle.fromMap(_withDocId(doc)))
        .where(
          (vehicle) => vehicle.groupId == groupId || vehicle.groupId.isEmpty,
        )
        .toList();
    vehicles.sort((a, b) => a.nomeProprietario.compareTo(b.nomeProprietario));
    return vehicles;
  }

  Future<List<Vehicle>> getAllVehiclesByOwner(String ownerId) async {
    final snapshot = await _vehicles
        .where('owner_id', isEqualTo: ownerId)
        .get();
    final vehicles = snapshot.docs
        .map((doc) => Vehicle.fromMap(_withDocId(doc)))
        .toList();
    vehicles.sort((a, b) => a.placa.compareTo(b.placa));
    return vehicles;
  }

  Future<List<Vehicle>> getVehicles(String groupId) async {
    final snapshot = await _vehicles
        .where('group_id', isEqualTo: groupId)
        .get();
    final vehicles = snapshot.docs
        .map((doc) => Vehicle.fromMap(_withDocId(doc)))
        .toList();
    vehicles.sort((a, b) => a.nomeProprietario.compareTo(b.nomeProprietario));
    return vehicles;
  }

  Future<List<Vehicle>> getVehiclesForGroupAndOwner(
    String groupId,
    String ownerId,
  ) async {
    final groupSnapshot = await _vehicles
        .where('group_id', isEqualTo: groupId)
        .get();
    final ownerSnapshot = await _vehicles
        .where('owner_id', isEqualTo: ownerId)
        .get();

    final vehiclesById = <String, Vehicle>{};
    for (final doc in groupSnapshot.docs) {
      final vehicle = Vehicle.fromMap(_withDocId(doc));
      vehiclesById[vehicle.id] = vehicle;
    }
    for (final doc in ownerSnapshot.docs) {
      final vehicle = Vehicle.fromMap(_withDocId(doc));
      if (vehicle.groupId.isEmpty || vehicle.groupId == groupId) {
        vehiclesById[vehicle.id] = vehicle;
      }
    }

    final vehicles = vehiclesById.values.toList()
      ..sort((a, b) => a.nomeProprietario.compareTo(b.nomeProprietario));
    return vehicles;
  }

  Future<Vehicle?> getVehicleById(String id) async {
    final doc = await _vehicles.doc(id).get();
    if (!doc.exists) return null;
    final data = {...doc.data()!};
    data['id'] ??= doc.id;
    return Vehicle.fromMap(data);
  }

  Future<Vehicle?> getVehicleByPlaca(String groupId, String placa) async {
    final snapshot = await _vehicles
        .where('group_id', isEqualTo: groupId)
        .where('placa', isEqualTo: placa.toUpperCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Vehicle.fromMap(_withDocId(snapshot.docs.first));
  }

  Future<void> updateVehicle(Vehicle v) async {
    await _vehicles.doc(v.id).set(v.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteVehicle(String id) async {
    await _vehicles.doc(id).delete();
  }

  // Sessions

  Future<void> insertSession(ChargingSession s) async {
    await _sessions.doc(s.id).set(s.toMap());
  }

  Future<List<ChargingSession>> getActiveSessions(String groupId) async {
    final snapshot = await _sessions
        .where('group_id', isEqualTo: groupId)
        .where('status', isEqualTo: 'active')
        .get();
    final sessions = snapshot.docs
        .map((doc) => ChargingSession.fromMap(_withDocId(doc)))
        .toList();
    sessions.sort((a, b) => a.chargerId.compareTo(b.chargerId));
    for (final session in sessions) {
      session.vehicle = await getVehicleById(session.vehicleId);
    }
    return sessions;
  }

  Future<ChargingSession?> getActiveSessionByCharger(
    String groupId,
    int chargerId,
  ) async {
    final snapshot = await _sessions
        .where('group_id', isEqualTo: groupId)
        .where('charger_id', isEqualTo: chargerId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final session = ChargingSession.fromMap(_withDocId(snapshot.docs.first));
    session.vehicle = await getVehicleById(session.vehicleId);
    return session;
  }

  Future<ChargingSession> endSession(String sessionId) async {
    final now = DateTime.now().toIso8601String();
    await _sessions.doc(sessionId).update({
      'hora_fim': now,
      'status': 'completed',
    });

    final doc = await _sessions.doc(sessionId).get();
    final data = {...doc.data()!};
    data['id'] ??= doc.id;
    final session = ChargingSession.fromMap(data);
    session.vehicle = await getVehicleById(session.vehicleId);
    return session;
  }

  Future<List<ChargingSession>> getAllSessions(
    String groupId, {
    int limit = 100,
  }) async {
    final snapshot = await _sessions
        .where('group_id', isEqualTo: groupId)
        .get();
    final sessions = snapshot.docs
        .map((doc) => ChargingSession.fromMap(_withDocId(doc)))
        .toList();
    sessions.sort((a, b) => b.horaInicio.compareTo(a.horaInicio));
    final limited = sessions.take(limit).toList();
    for (final session in limited) {
      session.vehicle = await getVehicleById(session.vehicleId);
    }
    return limited;
  }

  // Queue

  Future<bool> isVehicleInQueue(String groupId, String vehicleId) async {
    final snapshot = await _queue
        .where('group_id', isEqualTo: groupId)
        .where('vehicle_id', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> addToQueue(String groupId, String vehicleId) async {
    final snapshot = await _queue
        .where('group_id', isEqualTo: groupId)
        .where('status', isEqualTo: 'waiting')
        .get();
    final positions = snapshot.docs
        .map((doc) => (doc.data()['position'] as int?) ?? 0)
        .toList();
    final maxPosition = positions.isEmpty
        ? 0
        : positions.reduce((a, b) => a > b ? a : b);
    final entry = QueueEntry(
      groupId: groupId,
      vehicleId: vehicleId,
      position: maxPosition + 1,
    );
    await _queue.doc(entry.id).set(entry.toMap());
  }

  Future<List<QueueEntry>> getQueue(String groupId) async {
    final snapshot = await _queue
        .where('group_id', isEqualTo: groupId)
        .where('status', isEqualTo: 'waiting')
        .get();
    final entries = snapshot.docs
        .map((doc) => QueueEntry.fromMap(_withDocId(doc)))
        .toList();
    entries.sort((a, b) => a.position.compareTo(b.position));
    for (final entry in entries) {
      entry.vehicle = await getVehicleById(entry.vehicleId);
    }
    return entries;
  }

  Future<QueueEntry?> getNextInQueue(String groupId) async {
    final entries = await getQueue(groupId);
    if (entries.isEmpty) return null;
    return entries.first;
  }

  Future<void> removeFromQueue(String queueId) async {
    await _queue.doc(queueId).update({'status': 'cancelled'});
  }

  Future<void> cancelQueueByVehicle(String groupId, String vehicleId) async {
    final snapshot = await _queue
        .where('group_id', isEqualTo: groupId)
        .where('vehicle_id', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'waiting')
        .get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'cancelled'});
    }
    await batch.commit();
  }

  // Reports

  Future<List<UsageReport>> getUsageReport(String groupId) async {
    final vehicles = await getVehicles(groupId);
    final sessions = await getAllSessions(groupId, limit: 100000);

    return vehicles.map((vehicle) {
      final vehicleSessions = sessions
          .where(
            (session) =>
                session.vehicleId == vehicle.id &&
                session.status == 'completed',
          )
          .toList();
      final totalMinutes = vehicleSessions.fold<int>(0, (total, session) {
        final end = session.horaFim;
        if (end == null) return total;
        return total + end.difference(session.horaInicio).inMinutes;
      });
      return UsageReport(
        vehicle: vehicle,
        sessionCount: vehicleSessions.length,
        totalMinutes: totalMinutes,
      );
    }).toList()..sort((a, b) {
      final byCount = b.sessionCount.compareTo(a.sessionCount);
      if (byCount != 0) return byCount;
      return b.totalMinutes.compareTo(a.totalMinutes);
    });
  }
}
