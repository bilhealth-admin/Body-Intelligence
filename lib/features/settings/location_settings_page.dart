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

  String get localeCode =>
      Localizations.localeOf(context).languageCode.toLowerCase();

  String l(String key) =>
      _locationCopy[localeCode]?[key] ?? _locationCopy['en']![key]!;

  String cityLabel(BilCityOption city) => switch (localeCode) {
    'ar' => city.nameAr,
    'en' || 'fr' || 'es' || 'tr' => city.nameEn,
    _ => city.nameEn,
  };

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
      cityController.text = cityLabel(matching.first);
    } else if (cities.length == 1) {
      cityController.text = cityLabel(cities.first);
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
          labelText: l('searchCountries'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l('manualCityAccepted'))));
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
                l('suggestedCities'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final city in cities)
              ListTile(
                leading: const Icon(Icons.location_city_rounded),
                title: Text(cityLabel(city)),
                subtitle: Text(city.timezone),
                onTap: () {
                  setState(() {
                    cityController.text = cityLabel(city);
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
                        labelText: l('searchTimezone'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l('saved'))));
      context.go('/settings');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l('saveFailed'))));
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
        title: Text(l('title')),
        leading: IconButton(
          key: const Key('location-settings-back'),
          tooltip: l('back'),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
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
                          l('heading'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(l('description')),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        key: const Key('automatic-location-switch'),
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.my_location_rounded),
                        value: automaticLocation,
                        onChanged: _setAutomatic,
                        title: Text(l('automatic')),
                        subtitle: Text(
                          automaticLocation
                              ? (automaticSummary.isEmpty
                                    ? l('deviceOnSave')
                                    : automaticSummary)
                              : l('manualEnabled'),
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
                          title: Text(l('country')),
                          subtitle: Text(countryName ?? l('chooseCountry')),
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
                            labelText: l('city'),
                            helperText: cities.isEmpty
                                ? l('enterAnyCity')
                                : l('typeOrSuggest'),
                            suffixIcon: IconButton(
                              tooltip: l('showSuggested'),
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
                            labelText: l('timezone'),
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
                  label: Text(saving ? l('saving') : l('saveAndReturn')),
                ),
              ],
            ),
    );
  }
}

