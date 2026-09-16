part of 'bil_workout_routines_page.dart';

/// A pushed route outlives its originating details page. Remove the player,
/// rather than just covering it, when verified paid access ends so native
/// playback is paused and disposed even with fullscreen still on screen.
class _WorkoutVideoAccessGate extends ConsumerWidget {
  const _WorkoutVideoAccessGate({required this.item, required this.child});

  final WellnessContentItem item;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Preserve the bundle-scoped free preview allowlist, including while the
    // account is offline, loading or signed out.
    if (workoutItemAccessGranted(item, null)) return child;
    final access = ref.watch(verifiedSubscriptionAccessProvider);
    if (workoutItemAccessGranted(item, access.asData?.value)) return child;
    return Scaffold(
      key: ValueKey(
        access.isLoading
            ? 'workout-video-access-checking'
            : 'workout-video-access-locked',
      ),
      appBar: AppBar(title: Text(item.title)),
      body: Center(
        child: access.isLoading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: _LockedWorkoutPanel(minimumAccess: item.minimumAccess),
              ),
      ),
    );
  }
}
