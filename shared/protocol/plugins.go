package protocol

func CorePlugins() []PluginInfo {
	return []PluginInfo{
		{
			Name:        "capabilities",
			ChannelType: PluginChannelCapabilities,
			Version:     "v1",
		},
	}
}
