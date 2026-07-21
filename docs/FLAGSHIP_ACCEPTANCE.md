# Flagship Acceptance Checklist

## Visible transformation
- [ ] Welcome no longer resembles default Flutter UI.
- [ ] Profile is one premium screen rather than multiple sparse pages.
- [ ] Initial plan is visible before Dashboard.
- [ ] Dashboard has distinct hierarchy, not equal stacked cards.
- [ ] Arabic and English both feel intentional.

## Inputs
- [ ] `95.9` remains `95.9`.
- [ ] `104` remains `104`.
- [ ] Arabic digits parse correctly.
- [ ] Enter advances and submits on the final field.
- [ ] Arrow keys update the visible field.
- [ ] Mouse wheel step is exactly one configured step.
- [ ] Impossible human values show localized errors.

## Country
- [ ] Searchable list.
- [ ] Alphabetical.
- [ ] Flags.
- [ ] Arabic and English.
- [ ] Hamza-insensitive Arabic search.
- [ ] Selected flag appears in onboarding and Dashboard.

## Performance
- [ ] Before/after first meaningful frame timing recorded.
- [ ] No long blank white screen.
- [ ] Startup work is not unnecessarily sequential.

## Final gate
- [ ] `dart format .`
- [ ] `flutter analyze --no-pub`
- [ ] `flutter test`
- [ ] `flutter build web`
- [ ] `flutter build apk --debug`
- [ ] `git diff --check`
- [ ] clean `git status`
- [ ] before/after screenshots approved
