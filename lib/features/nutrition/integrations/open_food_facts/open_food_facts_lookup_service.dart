import '../../domain/barcode_identity.dart';
import '../../domain/unified_food.dart';
import 'open_food_facts_client.dart';
import 'open_food_facts_mapper.dart';

enum OpenFoodFactsLookupStatus {
  invalidBarcode,
  notFound,
  malformedProduct,
  resolved,
  unavailable,
}

class OpenFoodFactsLookupResult {
  final OpenFoodFactsLookupStatus status;
  final BarcodeIdentity barcode;
  final UnifiedFood? food;
  final String? diagnostic;

  const OpenFoodFactsLookupResult({
    required this.status,
    required this.barcode,
    this.food,
    this.diagnostic,
  });
}

class OpenFoodFactsLookupService {
  final OpenFoodFactsClient client;
  final OpenFoodFactsMapper mapper;

  const OpenFoodFactsLookupService({
    required this.client,
    this.mapper = const OpenFoodFactsMapper(),
  });

  Future<OpenFoodFactsLookupResult> lookup(String rawBarcode) async {
    final barcode = BarcodeIdentity.parse(rawBarcode);
    if (!barcode.isValid) {
      return OpenFoodFactsLookupResult(
        status: OpenFoodFactsLookupStatus.invalidBarcode,
        barcode: barcode,
        diagnostic: barcode.issue?.name,
      );
    }

    Map<String, Object?>? response;
    try {
      response = await client.fetchProduct(barcode.digits);
    } on Object catch (error) {
      return OpenFoodFactsLookupResult(
        status: OpenFoodFactsLookupStatus.unavailable,
        barcode: barcode,
        diagnostic: error.runtimeType.toString(),
      );
    }

    if (response == null || !_isFound(response)) {
      return OpenFoodFactsLookupResult(
        status: OpenFoodFactsLookupStatus.notFound,
        barcode: barcode,
      );
    }

    final product = _map(response['product']);
    final food = mapper.mapProduct(barcode: barcode.digits, product: product);
    if (food == null) {
      return OpenFoodFactsLookupResult(
        status: OpenFoodFactsLookupStatus.malformedProduct,
        barcode: barcode,
        diagnostic: 'missing-product-name',
      );
    }

    return OpenFoodFactsLookupResult(
      status: OpenFoodFactsLookupStatus.resolved,
      barcode: barcode,
      food: food,
    );
  }

  bool _isFound(Map<String, Object?> response) {
    final status = response['status'];
    if (status is num) return status.toInt() == 1;
    if (status is String) return status.trim() == '1';
    return response['product'] is Map;
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return const <String, Object?>{};
  }
}
