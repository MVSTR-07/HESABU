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
  static const _activeSessionKey = 'active_session_id';

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

  AnalysisSession? activeSession() {
    final workspace = activeWorkspace();
    final id = _store.readSetting(_activeSessionKey);
    if (workspace == null || id == null) return null;
    for (final session in sessionsFor(workspace.id)) {
      if (session.id == id && session.state == AnalysisSessionState.active) {
        return session;
      }
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
    _store.writeSetting(_activeSessionKey, '');
  }

  void renameWorkspace(String id, String value) {
    final name = _validateName(value, label: 'Workspace name');
    final all = workspaces();
    final index = all.indexWhere((workspace) => workspace.id == id);
    if (index < 0) throw StateError('That workspace is no longer available.');
    final old = all[index];
    all[index] = BusinessWorkspace(id: old.id, name: name, createdAt: old.createdAt);
    _saveWorkspaces(all);
  }

  void deleteWorkspace(String id) {
    final all = workspaces();
    if (!all.any((workspace) => workspace.id == id)) {
      throw StateError('That workspace is no longer available.');
    }
    final wasActive = activeWorkspace()?.id == id;
    _saveWorkspaces(all.where((workspace) => workspace.id != id).toList());
    _saveSessions(_sessions().where((session) => session.workspaceId != id).toList());
    if (wasActive) {
      _store.writeSetting(_activeWorkspaceKey, '');
      _store.writeSetting(_activeSessionKey, '');
    }
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
    _store.writeSetting(_activeSessionKey, session.id);
    return session;
  }

  void selectSession(String id) {
    AnalysisSession? session;
    for (final value in _sessions()) {
      if (value.id == id) {
        session = value;
        break;
      }
    }
    if (session == null || session.state != AnalysisSessionState.active) {
      throw StateError('That session is no longer active.');
    }
    if (activeWorkspace()?.id != session.workspaceId) {
      throw StateError('Select the session workspace first.');
    }
    _store.writeSetting(_activeSessionKey, id);
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
    if (state != AnalysisSessionState.active &&
        _store.readSetting(_activeSessionKey) == id) {
      _store.writeSetting(_activeSessionKey, '');
    }
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
