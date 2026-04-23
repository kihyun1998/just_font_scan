import 'package:flutter/material.dart';
import 'package:just_font_scan/just_font_scan.dart';

import 'font_family_tile.dart';

bool _hasAnyAxis(FontFamily f) =>
    f.weightAxis != null ||
    f.widthAxis != null ||
    f.slantAxis != null ||
    f.italicAxis != null ||
    f.opticalSizeAxis != null;

bool _hasMonospaceFace(FontFamily f) => f.faces.any((face) => face.isMonospace);

class FontListPage extends StatefulWidget {
  const FontListPage({super.key});

  @override
  State<FontListPage> createState() => _FontListPageState();
}

class _FontListPageState extends State<FontListPage> {
  List<FontFamily> _families = const [];
  List<FontFamily> _filtered = const [];
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _onlyVariable = false;
  bool _onlyMonospace = false;

  // One ValueNotifier per variable-font family, lazily created.
  // Lifting this out of the tile's State preserves the slider value
  // when the ListView recycles the tile as it scrolls off-screen.
  final Map<String, ValueNotifier<double>> _wghtNotifiers = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final n in _wghtNotifiers.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _scan() {
    setState(() => _loading = true);
    final results = JustFontScan.scan();
    setState(() {
      _families = results;
      _loading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _families.where((f) {
        if (_onlyVariable && !_hasAnyAxis(f)) return false;
        if (_onlyMonospace && !_hasMonospaceFace(f)) return false;
        if (q.isNotEmpty && !f.name.toLowerCase().contains(q)) return false;
        return true;
      }).toList();
    });
  }

  ValueNotifier<double> _notifierFor(FontFamily f) {
    return _wghtNotifiers.putIfAbsent(
      f.name,
      () => ValueNotifier<double>(f.weightAxis!.defaultValue.toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vfCount = _families.where(_hasAnyAxis).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'System Fonts · ${_filtered.length}/${_families.length} · VF $vfCount',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              JustFontScan.clearCache();
              _searchController.clear();
              _scan();
            },
            tooltip: 'Rescan',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search font family...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _applyFilter(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: const Text('Variable only'),
                      selected: _onlyVariable,
                      onSelected: (v) {
                        setState(() => _onlyVariable = v);
                        _applyFilter();
                      },
                    ),
                    FilterChip(
                      label: const Text('Monospace only'),
                      selected: _onlyMonospace,
                      onSelected: (v) {
                        setState(() => _onlyMonospace = v);
                        _applyFilter();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final family = _filtered[index];
                      return FontFamilyTile(
                        family: family,
                        wghtNotifier: family.weightAxis != null
                            ? _notifierFor(family)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
