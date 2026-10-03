class CommunityPollDraft {
  const CommunityPollDraft({
    required this.question,
    required this.options,
    this.allowMultiple = false,
    this.closesAt,
  });

  final String question;
  final List<String> options;
  final bool allowMultiple;
  final DateTime? closesAt;

  CommunityPollDraft normalized() {
    final normalizedQuestion = question.trim();
    final normalizedOptions = options.map((value) => value.trim()).toList();
    if (normalizedQuestion.isEmpty ||
        normalizedQuestion.length > 200 ||
        normalizedOptions.length < 2 ||
        normalizedOptions.length > 6 ||
        normalizedOptions.any((value) => value.isEmpty || value.length > 100) ||
        normalizedOptions.map((value) => value.toLowerCase()).toSet().length !=
            normalizedOptions.length ||
        (closesAt != null && !closesAt!.isAfter(DateTime.now().toUtc()))) {
      throw const FormatException('Invalid Community poll draft');
    }
    return CommunityPollDraft(
      question: normalizedQuestion,
      options: List.unmodifiable(normalizedOptions),
      allowMultiple: allowMultiple,
      closesAt: closesAt?.toUtc(),
    );
  }
}

class CommunityPollOption {
  const CommunityPollOption({
    required this.id,
    required this.position,
    required this.text,
    required this.voteCount,
    required this.selected,
  });

  final String id;
  final int position;
  final String text;
  final int voteCount;
  final bool selected;

  factory CommunityPollOption.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final position = json['position'];
    final text = json['text'];
    final voteCount = json['vote_count'];
    final selected = json['selected'];
    if (id is! String ||
        position is! num ||
        position % 1 != 0 ||
        position < 0 ||
        position > 5 ||
        text is! String ||
        text.trim().isEmpty ||
        text.length > 100 ||
        voteCount is! num ||
        voteCount % 1 != 0 ||
        voteCount < 0 ||
        selected is! bool) {
      throw const FormatException('Invalid Community poll option');
    }
    return CommunityPollOption(
      id: id,
      position: position.toInt(),
      text: text,
      voteCount: voteCount.toInt(),
      selected: selected,
    );
  }
}

class CommunityPoll {
  const CommunityPoll({
    required this.postId,
    required this.question,
    required this.allowMultiple,
    required this.closed,
    required this.totalVotes,
    required this.options,
    this.closesAt,
  });

  final String postId;
  final String question;
  final bool allowMultiple;
  final DateTime? closesAt;
  final bool closed;
  final int totalVotes;
  final List<CommunityPollOption> options;

  bool get hasSelection => options.any((option) => option.selected);

  factory CommunityPoll.fromJson(Map<String, dynamic> json) {
    final postId = json['post_id'];
    final question = json['question'];
    final allowMultiple = json['allow_multiple'];
    final rawClosesAt = json['closes_at'];
    final closesAt = rawClosesAt == null
        ? null
        : DateTime.tryParse(rawClosesAt.toString());
    final closed = json['closed'];
    final totalVotes = json['total_votes'];
    final rawOptions = json['options'];

    if (postId is! String ||
        question is! String ||
        question.trim().isEmpty ||
        question.length > 200 ||
        allowMultiple is! bool ||
        (rawClosesAt != null && closesAt == null) ||
        closed is! bool ||
        totalVotes is! num ||
        totalVotes % 1 != 0 ||
        totalVotes < 0 ||
        rawOptions is! List ||
        rawOptions.length < 2 ||
        rawOptions.length > 6) {
      throw const FormatException('Invalid Community poll');
    }

    final options = rawOptions
        .map((raw) {
          if (raw is! Map) {
            throw const FormatException('Invalid Community poll option');
          }
          return CommunityPollOption.fromJson(Map<String, dynamic>.from(raw));
        })
        .toList(growable: false);

    for (var i = 0; i < options.length; i++) {
      if (options[i].position != i) {
        throw const FormatException('Invalid Community poll option order');
      }
    }

    return CommunityPoll(
      postId: postId,
      question: question,
      allowMultiple: allowMultiple,
      closesAt: closesAt,
      closed: closed,
      totalVotes: totalVotes.toInt(),
      options: List.unmodifiable(options),
    );
  }
}
