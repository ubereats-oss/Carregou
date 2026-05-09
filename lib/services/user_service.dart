import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/phone_mask.dart';

class UserProfile {
  final String userId;
  final String name;
  final String phone;
  final String bloco;
  final String apto;

  const UserProfile({
    required this.userId,
    required this.name,
    this.phone = '',
    required this.bloco,
    required this.apto,
  });

  bool get isComplete => name.isNotEmpty && apto.isNotEmpty;

  UserProfile copyWith({
    String? name,
    String? phone,
    String? bloco,
    String? apto,
  }) => UserProfile(
    userId: userId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    bloco: bloco ?? this.bloco,
    apto: apto ?? this.apto,
  );
}

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static const _kUserId = 'user_id';
  static const _kName = 'user_name';
  static const _kPhone = 'user_phone';
  static const _kBloco = 'user_bloco';
  static const _kApto = 'user_apto';
  static const _kCurrentEmail = 'current_user_email';

  bool get _firebaseReady => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get _vehicles =>
      _firestore.collection('vehicles');
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection('charging_sessions');
  CollectionReference<Map<String, dynamic>> get _queue =>
      _firestore.collection('queue');
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<void> _deleteDocuments(
    Iterable<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    final list = refs.toList();
    for (var i = 0; i < list.length; i += 400) {
      final batch = _firestore.batch();
      for (final ref in list.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteDocumentsByFieldInChunks(
    CollectionReference<Map<String, dynamic>> collection,
    String field,
    List<String> values,
  ) async {
    if (values.isEmpty) return;
    for (var i = 0; i < values.length; i += 10) {
      final chunk = values.skip(i).take(10).toList();
      final snapshot = await collection.where(field, whereIn: chunk).get();
      await _deleteDocuments(snapshot.docs.map((doc) => doc.reference));
    }
  }

  Future<String?> _findFallbackAppAdminUid(String excludedUid) async {
    final candidates = <String>{};

    final boolSnapshot = await _users.where('app_admin', isEqualTo: true).get();
    for (final doc in boolSnapshot.docs) {
      if (doc.id != excludedUid) candidates.add(doc.id);
    }
    if (candidates.isNotEmpty) return candidates.first;

    final roleSnapshot = await _users
        .where('app_role', isEqualTo: 'appAdmin')
        .get();
    for (final doc in roleSnapshot.docs) {
      if (doc.id != excludedUid) candidates.add(doc.id);
    }
    if (candidates.isNotEmpty) return candidates.first;

    return null;
  }

  Future<void> _transferOwnedGroups(String fromUid, String toUid) async {
    final snapshot = await _groups.where('owner_id', isEqualTo: fromUid).get();
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'owner_id': toUid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kName);
    await prefs.remove(_kPhone);
    await prefs.remove(_kBloco);
    await prefs.remove(_kApto);
    await prefs.remove(_kCurrentEmail);
  }

  UserProfile _profileFromData(String uid, Map<String, dynamic>? data) =>
      UserProfile(
        userId: uid,
        name: data?['name'] as String? ?? '',
        phone: formatBrazilPhone(data?['phone'] as String? ?? ''),
        bloco: data?['bloco'] as String? ?? '',
        apto: data?['apto'] as String? ?? '',
      );

  Future<void> _cacheProfile(UserProfile profile, {String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, profile.userId);
    await prefs.setString(_kName, profile.name);
    await prefs.setString(_kPhone, profile.phone);
    await prefs.setString(_kBloco, profile.bloco);
    await prefs.setString(_kApto, profile.apto);
    if (email != null) await prefs.setString(_kCurrentEmail, email);
  }

  Future<UserProfile> getProfile() async {
    if (!_firebaseReady) return _getCachedProfile();

    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _userDoc(user.uid).get();
      final profile = _profileFromData(user.uid, snapshot.data());
      await _cacheProfile(profile, email: user.email);
      return profile;
    }

    return _getCachedProfile();
  }

  Future<UserProfile> _getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString(_kUserId) ?? '';
    if (userId.isEmpty) {
      userId = const Uuid().v4();
      await prefs.setString(_kUserId, userId);
    }
    return UserProfile(
      userId: userId,
      name: prefs.getString(_kName) ?? '',
      phone: formatBrazilPhone(prefs.getString(_kPhone) ?? ''),
      bloco: prefs.getString(_kBloco) ?? '',
      apto: prefs.getString(_kApto) ?? '',
    );
  }

  Future<void> saveProfile(UserProfile p) async {
    final normalized = p.copyWith(phone: formatBrazilPhone(p.phone));
    final user = _firebaseReady ? _auth.currentUser : null;
    if (user != null) {
      await _userDoc(user.uid).set({
        'email': user.email ?? '',
        'name': normalized.name,
        'phone': normalized.phone,
        'bloco': normalized.bloco,
        'apto': normalized.apto,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await _cacheProfile(normalized, email: user?.email);
  }

  Future<bool> isLoggedIn() async =>
      _firebaseReady && _auth.currentUser != null;

  Future<bool> isAppAdmin() async {
    final user = _firebaseReady ? _auth.currentUser : null;
    if (user == null) return false;

    final snapshot = await _userDoc(user.uid).get();
    final data = snapshot.data();
    return data?['app_admin'] == true || data?['app_role'] == 'appAdmin';
  }

  Future<void> setLoggedIn(bool value) async {
    if (!value) await logout();
  }

  Future<void> logout() async {
    if (_firebaseReady) await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentEmail);
  }

  Future<void> deleteAccount({required String password}) async {
    if (!_firebaseReady) {
      throw StateError('Firebase não iniciado.');
    }

    final user = _auth.currentUser;
    final email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Nenhum usuário autenticado.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    final uid = user.uid;
    final ownedGroups = await _groups.where('owner_id', isEqualTo: uid).get();
    if (ownedGroups.docs.isNotEmpty) {
      final fallbackUid = await _findFallbackAppAdminUid(uid);
      if (fallbackUid == null) {
        throw FirebaseAuthException(
          code: 'ownership-transfer-required',
          message: 'Cadastre outro administrador antes de excluir esta conta.',
        );
      }
      await _transferOwnedGroups(uid, fallbackUid);
    }

    final ownedVehicles = await _vehicles
        .where('owner_id', isEqualTo: uid)
        .get();
    final vehicleIds = ownedVehicles.docs.map((doc) => doc.id).toList();

    await _deleteDocumentsByFieldInChunks(_sessions, 'vehicle_id', vehicleIds);
    await _deleteDocumentsByFieldInChunks(_queue, 'vehicle_id', vehicleIds);
    await _deleteDocuments(ownedVehicles.docs.map((doc) => doc.reference));
    await _userDoc(uid).delete();
    await user.delete();
    await _clearLocalData();
  }

  Future<bool> hasAccount() async =>
      _firebaseReady && _auth.currentUser != null;

  Future<String> getCurrentEmail() async {
    final userEmail = _firebaseReady ? _auth.currentUser?.email : null;
    if (userEmail != null && userEmail.isNotEmpty) return userEmail;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrentEmail) ?? '';
  }

  Future<bool> requestEmailChange(String email) async {
    if (!_firebaseReady) return false;

    final user = _auth.currentUser;
    final newEmail = email.trim().toLowerCase();
    if (user == null || newEmail.isEmpty) return false;
    if ((user.email ?? '').toLowerCase() == newEmail) return false;

    await user.verifyBeforeUpdateEmail(newEmail);
    await _userDoc(user.uid).set({
      'pending_email': newEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  Future<bool> createAccount({
    required String email,
    required String password,
    required String name,
    required String bloco,
    required String apto,
  }) async {
    if (!_firebaseReady) return false;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return false;

      await user.updateDisplayName(name.trim());
      final profile = UserProfile(
        userId: user.uid,
        name: name.trim(),
        phone: '',
        bloco: bloco.trim(),
        apto: apto.trim(),
      );
      await _userDoc(user.uid).set({
        'email': user.email ?? email.trim().toLowerCase(),
        'name': profile.name,
        'phone': profile.phone,
        'bloco': profile.bloco,
        'apto': profile.apto,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _cacheProfile(profile, email: user.email);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return false;
      rethrow;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    if (!_firebaseReady) return false;

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return false;

      final profile = await getProfile();
      await _cacheProfile(profile, email: user.email);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-email') {
        return false;
      }
      rethrow;
    }
  }
}
