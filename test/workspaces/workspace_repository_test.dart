import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/core/workspaces/workspace_models.dart';
import 'package:hesabu/data/workspace_repository.dart';

import '../support/memory_store.dart';

void main() {
  test('workspaces and sessions persist locally and retain their boundary', () {
    final store = MemoryStore();
    final first = WorkspaceRepository(store);
    final bakery = first.createWorkspace('Fabricated Bakery');
    final salon = first.createWorkspace('Fabricated Salon');
    final session = first.createSession(bakery.id, 'October review');

    first.selectWorkspace(bakery.id);
    first.updateSessionState(session.id, AnalysisSessionState.completed);

    final restored = WorkspaceRepository(store);
    expect(restored.activeWorkspace()?.id, bakery.id);
    expect(restored.sessionsFor(bakery.id), hasLength(1));
    expect(restored.sessionsFor(salon.id), isEmpty);
    expect(
      restored.sessionsFor(bakery.id).single.state,
      AnalysisSessionState.completed,
    );
  });

  test('workspace names are validated before they persist', () {
    final repository = WorkspaceRepository(MemoryStore());
    expect(() => repository.createWorkspace(' '), throwsFormatException);
    expect(repository.workspaces(), isEmpty);
  });

  test('full local wipe removes workspace and session metadata', () async {
    final store = MemoryStore();
    final repository = WorkspaceRepository(store);
    final workspace = repository.createWorkspace('Fabricated Bakery');
    repository.createSession(workspace.id, 'Review');

    await store.deleteAllData();
    final restored = WorkspaceRepository(store);
    expect(restored.workspaces(), isEmpty);
    expect(restored.activeWorkspace(), isNull);
  });
}
