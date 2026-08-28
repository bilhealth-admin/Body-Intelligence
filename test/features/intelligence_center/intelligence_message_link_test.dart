import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trusted catalog link survives local conversation persistence', () {
    final message = IntelligenceMessage(
      id: 'answer-1',
      role: IntelligenceMessageRole.bil,
      kind: IntelligenceMessageKind.coach,
      text: 'Verified option',
      createdAt: DateTime.utc(2026, 8, 24),
      links: const <IntelligenceMessageLink>[
        IntelligenceMessageLink(
          id: 'shakshuka',
          label: 'Herbed shakshuka',
          route: '/wellness/recipes?recipe=shakshuka',
          kind: IntelligenceMessageLinkKind.recipe,
        ),
      ],
    );

    final restored = IntelligenceMessage.fromJson(message.toJson());

    expect(restored.links, hasLength(1));
    expect(restored.links.single.isTrustedLocalRoute, isTrue);
  });

  test('external or mismatched restored links are discarded', () {
    final raw = <String, Object?>{
      'id': 'answer-2',
      'role': 'bil',
      'kind': 'coach',
      'text': 'Unsafe link',
      'createdAt': DateTime.utc(2026, 8, 24).toIso8601String(),
      'links': <Object?>[
        <String, Object?>{
          'id': 'shakshuka',
          'label': 'External',
          'route': 'https://example.com/shakshuka',
          'kind': 'recipe',
        },
      ],
    };

    expect(IntelligenceMessage.fromJson(raw).links, isEmpty);
  });
}
