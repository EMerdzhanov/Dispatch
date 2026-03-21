import 'package:flutter_riverpod/flutter_riverpod.dart';

class BrowserTab {
  final String id;
  final String url;
  final String title;

  const BrowserTab({required this.id, required this.url, required this.title});
}

class BrowserState {
  final Map<String, List<BrowserTab>> groupTabs; // groupId → tabs
  final String? activeTabId;

  const BrowserState({this.groupTabs = const {}, this.activeTabId});

  BrowserState copyWith({
    Map<String, List<BrowserTab>>? groupTabs,
    String? Function()? activeTabId,
  }) {
    return BrowserState(
      groupTabs: groupTabs ?? this.groupTabs,
      activeTabId: activeTabId != null ? activeTabId() : this.activeTabId,
    );
  }
}

class BrowserNotifier extends Notifier<BrowserState> {
  @override
  BrowserState build() => const BrowserState();

  /// Add a browser tab for a localhost URL. Deduplicates by port.
  void addTab(String groupId, String url) {
    final tabs = List<BrowserTab>.from(state.groupTabs[groupId] ?? []);

    // Deduplicate by port
    String? port;
    try {
      port = Uri.parse(url).port.toString();
    } catch (_) {}

    if (port != null) {
      final exists = tabs.any((t) {
        try { return Uri.parse(t.url).port.toString() == port; } catch (_) { return false; }
      });
      if (exists) return;
    }

    String title = url;
    try { final u = Uri.parse(url); title = '${u.host}:${u.port}'; } catch (_) {}

    final tab = BrowserTab(
      id: 'browser-${DateTime.now().millisecondsSinceEpoch}',
      url: url,
      title: title,
    );
    tabs.add(tab);

    state = state.copyWith(
      groupTabs: {...state.groupTabs, groupId: tabs},
      activeTabId: () => tab.id,
    );
  }

  void removeTab(String groupId, String tabId) {
    final tabs = List<BrowserTab>.from(state.groupTabs[groupId] ?? []);
    tabs.removeWhere((t) => t.id == tabId);
    state = state.copyWith(
      groupTabs: {...state.groupTabs, groupId: tabs},
      activeTabId: () => state.activeTabId == tabId ? null : state.activeTabId,
    );
  }

  void setActiveTab(String? tabId) {
    state = state.copyWith(activeTabId: () => tabId);
  }

  List<BrowserTab> getTabsForGroup(String groupId) {
    return state.groupTabs[groupId] ?? [];
  }
}

final browserProvider = NotifierProvider<BrowserNotifier, BrowserState>(BrowserNotifier.new);
