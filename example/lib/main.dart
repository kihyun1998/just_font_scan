import 'package:flutter/material.dart';
import 'package:just_font_scan/just_font_scan.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'just_font_scan Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const FontListPage(),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _scan();
  }

  void _scan() {
    setState(() => _loading = true);
    final results = JustFontScan.scan();
    setState(() {
      _families = results;
      _filtered = results;
      _loading = false;
    });
  }

  void _onSearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _families
          : _families.where((f) => f.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('System Fonts (${_filtered.length})'),
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
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search font family...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final family = _filtered[index];
                      return _FontFamilyTile(family: family);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FontFamilyTile extends StatelessWidget {
  final FontFamily family;
  const _FontFamilyTile({required this.family});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(family.name),
      subtitle: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: family.weights.map((w) {
          return Chip(
            label: Text('$w', style: const TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(),
      ),
    );
  }
}
