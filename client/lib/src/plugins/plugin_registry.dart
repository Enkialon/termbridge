class RemotePluginInfo {
  const RemotePluginInfo({
    required this.name,
    required this.channelType,
    required this.version,
  });

  final String name;
  final String channelType;
  final String version;
}

abstract interface class RemotePluginClient {
  RemotePluginInfo get info;
}

class PluginRegistry {
  static const capabilitiesChannel = 'mrt.plugin.capabilities@v1';
  static const gitDiffChannel = 'mrt.plugin.git-diff@v1';

  final Map<String, RemotePluginClient> _clients = {};

  void register(RemotePluginClient client) {
    _clients[client.info.channelType] = client;
  }

  RemotePluginClient? operator [](String channelType) {
    return _clients[channelType];
  }
}

class GitDiffPluginClient implements RemotePluginClient {
  const GitDiffPluginClient();

  @override
  RemotePluginInfo get info => const RemotePluginInfo(
        name: 'git-diff',
        channelType: PluginRegistry.gitDiffChannel,
        version: 'v1',
      );

  Future<void> open() async {
    throw UnimplementedError(
      'Git Diff channel is reserved for the Rust core plugin transport.',
    );
  }
}
