part of 'recipe_library_page.dart';

class _RecipeLibraryDetailVisit extends ConsumerStatefulWidget {
  const _RecipeLibraryDetailVisit({required this.load, required this.image});
  final Future<RecipeCatalogDetail> Function() load;
  final Future<WellnessMediaCacheResult>? Function() image;

  @override
  ConsumerState<_RecipeLibraryDetailVisit> createState() =>
      _RecipeLibraryDetailVisitState();
}

class _RecipeLibraryDetailVisitState
    extends ConsumerState<_RecipeLibraryDetailVisit> {
  late final Future<RecipeCatalogDetail> _detail;
  late final Future<WellnessMediaCacheResult>? _image;
  late final String? _owner;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(verifiedEntitlementOwnerIdProvider);
    _detail = Future<RecipeCatalogDetail>.sync(widget.load);
    _image = widget.image();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(verifiedEntitlementOwnerIdProvider) == _owner;
    return FutureBuilder<RecipeCatalogDetail>(
      future: _detail,
      builder: (context, snapshot) {
        if (current && snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 320,
            child: Center(child: BilFeatureWelcomeStatus()),
          );
        }
        if (!current || snapshot.hasError || !snapshot.hasData) {
          return SizedBox(
            height: 320,
            child: Center(
              child: Text(
                wellnessCopy(
                  context,
                  'Recipe details are unavailable.',
                  'تفاصيل الوصفة غير متاحة.',
                ),
              ),
            ),
          );
        }
        return _RecipeDetails(
          detail: snapshot.requireData,
          imageResult: _image,
        );
      },
    );
  }
}