const _locationCopy = <String, Map<String, String>>{
  'en': {
    'searchCountries': 'Search countries',
    'manualCityAccepted': 'Enter your city manually; every city is accepted.',
    'suggestedCities': 'Suggested cities',
    'searchTimezone': 'Search country, city, or timezone',
    'saved': 'Location settings were saved locally.',
    'saveFailed': 'Location settings could not be saved. Please try again.',
    'title': 'Location & local time',
    'back': 'Back to settings',
    'heading': 'Smart, private local setup',
    'description':
        'BIL uses the device region, locale, and timezone to personalize the experience. It does not use GPS or upload your location.',
    'automatic': 'Automatic device region',
    'deviceOnSave': 'Device settings will be used when saved.',
    'manualEnabled': 'Manual country and city selection is enabled.',
    'country': 'Country',
    'chooseCountry': 'Choose a country',
    'city': 'City',
    'enterAnyCity': 'Enter any city manually.',
    'typeOrSuggest': 'Type freely or choose a suggestion.',
    'showSuggested': 'Show suggested cities',
    'timezone': 'Timezone',
    'saving': 'Saving…',
    'saveAndReturn': 'Save and return to settings',
  },
  'ar': {
    'searchCountries': 'ابحث عن دولة',
    'manualCityAccepted': 'اكتب مدينتك يدويًا؛ جميع المدن مقبولة.',
    'suggestedCities': 'مدن مقترحة',
    'searchTimezone': 'ابحث بالدولة أو المدينة أو المنطقة الزمنية',
    'saved': 'تم حفظ إعداد الموقع محليًا.',
    'saveFailed': 'تعذّر حفظ إعدادات الموقع. حاول مرة أخرى.',
    'title': 'الموقع والوقت المحلي',
    'back': 'العودة إلى الإعدادات',
    'heading': 'إعداد محلي ذكي وآمن',
    'description':
        'يستخدم BIL منطقة الجهاز ولغته وتوقيته لتخصيص التجربة. لا يستخدم GPS ولا يرفع موقعك.',
    'automatic': 'تحديد تلقائي من الجهاز',
    'deviceOnSave': 'سيتم استخدام إعداد الجهاز عند الحفظ.',
    'manualEnabled': 'تم تفعيل الاختيار اليدوي للدولة والمدينة.',
    'country': 'الدولة',
    'chooseCountry': 'اختر دولة',
    'city': 'المدينة',
    'enterAnyCity': 'اكتب أي مدينة يدويًا.',
    'typeOrSuggest': 'يمكنك الكتابة أو اختيار اقتراح.',
    'showSuggested': 'عرض المدن المقترحة',
    'timezone': 'المنطقة الزمنية',
    'saving': 'جارٍ الحفظ…',
    'saveAndReturn': 'حفظ والعودة إلى الإعدادات',
  },
  'fr': {
    'searchCountries': 'Rechercher un pays',
    'manualCityAccepted':
        'Saisissez votre ville manuellement ; toutes les villes sont acceptées.',
    'suggestedCities': 'Villes suggérées',
    'searchTimezone': 'Rechercher un pays, une ville ou un fuseau horaire',
    'saved': 'Les paramètres de localisation ont été enregistrés localement.',
    'saveFailed':
        'Impossible d’enregistrer les paramètres de localisation. Réessayez.',
    'title': 'Localisation et heure locale',
    'back': 'Retour aux paramètres',
    'heading': 'Configuration locale intelligente et privée',
    'description':
        'BIL utilise la région, la langue et le fuseau horaire de l’appareil pour personnaliser l’expérience. Il n’utilise pas le GPS et ne transmet pas votre position.',
    'automatic': 'Région automatique de l’appareil',
    'deviceOnSave':
        'Les paramètres de l’appareil seront utilisés lors de l’enregistrement.',
    'manualEnabled':
        'La sélection manuelle du pays et de la ville est activée.',
    'country': 'Pays',
    'chooseCountry': 'Choisir un pays',
    'city': 'Ville',
    'enterAnyCity': 'Saisissez librement une ville.',
    'typeOrSuggest': 'Saisissez une ville ou choisissez une suggestion.',
    'showSuggested': 'Afficher les villes suggérées',
    'timezone': 'Fuseau horaire',
    'saving': 'Enregistrement…',
    'saveAndReturn': 'Enregistrer et revenir aux paramètres',
  },
  'es': {
    'searchCountries': 'Buscar países',
    'manualCityAccepted':
        'Introduce tu ciudad manualmente; se acepta cualquier ciudad.',
    'suggestedCities': 'Ciudades sugeridas',
    'searchTimezone': 'Buscar país, ciudad o zona horaria',
    'saved': 'La configuración de ubicación se guardó localmente.',
    'saveFailed':
        'No se pudo guardar la configuración de ubicación. Inténtalo de nuevo.',
    'title': 'Ubicación y hora local',
    'back': 'Volver a ajustes',
    'heading': 'Configuración local inteligente y privada',
    'description':
        'BIL usa la región, el idioma y la zona horaria del dispositivo para personalizar la experiencia. No usa GPS ni sube tu ubicación.',
    'automatic': 'Región automática del dispositivo',
    'deviceOnSave': 'Los ajustes del dispositivo se usarán al guardar.',
    'manualEnabled': 'La selección manual de país y ciudad está activada.',
    'country': 'País',
    'chooseCountry': 'Elegir un país',
    'city': 'Ciudad',
    'enterAnyCity': 'Introduce cualquier ciudad manualmente.',
    'typeOrSuggest': 'Escribe libremente o elige una sugerencia.',
    'showSuggested': 'Mostrar ciudades sugeridas',
    'timezone': 'Zona horaria',
    'saving': 'Guardando…',
    'saveAndReturn': 'Guardar y volver a ajustes',
  },
  'tr': {
    'searchCountries': 'Ülke ara',
    'manualCityAccepted': 'Şehrinizi elle girin; tüm şehirler kabul edilir.',
    'suggestedCities': 'Önerilen şehirler',
    'searchTimezone': 'Ülke, şehir veya saat dilimi ara',
    'saved': 'Konum ayarları yerel olarak kaydedildi.',
    'saveFailed': 'Konum ayarları kaydedilemedi. Lütfen tekrar deneyin.',
    'title': 'Konum ve yerel saat',
    'back': 'Ayarlara dön',
    'heading': 'Akıllı ve özel yerel kurulum',
    'description':
        'BIL deneyimi kişiselleştirmek için cihazın bölgesini, dilini ve saat dilimini kullanır. GPS kullanmaz ve konumunuzu yüklemez.',
    'automatic': 'Otomatik cihaz bölgesi',
    'deviceOnSave': 'Kaydedildiğinde cihaz ayarları kullanılacak.',
    'manualEnabled': 'Elle ülke ve şehir seçimi etkin.',
    'country': 'Ülke',
    'chooseCountry': 'Ülke seçin',
    'city': 'Şehir',
    'enterAnyCity': 'Herhangi bir şehri elle girin.',
    'typeOrSuggest': 'Serbestçe yazın veya bir öneri seçin.',
    'showSuggested': 'Önerilen şehirleri göster',
    'timezone': 'Saat dilimi',
    'saving': 'Kaydediliyor…',
    'saveAndReturn': 'Kaydet ve ayarlara dön',
  },
};
