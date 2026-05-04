enum SyncState {
  notConfigured,
  offline,
  pendingSync,
  synced,
  syncError;

  String get label => switch (this) {
    SyncState.notConfigured => 'Not configured',
    SyncState.offline => 'Offline',
    SyncState.pendingSync => 'Pending sync',
    SyncState.synced => 'Synced',
    SyncState.syncError => 'Sync error',
  };
}

class SyncService {
  const SyncService();

  SyncState get currentState => SyncState.notConfigured;
}
