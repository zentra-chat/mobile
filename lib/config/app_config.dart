// Configuration for connecting to a Zentra backend instance.
//
// The web client supports multiple saved instances; the mobile base starts
// with a single configurable instance and is structured so multi-instance
// support can be layered on later.

class Instance {
  final String id;
  final String url;
  final String name;
  final String? iconUrl;
  final bool isOnline;
  final String? lastChecked;

  const Instance({
    required this.id,
    required this.url,
    required this.name,
    this.iconUrl,
    this.isOnline = false,
    this.lastChecked,
  });

  String get apiBaseUrl => '${url.replaceAll(RegExp(r'/+\$'), '')}/api/v1';

  String get wsUrl {
    final trimmed = url.replaceAll(RegExp(r'/+\$'), '');
    final ws = trimmed.replaceFirst(RegExp(r'^http'), 'ws');
    return '$ws/ws';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        if (iconUrl != null) 'iconUrl': iconUrl,
        'isOnline': isOnline,
        if (lastChecked != null) 'lastChecked': lastChecked,
      };

  factory Instance.fromJson(Map<String, dynamic> json) => Instance(
        id: json['id'] as String,
        url: json['url'] as String,
        name: json['name'] as String,
        iconUrl: json['iconUrl'] as String?,
        isOnline: json['isOnline'] as bool? ?? false,
        lastChecked: json['lastChecked'] as String?,
      );

  // Builds an instance from a user-entered URL, normalising the scheme and
  // stripping trailing slashes. Falls back to the host as the display name.
  factory Instance.fromUrl(String url, {String? name, String? id}) {
    var trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    trimmed = trimmed.replaceAll(RegExp(r'/+\$'), '');
    final host = Uri.tryParse(trimmed)?.host ?? trimmed;
    return Instance(
      id: id ?? 'inst_${DateTime.now().microsecondsSinceEpoch}',
      url: trimmed,
      name: name?.trim().isNotEmpty == true ? name!.trim() : host,
    );
  }

  Instance copyWith({
    String? id,
    String? url,
    String? name,
    String? iconUrl,
    bool? isOnline,
    String? lastChecked,
  }) {
    return Instance(
      id: id ?? this.id,
      url: url ?? this.url,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
      isOnline: isOnline ?? this.isOnline,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class AppConfig {
  // The instance the app talks to by default. Override via environment or
  // runtime configuration once instance management UI is added.
  static const Instance defaultInstance = Instance(
    id: 'default',
    url: String.fromEnvironment(
      'ZENTRA_INSTANCE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    name: String.fromEnvironment(
      'ZENTRA_INSTANCE_NAME',
      defaultValue: 'Zentra Local',
    ),
  );

  static const String appName = 'Zentra';
}
