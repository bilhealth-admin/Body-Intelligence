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
    if (name.isEmpty && phone.isEmpty) return null;
    return PickedBilContact(name: name, phone: phone);
  }
}
