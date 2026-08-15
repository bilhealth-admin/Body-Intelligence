abstract final class AuthInputValidation {
  static String normalizeInternationalPhone(String? value) {
    var phone = (value ?? '').trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (phone.startsWith('00')) phone = '+${phone.substring(2)}';
    return phone;
  }

  static String normalizeNationalPhone(
    String? value,
    String dialingCode, {
    String? nationalExample,
  }) {
    final raw = (value ?? '').trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (raw.startsWith('+')) {
      return normalizeInternationalPhone(raw);
    }
    if (raw.startsWith('00')) {
      final international = normalizeInternationalPhone(raw);
      if (RegExp(r'^\+[1-9]\d*$').hasMatch(international)) {
        return international;
      }
    }
    // The registration field accepts a national mobile number. National
    // trunk zeroes are not part of its E.164 representation. Strip every
    // leading trunk zero here as well as in the visible field so autofill and
    // programmatic controller updates cannot bypass the normalization.
    final national = raw.replaceFirst(RegExp(r'^0+'), '');
    return '+$dialingCode$national';
  }

  /// Normalizes text shown beside a fixed country calling-code prefix.
  ///
  /// A full number pasted with the currently selected calling code is reduced
  /// to its national part. A full number for another country remains explicit
  /// (and is rejected by [isValidNationalPhone]) instead of being silently
  /// combined with the selected prefix.
  static String normalizeVisibleNationalPhone(
    String? value,
    String dialingCode,
  ) {
    final raw = value ?? '';
    final compact = raw.trim().replaceAll(RegExp(r'[\s()-]'), '');
    final selectedPrefix = '+$dialingCode';

    if (compact.startsWith('00')) {
      final international = normalizeInternationalPhone(compact);
      if (RegExp(r'^\+[1-9]\d*$').hasMatch(international)) {
        return international.startsWith(selectedPrefix)
            ? international.substring(selectedPrefix.length)
            : international;
      }
    }
    if (compact.startsWith(selectedPrefix)) {
      return compact.substring(selectedPrefix.length);
    }
    if (compact.startsWith('+')) return compact;
    return raw.replaceFirst(RegExp(r'^0+'), '');
  }

  static bool isValidNationalPhone(
    String? value,
    String dialingCode, {
    String? nationalExample,
  }) {
    final normalized = normalizeNationalPhone(
      value,
      dialingCode,
      nationalExample: nationalExample,
    );
    return normalized.startsWith('+$dialingCode') &&
        RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized);
  }

  static bool isValidInternationalPhone(String? value) =>
      RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalizeInternationalPhone(value));

  static bool isValidEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || email.length > 254 || email.contains(RegExp(r'\s'))) {
      return false;
    }
    final separator = email.lastIndexOf('@');
    if (separator <= 0 || separator != email.indexOf('@') || separator > 64) {
      return false;
    }
    final domain = email.substring(separator + 1);
    if (domain.length < 3 || domain.startsWith('.') || domain.endsWith('.')) {
      return false;
    }
    final labels = domain.split('.');
    if (labels.length < 2) return false;
    return labels.every(
      (label) =>
          label.isNotEmpty &&
          label.length <= 63 &&
          !label.startsWith('-') &&
          !label.endsWith('-') &&
          RegExp(r'^[A-Za-z0-9-]+$').hasMatch(label),
    );
  }
}
