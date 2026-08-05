import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/map/geo_regions.dart';

/// Opens a bottom sheet to pick a country then a region (ISO 3166-2).
/// Returns the selected [GeoRegion], or null if dismissed.
Future<GeoRegion?> showRegionPicker(BuildContext context) {
  return showModalBottomSheet<GeoRegion>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _RegionPickerSheet(),
  );
}

class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet();

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  late final Future<void> _future = GeoRegions.instance.load();
  final _searchController = TextEditingController();
  GeoCountry? _country;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCountry(GeoCountry country) {
    setState(() {
      _country = country;
      _searchController.clear();
      _query = '';
    });
  }

  void _back() {
    setState(() {
      _country = null;
      _searchController.clear();
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                _header(context),
                _searchField(),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: _country == null ? _countryList() : _regionList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          if (_country != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _back,
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              _country == null
                  ? l10nGlobal.selectCountryText
                  : _country!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: _country == null
              ? l10nGlobal.searchCountryText
              : l10nGlobal.searchRegionText,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: AppColors.inputSpace,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _countryList() {
    final countries = _query.isEmpty
        ? GeoRegions.instance.countries
        : GeoRegions.instance.countries
              .where((c) => c.name.toLowerCase().contains(_query))
              .toList();
    return ListView.builder(
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        return ListTile(
          title: Text(
            country.name,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            '${country.regions.length} viloyat',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => _selectCountry(country),
        );
      },
    );
  }

  Widget _regionList() {
    final regions = _query.isEmpty
        ? _country!.regions
        : _country!.regions
              .where((r) => r.name.toLowerCase().contains(_query))
              .toList();
    return ListView.builder(
      itemCount: regions.length,
      itemBuilder: (context, index) {
        final region = regions[index];
        return ListTile(
          leading: const Icon(Icons.place_outlined, color: Color(0xFF2ED573)),
          title: Text(
            region.name,
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () => Navigator.of(context).pop(region),
        );
      },
    );
  }
}
