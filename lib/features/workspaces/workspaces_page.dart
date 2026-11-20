import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../app_controller.dart';
import '../../core/workspaces/workspace_models.dart';
import '../../data/workspace_repository.dart';
import '../../ui/shared.dart';

class WorkspacesPage extends StatefulWidget {
  const WorkspacesPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends State<WorkspacesPage> {
  String? _message;

  WorkspaceRepository get _repository => widget.controller.workspaces;

  Future<void> _createWorkspace() async {
    final value = await _ask('Create workspace', 'Workspace name');
    if (value == null || !mounted) return;
    try {
      _repository.createWorkspace(value);
      setState(() => _message = 'Workspace created locally.');
      widget.controller.refresh();
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  Future<void> _createSession(BusinessWorkspace workspace) async {
    final value = await _ask('Create analysis session', 'Session name');
    if (value == null || !mounted) return;
    try {
      _repository.createSession(workspace.id, value);
      setState(() => _message = 'Analysis session created locally.');
      widget.controller.refresh();
      // A session is the safe analysis sandbox. Take the user directly to the
      // tool catalogue so the next step is importing or analysing data.
      widget.controller.navigate(AppPage.tools);
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  Future<bool> _authorizeWorkspaceChange() async {
    if ((kDebugMode || kProfileMode) && widget.controller.developerPreview) {
      return true;
    }
    if (!widget.controller.hasAccountPassword) {
      setState(
        () => _message = 'Set an account password before editing workspaces.',
      );
      return false;
    }
    final value = await _ask(
      'Confirm workspace change',
      'Account password',
      password: true,
    );
    if (value == null) return false;
    final valid = widget.controller.verifyAccountPassword(value);
    if (!valid && mounted)
      setState(() => _message = 'Incorrect account password.');
    return valid;
  }

  Future<void> _renameWorkspace(BusinessWorkspace workspace) async {
    if (!await _authorizeWorkspaceChange() || !mounted) return;
    final value = await _ask('Rename workspace', 'New workspace name');
    if (value == null || !mounted) return;
    try {
      _repository.renameWorkspace(workspace.id, value);
      setState(() => _message = 'Workspace renamed locally.');
      widget.controller.refresh();
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  Future<void> _deleteWorkspace(BusinessWorkspace workspace) async {
    if (!await _authorizeWorkspaceChange() || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${workspace.name}?'),
        content: const Text(
          'This removes the workspace and its session metadata. Imported business records remain in the encrypted store until you clear them explicitly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete workspace'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _repository.deleteWorkspace(workspace.id);
    setState(() => _message = 'Workspace deleted locally.');
    widget.controller.refresh();
  }

  Future<String?> _ask(
    String title,
    String label, {
    bool password = false,
  }) async {
    var value = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          maxLength: password ? 128 : 80,
          obscureText: password,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: label),
          onChanged: (next) => value = next,
          onSubmitted: (next) => Navigator.pop(context, next),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value),
            child: const Text('Save locally'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _repository.workspaces();
    final active = _repository.activeWorkspace();
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Workspaces',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _createWorkspace,
                icon: const Icon(Icons.add),
                label: const Text('Create workspace'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'A workspace is a private local context for future sources, sessions and reports. Existing records are preserved while workspace ownership is introduced safely.',
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            GlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (all.isEmpty)
            GlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a private workspace',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create one for a business, project or client. HESABU stores its metadata inside the encrypted local database.',
                    ),
                  ],
                ),
              ),
            )
          else
            ...all.map(
              (workspace) =>
                  _workspaceCard(workspace, active?.id == workspace.id),
            ),
          const SizedBox(height: 24),
          const PrivacyNote(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _workspaceCard(BusinessWorkspace workspace, bool active) {
    final sessions = _repository.sessionsFor(workspace.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onLongPress: () => _showWorkspaceMenu(workspace),
        child: GlassPanel(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        workspace.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (active) const Chip(label: Text('ACTIVE')),
                    PopupMenuButton<String>(
                      tooltip: 'Workspace actions',
                      onSelected: (value) {
                        if (value == 'rename') _renameWorkspace(workspace);
                        if (value == 'delete') _deleteWorkspace(workspace);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${sessions.length} analysis session(s) · Stored locally'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        _repository.selectWorkspace(workspace.id);
                        setState(
                          () => _message = '${workspace.name} is active.',
                        );
                        widget.controller.refresh();
                      },
                      child: Text(
                        active ? 'Active workspace' : 'Use workspace',
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _createSession(workspace),
                      child: const Text('Create session'),
                    ),
                  ],
                ),
                if (sessions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Recent sessions'),
                  const SizedBox(height: 6),
                  ...sessions.take(4).map(_sessionRow),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWorkspaceMenu(BusinessWorkspace workspace) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename workspace'),
              onTap: () {
                Navigator.pop(context);
                _renameWorkspace(workspace);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete workspace'),
              onTap: () {
                Navigator.pop(context);
                _deleteWorkspace(workspace);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionRow(AnalysisSession session) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(session.name),
    subtitle: Text(session.state.name),
    trailing: session.state == AnalysisSessionState.active
        ? Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () {
                  _repository.selectSession(session.id);
                  widget.controller.refresh();
                  widget.controller.navigate(AppPage.tools);
                },
                child: const Text('Open tools'),
              ),
              TextButton(
                onPressed: () {
                  _repository.updateSessionState(
                    session.id,
                    AnalysisSessionState.completed,
                  );
                  setState(() => _message = 'Session marked complete.');
                  widget.controller.refresh();
                },
                child: const Text('Complete'),
              ),
            ],
          )
        : null,
  );
}
