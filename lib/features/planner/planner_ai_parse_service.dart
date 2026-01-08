import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/planner/lane_planner_models.dart';

class PlannerAiParseException implements Exception {
  final String message;
  const PlannerAiParseException(this.message);

  @override
  String toString() => message;
}

/// AI parsing must be handled by a backend proxy. This stub keeps the app
/// deterministic and validates JSON once a backend is wired up.
class PlannerAiParseService {
  Future<LanePlannerInput> parseQuestion(String question) async {
    throw const PlannerAiParseException(
      'AI parsing requires a backend endpoint.',
    );
  }

  LanePlannerInput parseJsonResponse(String jsonString) {
    final decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI response must be a JSON object.');
    }
    return LanePlannerInput.fromJson(decoded);
  }
}

final plannerAiParseServiceProvider = Provider<PlannerAiParseService>(
  (ref) => PlannerAiParseService(),
);
