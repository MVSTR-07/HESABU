import 'dart:convert';

import '../core/workspaces/workspace_models.dart';
import 'local_store.dart';

/// Encrypted local workspace/session metadata. Records remain unassigned until
/// the later ownership migration; this repository never moves or deletes them.
class WorkspaceRepository {
  WorkspaceRepository(this._store);
  final LocalStore _store;

  static const _workspacesKey = 'workspaces_v1';
  static const _sessionsKey = 'analysis_sessions_v1';
  static const _activeWorkspaceKey = 'active_workspace_id';

  List<BusinessWorkspace> workspaces() => _decodeList(
    _store.readSetting(_workspacesKey),
    BusinessWorkspace.fromJson,
  )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<AnalysisSession> sessionsFor(String workspaceId) =>
      _decodeList(
          _store.readSetting(_sessionsKey),
          AnalysisSession.fromJson,
        ).where((session) => session.workspaceId == workspaceId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  BusinessWorkspace? activeWorkspace() {
    final id = _store.readSetting(_activeWorkspaceKey);
    if (id == null) return null;
    for (final workspace in workspaces()) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }

  BusinessWorkspace createWorkspace(String value) {
    final name = _validateName(value, label: 'Workspace name');
    final now = DateTime.now().toUtc();
    final workspace = BusinessWorkspace(
      id: 'ws-${now.microsecondsSinceEpoch}',
      name: name,
      createdAt: now,
    );
    final all = workspaces()..add(workspace);
    _saveWorkspaces(all);
    selectWorkspace(workspace.id);
    return workspace;
  }

  void selectWorkspace(String id) {
    if (!workspaces().any((workspace) => workspace.id == id)) {
      throw StateError('That workspace is no longer available.');
    }
    _store.writeSetting(_activeWorkspaceKey, id);
  }

  AnalysisSession createSession(String workspaceId, String value) {
    if (!workspaces().any((workspace) => workspace.id == workspaceId)) {
      throw StateError('Select a workspace before creating a session.');
    }
    final now = DateTime.now().toUtc();
    final session = AnalysisSession(
      id: 'session-${now.microsecondsSinceEpoch}',
      workspaceId: workspaceId,
      name: _validateName(value, label: 'Session name'),
      state: AnalysisSessionState.active,
      createdAt: now,
    );
    final all = _sessions()..add(session);
    _saveSessions(all);
    return session;
  }

  void updateSessionState(String id, AnalysisSessionState state) {
    final all = _sessions();
    final index = all.indexWhere((session) => session.id == id);
    if (index < 0) throw StateError('That session is no longer available.');
    all[index] = all[index].copyWith(
      state: state,
      completedAt: state == AnalysisSessionState.completed
          ? DateTime.now().toUtc()
          : null,
    );
    _saveSessions(all);
  }

  List<AnalysisSession> _sessions() =>
      _decodeList(_store.readSetting(_sessionsKey), AnalysisSession.fromJson);

  void _saveWorkspaces(List<BusinessWorkspace> values) => _store.writeSetting(
    _workspacesKey,
    jsonEncode(values.map((value) => value.toJson()).toList()),
  );

  void _saveSessions(List<AnalysisSession> values) => _store.writeSetting(
    _sessionsKey,
    jsonEncode(values.map((value) => value.toJson()).toList()),
  );

  static List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((value) => decode(Map<String, dynamic>.from(value as Map)))
          .toList();
    } on FormatException {
      return [];
    }
  }

  static String _validateName(String value, {required String label}) {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2 || name.length > 80) {
      throw FormatException('$label must be between 2 and 80 characters.');
    }
    return name;
  }
}
