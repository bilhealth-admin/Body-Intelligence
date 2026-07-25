import 'dart:ui';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/premium_surface.dart';
import '../profile/providers/user_profile_provider.dart';
import 'location_catalog.dart';

class LocationSettingsPage extends ConsumerStatefulWidget {
  const LocationSettingsPage({super.key});

  @override
  ConsumerState<LocationSettingsPage> createState() =>
      _LocationSettingsPageState();
}

class _LocationSettingsPageState extends ConsumerState<LocationSettingsPage> {
  final cityController = TextEditingController();
  final timezoneController = TextEditingController();

  String? countryCode;
  String? countryName;
  bool loading = true;
  bool saving = false;
  bool automaticLocation = true;
  String deviceTimezone = 'UTC';
  List<String> timezoneChoices = bilTimezoneChoices;

  bool get arabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    cityController.dispose();
    timezoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(preferencesRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.get('countryCode'),
      repository.get('countryRegion'),
      repository.get('cityName'),
      repository.get('timezoneName'),
      repository.get('automaticLocation'),
      repository.get('locationSource'),
      _loadDeviceTimezone(),
      _loadTimezoneChoices(),
    ]);
    if (!mounted) return;
    final values = results.take(6).cast<String?>().toList();
    deviceTimezone = results[6] as String;
    timezoneChoices = results[7] as List<String>;

    automaticLocation = values[4] == null
        ? values[5] != 'manual'
        : values[4] == 'true';
    countryCode = values[0];
    countryName = values[1];
    cityController.text = values[2] ?? '';
    timezoneController.text = values[3] ?? '';

    if (automaticLocation) {
      _applyDeviceRegion();
    }

    setState(() => loading = false);
  }

  Future<String> _loadDeviceTimezone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return inferTimezoneFromDeviceName(DateTime.now().timeZoneName) ?? 'UTC';
    }
  }

  Future<List<String>> _loadTimezoneChoices() async {
    try {
      final zones = await FlutterTimezone.getAvailableTimezones();
      final identifiers =
          zones
              .map((zone) => zone.identifier)
              .where(
                (identifier) =>
                    identifier == 'UTC' ||
                    (identifier.contains('/') &&
                        !identifier.startsWith('Etc/') &&
                        !identifier.contains('SystemV')),
              )
              .toSet()
              .toList()
            ..sort();
      return identifiers.isEmpty ? bilTimezoneChoices : identifiers;
    } catch (_) {
      return bilTimezoneChoices;
    }
  }

  void _applyDeviceRegion() {
    final locale = PlatformDispatcher.instance.locale;
    final code = locale.countryCode;
    final timezone = deviceTimezone;

    Country? country;
    if (code != null && code.isNotEmpty) {
      try {
        country = Country.parse(code);
      } catch (_) {
        country = null;
      }
    }

    countryCode = country?.countryCode ?? countryCode;
    countryName = country?.displayNameNoCountryCode ?? countryName;
    timezoneController.text = timezone;

    final cities = bilCityCatalog[countryCode] ?? const [];
    final matching = cities.where((city) => city.timezone == timezone);
    if (matching.isNotEmpty) {
      cityController.text = matching.first.label(arabic);
    } else if (cities.length == 1) {
      cityController.text = cities.first.label(arabic);
    }
  }

  Future<void> _setAutomatic(bool value) async {
    setState(() {
      automaticLocation = value;
      if (value) _applyDeviceRegion();
    });
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        inputDecoration: InputDecoration(
          labelText: arabic ? 'ابحث عن دولة' : 'Search countries',
          prefixIcon: const Icon(Icons.search_rounded),
        ),
      ),
      onSelect: (country) {
        setState(() {
          countryCode = country.countryCode;
          countryName = country.displayNameNoCountryCode;
          cityController.clear();
          final cities = bilCityCatalog[country.countryCode] ?? const [];
          if (cities.isNotEmpty) {
            timezoneController.text = cities.first.timezone;
          }
        });
      },
    );
  }

  void _pickCity() {
    final cities = bilCityCatalog[countryCode] ?? const [];
    if (cities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            arabic
                ? 'اكتب مدينتك يدويًا؛ جميع المدن مقبولة.'
                : 'Enter your city manually; every city is accepted.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                arabic ? 'مدن مقترحة' : 'Suggested cities',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final city in cities)
              ListTile(
                leading: const Icon(Icons.location_city_rounded),
                title: Text(city.label(arabic)),
                subtitle: Text(city.timezone),
                onTap: () {
                  setState(() {
                    cityController.text = city.label(arabic);
                    timezoneController.text = city.timezone;
                  });
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTimezone() async {
    var query = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalized = query.trim().toLowerCase();
          final matches = timezoneChoices.where((identifier) {
            if (normalized.isEmpty) return true;
            final cityLabel = identifier
                .split('/')
                .last
                .replaceAll('_', ' ')
                .toLowerCase();
            final catalogMatch = bilCityCatalog.values
                .expand((cities) => cities)
                .where((city) => city.timezone == identifier)
                .any(
                  (city) =>
                      city.nameEn.toLowerCase().contains(normalized) ||
                      city.nameAr.contains(query.trim()),
                );
            return identifier.toLowerCase().contains(normalized) ||
                cityLabel.contains(normalized) ||
                catalogMatch;
          }).toList();
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: .86,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: TextField(
                      key: const Key('timezone-search-field'),
                      autofocus: true,
                      onChanged: (value) => setSheetState(() => query = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        labelText: arabic
                            ? 'ابحث بالدولة أو المدينة أو المنطقة الزمنية'
                            : 'Search country, city, or timezone',
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final identifier = matches[index];
                        return ListTile(
                          leading: const Icon(Icons.schedule_rounded),
                          title: Text(
                            identifier.split('/').last.replaceAll('_', ' '),
                          ),
                          subtitle: Text(identifier),
                          selected: timezoneController.text == identifier,
                          onTap: () => Navigator.pop(sheetContext, identifier),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected != null) {
      setState(() => timezoneController.text = selected);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      if (automaticLocation) _applyDeviceRegion();

      final repository = ref.read(preferencesRepositoryProvider);

      Future<void> setOrRemove(String key, String? value) async {
        final cleaned = value?.trim() ?? '';
        if (cleaned.isEmpty) {
          await repository.remove(key);
        } else {
          await repository.set(key, cleaned);
        }
      }

      await repository.set(
        'automaticLocation',
        automaticLocation ? 'true' : 'false',
      );
      await repository.set(
        'locationSource',
        automaticLocation ? 'device' : 'manual',
      );
      await setOrRemove('countryCode', countryCode);
      await setOrRemove('countryRegion', countryName);
      await setOrRemove('cityName', cityController.text);
      await setOrRemove('timezoneName', timezoneController.text);
      await repository.set(
        'timezoneOffsetMinutes',
        DateTime.now().timeZoneOffset.inMinutes.toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            arabic
                ? 'تم حفظ إعداد الموقع محليًا.'
                : 'Location settings were saved locally.',
          ),
        ),
      );
      context.go('/settings');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = bilCityCatalog[countryCode] ?? const [];
    final automaticSummary = [
      if (countryName?.trim().isNotEmpty == true) countryName!,
      if (cityController.text.trim().isNotEmpty) cityController.text.trim(),
      if (timezoneController.text.trim().isNotEmpty)
        timezoneController.text.trim(),
    ].join(' · ');

    return Scaffold(
      backgroundColor: const Color(0xFF01050D),
      appBar: AppBar(
        title: Text(arabic ? 'الموقع والوقت المحلي' : 'Location & local time'),
        leading: IconButton(
          key: const Key('location-settings-back'),
          tooltip: arabic ? 'العودة إلى الإعدادات' : 'Back to settings',
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PremiumSurface(
                  emphasized: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          arabic
                              ? 'إعداد محلي ذكي وآمن'
                              : 'Smart, private local setup',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        arabic
                            ? 'يستخدم BIL منطقة الجهاز ولغته وتوقيته لتخصيص التجربة. لا يستخدم GPS ولا يرفع موقعك.'
                            : 'BIL uses the device region, locale, and timezone to personalize the experience. It does not use GPS or upload your location.',
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        key: const Key('automatic-location-switch'),
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.my_location_rounded),
                        value: automaticLocation,
                        onChanged: _setAutomatic,
                        title: Text(
                          arabic
                              ? 'تحديد تلقائي من الجهاز'
                              : 'Automatic device region',
                        ),
                        subtitle: Text(
                          automaticLocation
                              ? (automaticSummary.isEmpty
                                    ? (arabic
                                          ? 'سيتم استخدام إعداد الجهاز عند الحفظ.'
                                          : 'Device settings will be used when saved.')
                                    : automaticSummary)
                              : (arabic
                                    ? 'أوقف التحديد التلقائي لاختيار الدولة والمدينة يدويًا.'
                                    : 'Manual country and city selection is enabled.'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!automaticLocation) ...[
                  const SizedBox(height: 16),
                  PremiumSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.public_rounded),
                          title: Text(arabic ? 'الدولة' : 'Country'),
                          subtitle: Text(
                            countryName ??
                                (arabic ? 'اختر دولة' : 'Choose a country'),
                          ),
                          trailing: const Icon(Icons.expand_more_rounded),
                          onTap: _pickCountry,
                        ),
                        const Divider(),
                        TextField(
                          key: const Key('location-city-field'),
                          controller: cityController,
                          autofillHints: const [AutofillHints.addressCity],
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.location_city_rounded),
                            labelText: arabic ? 'المدينة' : 'City',
                            helperText: cities.isEmpty
                                ? (arabic
                                      ? 'اكتب أي مدينة يدويًا.'
                                      : 'Enter any city manually.')
                                : (arabic
                                      ? 'يمكنك الكتابة أو اختيار اقتراح.'
                                      : 'Type freely or choose a suggestion.'),
                            suffixIcon: IconButton(
                              tooltip: arabic
                                  ? 'عرض المدن المقترحة'
                                  : 'Show suggested cities',
                              onPressed: _pickCity,
                              icon: const Icon(Icons.list_alt_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('location-timezone-field'),
                          controller: timezoneController,
                          readOnly: true,
                          onTap: _pickTimezone,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.schedule_rounded),
                            suffixIcon: const Icon(Icons.expand_more_rounded),
                            labelText: arabic ? 'المنطقة الزمنية' : 'Timezone',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('location-settings-save'),
                  onPressed: saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    saving
                        ? (arabic ? 'جارٍ الحفظ…' : 'Saving…')
                        : (arabic
                              ? 'حفظ والعودة إلى الإعدادات'
                              : 'Save and return to settings'),
                  ),
                ),
              ],
            ),
    );
  }
}
