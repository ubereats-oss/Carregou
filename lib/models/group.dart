class Group {
  final String id;
  final String name;
  final String primaryColor;
  final int numChargers;
  final String wppMode; // 'manual' | 'evolution'
  final String wppApiUrl;
  final String wppApiKey;
  final String wppInstance;
  final String wppGroupJid;
  final String? logoAsset;
  final String accessCode;
  final DateTime createdAt;
  final String ownerId;

  const Group({
    required this.id,
    required this.name,
    this.primaryColor = '#2E7D32',
    this.numChargers = 1,
    this.wppMode = 'manual',
    this.wppApiUrl = '',
    this.wppApiKey = '',
    this.wppInstance = '',
    this.wppGroupJid = '',
    this.logoAsset,
    this.accessCode = '',
    required this.createdAt,
    required this.ownerId,
  });

  static int _intFrom(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Group copyWith({
    String? name,
    String? primaryColor,
    int? numChargers,
    String? wppMode,
    String? wppApiUrl,
    String? wppApiKey,
    String? wppInstance,
    String? wppGroupJid,
    String? logoAsset,
    String? accessCode,
    String? ownerId,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      numChargers: numChargers ?? this.numChargers,
      wppMode: wppMode ?? this.wppMode,
      wppApiUrl: wppApiUrl ?? this.wppApiUrl,
      wppApiKey: wppApiKey ?? this.wppApiKey,
      wppInstance: wppInstance ?? this.wppInstance,
      wppGroupJid: wppGroupJid ?? this.wppGroupJid,
      logoAsset: logoAsset ?? this.logoAsset,
      accessCode: accessCode ?? this.accessCode,
      createdAt: createdAt,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'primary_color': primaryColor,
    'num_chargers': numChargers,
    'numChargers': numChargers,
    'wpp_mode': wppMode,
    'wpp_api_url': wppApiUrl,
    'wpp_api_key': wppApiKey,
    'wpp_instance': wppInstance,
    'wpp_group_jid': wppGroupJid,
    'logo_asset': logoAsset,
    'access_code': accessCode,
    'created_at': createdAt.toIso8601String(),
    'owner_id': ownerId,
  };

  factory Group.fromMap(Map<String, dynamic> m) => Group(
    id: m['id'] as String,
    name: m['name'] as String,
    primaryColor: (m['primary_color'] as String?) ?? '#2E7D32',
    numChargers: _intFrom(m['num_chargers'] ?? m['numChargers'], 1),
    wppMode: (m['wpp_mode'] as String?) ?? 'manual',
    wppApiUrl: (m['wpp_api_url'] as String?) ?? '',
    wppApiKey: (m['wpp_api_key'] as String?) ?? '',
    wppInstance: (m['wpp_instance'] as String?) ?? '',
    wppGroupJid: (m['wpp_group_jid'] as String?) ?? '',
    logoAsset: m['logo_asset'] as String?,
    accessCode: (m['access_code'] as String?) ?? '',
    createdAt: DateTime.parse(m['created_at'] as String),
    ownerId: (m['owner_id'] as String?) ?? '',
  );
}
