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

  String get apiBaseUrl => '${url.replaceAll(RegExp(r'/+$$'), '')}/api/v1';

  String get wsUrl {
    final trimmed = url.replaceAll(RegExp(r'/+$$'), '');
    final ws = trimmed.replaceFirst(RegExp(r'^http'), 'ws');
    return '$ws/ws';
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
