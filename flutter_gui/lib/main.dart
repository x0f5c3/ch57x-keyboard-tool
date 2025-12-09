import 'dart:async';

import 'package:flutter/material.dart';

import 'bridge_generated.dart';
import 'ffi.dart';

void main() {
  runApp(const KeyboardGuiApp());
}

class KeyboardGuiApp extends StatefulWidget {
  const KeyboardGuiApp({super.key});

  @override
  State<KeyboardGuiApp> createState() => _KeyboardGuiAppState();
}

class _KeyboardGuiAppState extends State<KeyboardGuiApp> {
  late Future<_GuiBootstrap> _bootstrap;
  final TextEditingController _configController = TextEditingController();
  final Set<int> _activeKeys = <int>{};
  final Set<int> _activeKnobs = <int>{};
  KeyboardLayoutInfo? _selectedLayout;
  String? _status;
  String? _initialExample;

  @override
  void initState() {
    super.initState();
    _bootstrap = _load();
  }

  Future<_GuiBootstrap> _load() async {
    final api = await initApi();
    final layouts = await api.supportedLayouts();
    final example = await api.exampleConfig();
    _selectedLayout = layouts.isNotEmpty ? layouts.first : null;
    _initialExample = example;
    _configController.text = example;
    return _GuiBootstrap(api: api, layouts: layouts);
  }

  @override
  void dispose() {
    _configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CH57x Keyboard Tool',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('CH57x Keyboard GUI'),
        ),
        body: FutureBuilder<_GuiBootstrap>(
          future: _bootstrap,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load bindings: ${snapshot.error}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              );
            }
            final data = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(data.layouts),
                    const SizedBox(height: 16),
                    if (_selectedLayout != null)
                      _KeyboardLayoutView(
                        layout: _selectedLayout!,
                        activeKeys: _activeKeys,
                        activeKnobs: _activeKnobs,
                        onToggleKey: (idx) {
                          setState(() {
                            if (!_activeKeys.add(idx)) {
                              _activeKeys.remove(idx);
                            }
                          });
                        },
                        onToggleKnob: (idx) {
                          setState(() {
                            if (!_activeKnobs.add(idx)) {
                              _activeKnobs.remove(idx);
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 16),
                    _buildConfigEditor(),
                    const SizedBox(height: 8),
                    _buildActions(data.api),
                    if (_status != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _status!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.green.shade700),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(List<KeyboardLayoutInfo> layouts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pick the keyboard layout to visualize the grid and knobs.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        DropdownButton<KeyboardLayoutInfo>(
          isExpanded: true,
          value: _selectedLayout,
          items: layouts
              .map(
                (layout) => DropdownMenuItem(
                  value: layout,
                  child: Text('${layout.name} — ${layout.description}'),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedLayout = value;
              _activeKeys.clear();
              _activeKnobs.clear();
            });
          },
        ),
      ],
    );
  }

  Widget _buildConfigEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YAML configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {
                _configController.text = _initialExample ?? _configController.text;
              },
              child: const Text('Reset'),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _configController,
            maxLines: 12,
            decoration: const InputDecoration.collapsed(
              hintText: 'Paste or edit the keyboard mapping YAML here.',
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(KeyboardApi api) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            try {
              final result = await api.validateConfigYaml(
                yaml: _configController.text,
              );
              final summary =
                  'Valid ✓ • ${result.layers} layers • ${result.buttons} buttons • ${result.knobs} knobs';
              if (mounted) {
                setState(() => _status = summary);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(summary)));
              }
            } catch (err) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Validation failed: $err')),
              );
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('Validate'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            try {
              await api.uploadConfigYaml(yaml: _configController.text);
              if (mounted) {
                setState(() => _status = 'Upload sent to keyboard');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Upload sent to keyboard')),
                );
              }
            } catch (err) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Upload failed: $err')),
              );
            }
          },
          icon: const Icon(Icons.usb),
          label: const Text('Upload to keyboard'),
        ),
      ],
    );
  }
}

class _GuiBootstrap {
  const _GuiBootstrap({
    required this.api,
    required this.layouts,
  });

  final KeyboardApi api;
  final List<KeyboardLayoutInfo> layouts;
}

class _KeyboardLayoutView extends StatelessWidget {
  const _KeyboardLayoutView({
    required this.layout,
    required this.activeKeys,
    required this.activeKnobs,
    required this.onToggleKey,
    required this.onToggleKnob,
  });

  final KeyboardLayoutInfo layout;
  final Set<int> activeKeys;
  final Set<int> activeKnobs;
  final ValueChanged<int> onToggleKey;
  final ValueChanged<int> onToggleKnob;

  @override
  Widget build(BuildContext context) {
    final totalButtons = layout.rows * layout.columns;
    final keyTiles = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: layout.columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: totalButtons,
      itemBuilder: (context, index) {
        final isActive = activeKeys.contains(index);
        return GestureDetector(
          onTap: () => onToggleKey(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isActive ? Colors.blue.shade100 : Colors.grey.shade200,
              border: Border.all(
                color: isActive ? Colors.blue : Colors.grey.shade400,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              'K${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.blue.shade900 : Colors.black87,
              ),
            ),
          ),
        );
      },
    );

    final knobRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(layout.knobs, (idx) {
        final isActive = activeKnobs.contains(idx);
        return ChoiceChip(
          label: Text('Knob ${idx + 1}'),
          selected: isActive,
          avatar: const Icon(Icons.circle),
          onSelected: (_) => onToggleKnob(idx),
        );
      }),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${layout.rows}×${layout.columns} keys and ${layout.knobs} knob(s)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        keyTiles,
        if (layout.knobs > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Knobs',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          knobRow,
        ],
      ],
    );
  }
}
