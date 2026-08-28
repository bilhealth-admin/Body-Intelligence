import 'package:flutter/services.dart';

class PickedBilContact {
  const PickedBilContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

class ContactPickerService {
  const ContactPickerService();

  static const _channel = MethodChannel('bil/contact_picker');

  Future<PickedBilContact?> pick() async {
    final value = await _channel.invokeMapMethod<String, dynamic>('pick');
    if (value == null) return null;
    final name = (value['name'] as String? ?? '').trim();
    final phone = (value['phone'] as String? ?? '').trim();
    // The native picker can return a contact card without a phone number on
    // iOS. Such a result cannot open the SMS invitation composer and must be
    // treated like a cancelled selection rather than creating an invalid URI.
    if (phone.isEmpty) return null;
    return PickedBilContact(name: name, phone: phone);
  }
}
