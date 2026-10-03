part of 'community_hub_page.dart';

class _CommunityPollPanel extends StatefulWidget {
  const _CommunityPollPanel({
    required this.poll,
    required this.repository,
    this.compact = false,
  });

  final CommunityPoll poll;
  final CommunityRepository repository;
  final bool compact;

  @override
  State<_CommunityPollPanel> createState() => _CommunityPollPanelState();
}

class _CommunityPollPanelState extends State<_CommunityPollPanel> {
  late CommunityPoll _poll = widget.poll;
  late Set<String> _selection = _selectedIds(widget.poll);
  bool _voting = false;

  static Set<String> _selectedIds(CommunityPoll poll) => poll.options
      .where((option) => option.selected)
      .map((option) => option.id)
      .toSet();

  @override
  void didUpdateWidget(covariant _CommunityPollPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_voting && oldWidget.poll != widget.poll) {
      _poll = widget.poll;
      _selection = _selectedIds(widget.poll);
    }
  }

  Future<void> _choose(CommunityPollOption option) async {
    if (_voting || _poll.closed) return;
    if (_poll.allowMultiple) {
      setState(() {
        if (!_selection.add(option.id)) {
          _selection.remove(option.id);
        }
      });
      return;
    }
    setState(() => _selection = {option.id});
    await _submit();
  }

  Future<void> _submit() async {
    if (_voting || _poll.closed || _selection.isEmpty) return;
    setState(() => _voting = true);
    try {
      final updated = await widget.repository.voteCommunityPoll(
        postId: _poll.postId,
        optionIds: _selection.toList(growable: false),
      );
      if (!mounted) return;
      setState(() {
        _poll = updated;
        _selection = _selectedIds(updated);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not record your vote. Try again.',
              'تعذر تسجيل تصويتك. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _poll.totalVotes;
    return Semantics(
      container: true,
      label: communityText(context, 'Poll', 'استطلاع'),
      child: Container(
        key: Key('community-poll-${_poll.postId}'),
        padding: EdgeInsets.all(widget.compact ? 12 : 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _poll.question,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final option in _poll.options) ...[
              _CommunityPollOptionTile(
                option: option,
                selected: _selection.contains(option.id),
                totalVotes: total,
                allowMultiple: _poll.allowMultiple,
                enabled: !_voting && !_poll.closed,
                onTap: () => _choose(option),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    _poll.closed
                        ? communityText(
                            context,
                            'Poll closed',
                            'انتهى الاستطلاع',
                          )
                        : _poll.allowMultiple
                        ? communityText(
                            context,
                            'Choose one or more',
                            'اختر خيارًا أو أكثر',
                          )
                        : communityText(
                            context,
                            'Choose one option',
                            'اختر خيارًا واحدًا',
                          ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  communityText(context, '$total votes', '$total تصويت'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (_poll.allowMultiple && !_poll.closed) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                key: Key('community-poll-vote-${_poll.postId}'),
                onPressed: _voting || _selection.isEmpty ? null : _submit,
                icon: _voting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_vote_outlined),
                label: Text(communityText(context, 'Vote', 'تصويت')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommunityPollOptionTile extends StatelessWidget {
  const _CommunityPollOptionTile({
    required this.option,
    required this.selected,
    required this.totalVotes,
    required this.allowMultiple,
    required this.enabled,
    required this.onTap,
  });

  final CommunityPollOption option;
  final bool selected;
  final int totalVotes;
  final bool allowMultiple;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = totalVotes == 0 ? 0.0 : option.voteCount / totalVotes;
    return InkWell(
      key: Key('community-poll-option-${option.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  allowMultiple
                      ? selected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded
                      : selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(option.text)),
                Text('${option.voteCount}'),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0).toDouble()),
          ],
        ),
      ),
    );
  }
}
