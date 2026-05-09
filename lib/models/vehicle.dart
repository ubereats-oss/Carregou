import 'package:uuid/uuid.dart';

class Vehicle {
  final String id;
  final String groupId;
  final String placa;
  final String nomeProprietario;
  final String? bloco;
  final String apto;
  final String marca;
  final String modelo;
  final String ownerId; // userId do morador; vazio = cadastrado pelo adm
  final String createdAt;

  Vehicle({
    String? id,
    required this.groupId,
    required this.placa,
    required this.nomeProprietario,
    this.bloco,
    required this.apto,
    this.marca = '',
    this.modelo = '',
    this.ownerId = '',
    String? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      groupId: (map['group_id'] as String?) ?? '',
      placa: map['placa'] as String,
      nomeProprietario: map['nome_proprietario'] as String,
      bloco: map['bloco'] as String?,
      apto: map['apto'] as String,
      marca: (map['marca'] as String?) ?? '',
      modelo: (map['modelo'] as String?) ?? '',
      ownerId: (map['owner_id'] as String?) ?? '',
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'placa': placa.toUpperCase(),
      'nome_proprietario': nomeProprietario,
      'bloco': bloco,
      'apto': apto,
      'marca': marca,
      'modelo': modelo,
      'owner_id': ownerId,
      'created_at': createdAt,
    };
  }

  Vehicle copyWith({
    String? groupId,
    String? placa,
    String? nomeProprietario,
    String? bloco,
    String? apto,
    String? marca,
    String? modelo,
    String? ownerId,
  }) {
    return Vehicle(
      id: id,
      groupId: groupId ?? this.groupId,
      placa: placa ?? this.placa,
      nomeProprietario: nomeProprietario ?? this.nomeProprietario,
      bloco: bloco ?? this.bloco,
      apto: apto ?? this.apto,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt,
    );
  }

  String get blocoApto {
    if (bloco != null && bloco!.isNotEmpty) return 'Bloco $bloco / Apto $apto';
    return 'Apto $apto';
  }
}
