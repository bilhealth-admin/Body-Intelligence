abstract interface class OpenFoodFactsClient {
  Future<Map<String, Object?>?> fetchProduct(String canonicalBarcode);
}
