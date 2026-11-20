import 'package:flutter/material.dart';

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
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  Future<String?> _ask(String title, String label) async {
    var value = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          maxLength: 80,
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
                      setState(() => _message = '${workspace.name} is active.');
                      widget.controller.refresh();
                    },
                    child: Text(active ? 'Active workspace' : 'Use workspace'),
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
    );
  }

  Widget _sessionRow(AnalysisSession session) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(session.name),
    subtitle: Text(session.state.name),
    trailing: session.state == AnalysisSessionState.active
        ? TextButton(
            onPressed: () {
              _repository.updateSessionState(
                session.id,
                AnalysisSessionState.completed,
              );
              setState(() => _message = 'Session marked complete.');
              widget.controller.refresh();
            },
            child: const Text('Complete'),
          )
        : null,
  );
}
