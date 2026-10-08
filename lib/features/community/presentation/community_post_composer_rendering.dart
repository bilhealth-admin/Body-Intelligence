part of 'community_hub_page.dart';

extension _CommunityPostComposerRendering on _CommunityPostComposerPageState {
  Widget buildCommunityPostComposer(BuildContext context) {
    final busy =
        _publishing ||
        _savingDraft ||
        _voiceCapturing ||
        _selectingImage ||
        _completed ||
        _openingDrafts;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopScope<bool>(
      canPop: (!_publishing && !_savingDraft) || _completed,
      child: ScaffoldMessenger(
        child: Scaffold(
          key: const Key('community-post-editor-page'),
          backgroundColor: dark
              ? CommunitySapphire.canvas(context)
              : const Color(0xFFFBFDFF),
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: dark
                ? CommunitySapphire.canvas(context)
                : const Color(0xFFFBFDFF),
            surfaceTintColor: Colors.transparent,
            toolbarHeight: scale >= 1.5 ? 100 : 56,
            leading: IconButton(
              key: const Key('community-post-editor-close'),
              tooltip: communityText(context, 'Close', 'إغلاق'),
              onPressed: busy ? null : () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded, size: 21),
            ),
            centerTitle: true,
            titleSpacing: 0,
            title: Text(
              communityText(context, 'Create a Post', 'إنشاء منشور'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: CommunitySapphire.ink(context),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: scale >= 1.5 ? 104 : 98,
                  ),
                  child: TextButton(
                    key: const Key('community-composer-open-drafts'),
                    onPressed: busy ? null : _openComposerDrafts,
                    style: TextButton.styleFrom(
                      backgroundColor: dark
                          ? const Color(0xFF203655)
                          : const Color(0xFFEDF5FF),
                      foregroundColor: dark
                          ? const Color(0xFF86B5FF)
                          : const Color(0xFF0866FF),
                      minimumSize: const Size(48, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: Text(
                      _draftCount == null
                          ? communityText(context, 'Drafts', 'المسودات')
                          : communityText(
                              context,
                              'Drafts ({count})',
                              'المسودات ({count})',
                            ).replaceAll(
                              '{count}',
                              '${_draftCount!}${_draftCountCapped ? '+' : ''}',
                            ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('community-post-editor-scroll'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.fromEarn) ...[
                            const CommunityAiRewardNotice(),
                            const SizedBox(height: 12),
                          ],
                          _buildCommunityTitleField(context, busy),
                          const SizedBox(height: 8),
                          _buildCommunityBodyField(context, busy),
                          const SizedBox(height: 9),
                          _buildCommunityImageStrip(context, busy),
                          const SizedBox(height: 10),
                          _buildCommunityReferenceOptions(context, busy),
                        ],
                      ),
                    ),
                  ),
                  // A long error or 200% text with an open keyboard must not
                  // consume the editor or overflow the Scaffold. Both actions
                  // and the full recovery copy remain reachable by scrolling.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * .55,
                    ),
                    child: SingleChildScrollView(
                      key: const Key('community-composer-footer-scroll'),
                      child: buildCommunityPostComposerToolbar(context, busy),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _composerTextBox({
    Key? key,
    required Widget child,
    double minHeight = 0,
  }) => Container(
    key: key,
    constraints: BoxConstraints(minHeight: minHeight),
    padding: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: CommunitySapphire.paper(context),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF344965)
            : const Color(0xFFDCE9FA),
      ),
    ),
    child: child,
  );

  InputDecoration _composerFieldDecoration({String? hint, String? error}) =>
      InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13.5,
          height: 1.45,
          color: CommunitySapphire.muted(context),
        ),
        contentPadding: const EdgeInsets.fromLTRB(13, 11, 13, 1),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        counterStyle: TextStyle(
          fontSize: 10.5,
          color: CommunitySapphire.muted(context),
        ),
        errorText: error,
        errorMaxLines: 4,
      );

  Widget _buildCommunityBodyField(
    BuildContext context,
    bool busy,
  ) => _composerTextBox(
    key: const Key('community-composer-body-box'),
    minHeight: 120,
    child: TextField(
      key: const Key('community-post-composer'),
      controller: _composer,
      focusNode: _composerFocus,
      enabled: !busy,
      maxLength: CommunityTextLimits.bodyCodePointLimit,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      buildCounter: communityBodyCounter(_composer),
      minLines: 4,
      maxLines: 7,
      style: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: CommunitySapphire.ink(context),
      ),
      textDirection: _composerDirection ?? Directionality.of(context),
      textCapitalization: TextCapitalization.sentences,
      onChanged: (value) {
        widget.draft.body = value;
        final error = CommunityTextLimits.exceedsBodyLimit(value)
            ? communityBodyLimitText(context)
            : null;
        final direction = BilWrittenLanguageResolver.directionFor(
          value,
          fallback: Directionality.of(context),
        );
        if (_composerError != error ||
            _submitError != null ||
            direction != _composerDirection) {
          _setComposerState(() {
            _composerDirection = direction;
            _composerError = error;
            _submitError = null;
          });
        }
      },
      decoration:
          _composerFieldDecoration(
            hint: communityText(
              context,
              "Share your thoughts, experience, or tips...\nWhat's on your mind?",
              'شارك أفكارك أو تجربتك أو نصائحك...\nما الذي يشغل بالك؟',
            ),
            error: _composerError,
          ).copyWith(
            suffixIcon: IconButton(
              key: const Key('community-composer-voice-input'),
              tooltip: communityText(context, 'Voice input', 'إدخال صوتي'),
              onPressed: busy ? null : _captureVoiceInput,
              icon: _voiceCapturing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mic_none_rounded, size: 20),
            ),
          ),
    ),
  );
}
