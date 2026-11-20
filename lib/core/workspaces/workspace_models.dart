enum AnalysisSessionState { active, completed, archived }

class BusinessWorkspace {
  const BusinessWorkspace({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, String> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory BusinessWorkspace.fromJson(Map<String, dynamic> json) =>
      BusinessWorkspace(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AnalysisSession {
  const AnalysisSession({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.state,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String workspaceId;
  final String name;
  final AnalysisSessionState state;
  final DateTime createdAt;
  final DateTime? completedAt;

  AnalysisSession copyWith({
    AnalysisSessionState? state,
    DateTime? completedAt,
  }) => AnalysisSession(
    id: id,
    workspaceId: workspaceId,
    name: name,
    state: state ?? this.state,
    createdAt: createdAt,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, String> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'name': name,
    'state': state.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
  };

  factory AnalysisSession.fromJson(Map<String, dynamic> json) =>
      AnalysisSession(
        id: json['id'] as String,
        workspaceId: json['workspaceId'] as String,
        name: json['name'] as String,
        state: AnalysisSessionState.values.byName(json['state'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
      );
}
