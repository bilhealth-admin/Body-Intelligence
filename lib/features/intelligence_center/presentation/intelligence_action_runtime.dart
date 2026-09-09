part of 'intelligence_center_page.dart';

enum _CoachVoiceMode { idle, dictation, liveCall }

enum _CoachReplyPhase { idle, preparing, searching, failed }

/// Injectable navigation boundary for focused action success/failure tests.
/// Production delegates only allow-listed paths to go_router.
typedef IntelligenceCenterNavigationExecutor =
    Future<void> Function(BuildContext context, String path, bool push);

final intelligenceCenterNavigationExecutorProvider =
    Provider<IntelligenceCenterNavigationExecutor>(
      (ref) => (context, path, push) async {
        if (push) {
          unawaited(context.push(path));
        } else {
          context.go(path);
        }
      },
    );

enum _CoachActionExecutionPhase { idle, running, failed }

String _coachActionExecutionKey(IntelligenceAction action) =>
    '${action.type.name}:${action.id}';
