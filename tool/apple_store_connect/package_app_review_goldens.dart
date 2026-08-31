import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

const _sourceDirectory = 'test/features/commerce/goldens/app_store_review/v1.0';
const _outputDirectory = 'store_assets/review/apple/v1.0';
const _expectedWidth = 1170;
const _expectedHeight = 2532;

const _productIds = <String>[
  'bil_premium',
  'bil_premium_annual',
  'bil_premium_ai_coach',
  'bil_premium_ai_coach_annual',
  'bil_ai_boost',
];

const _reviewMetadata = <String, Map<String, Object?>>{
  'bil_premium': {
    'selectedTerm': 'MONTHLY',
    'localizedPrice': 'EGP 129.99',
    'currencyCode': 'EGP',
    'storeCountryCode': 'EGY',
    'availabilityPolicy': 'EGY/IND/PAK/TUR only',
  },
  'bil_premium_annual': {
    'selectedTerm': 'ANNUAL',
    'localizedPrice': 'EGP 999.99',
    'currencyCode': 'EGP',
    'storeCountryCode': 'EGY',
    'availabilityPolicy': 'EGY/IND/PAK/TUR only',
    'derivedSavingsBadge': 'Save 36%',
    'badgeCalculation': 'round((129.99 * 12 - 999.99) / (129.99 * 12) * 100)',
  },
  'bil_premium_ai_coach': {
    'selectedTerm': 'MONTHLY',
    'localizedPrice': r'$5.99',
    'currencyCode': 'USD',
    'storeCountryCode': 'USA',
  },
  'bil_premium_ai_coach_annual': {
    'selectedTerm': 'ANNUAL',
    'localizedPrice': r'$49.99',
    'currencyCode': 'USD',
    'storeCountryCode': 'USA',
    'derivedSavingsBadge': 'Save 30%',
    'badgeCalculation': 'round((5.99 * 12 - 49.99) / (5.99 * 12) * 100)',
  },
  'bil_ai_boost': {
    'selectedTerm': 'ONE_TIME_CONSUMABLE',
    'localizedPrice': r'$2.49',
    'currencyCode': 'USD',
    'storeCountryCode': 'USA',
    'discountBadge': null,
  },
};

void main() {
  final sourceDirectory = Directory(_sourceDirectory);
  if (!sourceDirectory.existsSync()) {
    stderr.writeln('Missing golden directory: ${sourceDirectory.path}');
    exitCode = 1;
    return;
  }

  final outputDirectory = Directory(_outputDirectory)
    ..createSync(recursive: true);
  final entries = <Map<String, Object?>>[];

  for (final productId in _productIds) {
    final source = File('${sourceDirectory.path}/$productId.png');
    if (!source.existsSync()) {
      throw StateError('Missing review golden for $productId: ${source.path}');
    }

    final decoded = img.decodePng(source.readAsBytesSync());
    if (decoded == null) {
      throw StateError('Could not decode ${source.path}');
    }
    if (decoded.width != _expectedWidth || decoded.height != _expectedHeight) {
      throw StateError(
        '$productId must be ${_expectedWidth}x$_expectedHeight; '
        'found ${decoded.width}x${decoded.height}.',
      );
    }

    if (decoded.hasAlpha) {
      for (final pixel in decoded) {
        if (pixel.aNormalized < 1) {
          throw StateError(
            '$productId contains transparency. Review screenshots must be '
            'fully opaque before RGB flattening.',
          );
        }
      }
    }

    final flattened = decoded.convert(numChannels: 3, noAnimation: true);
    final output = File('${outputDirectory.path}/$productId.png');
    output.writeAsBytesSync(img.encodePng(flattened));

    final packaged = img.decodePng(output.readAsBytesSync());
    if (packaged == null ||
        packaged.width != _expectedWidth ||
        packaged.height != _expectedHeight ||
        packaged.hasAlpha ||
        packaged.numChannels != 3) {
      throw StateError('$productId failed packaged RGB PNG validation.');
    }

    final reviewMetadata = _reviewMetadata[productId];
    if (reviewMetadata == null) {
      throw StateError('Missing review metadata for $productId.');
    }
    if ((productId == 'bil_premium' || productId == 'bil_premium_annual') &&
        reviewMetadata['currencyCode'] == 'USD') {
      throw StateError(
        '$productId is not sold in USA; its review attachment cannot invent '
        'USD StoreKit metadata.',
      );
    }

    entries.add({
      'productId': productId,
      'file': output.path.replaceAll('\\', '/'),
      'width': packaged.width,
      'height': packaged.height,
      'colorChannels': packaged.numChannels,
      'hasAlpha': packaged.hasAlpha,
      'sha256': sha256.convert(output.readAsBytesSync()).toString(),
      ...reviewMetadata,
    });
  }

  final manifest = File('${outputDirectory.path}/manifest.json');
  manifest.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'purpose': 'App Store Connect subscription and IAP review screenshots', 'source': _sourceDirectory, 'pixelSize': '${_expectedWidth}x$_expectedHeight', 'files': entries})}\n',
  );

  stdout.writeln(
    'Packaged ${entries.length} opaque RGB review screenshots in '
    '${outputDirectory.path}.',
  );
}
