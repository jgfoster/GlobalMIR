import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scoring.dart';

/// Application version, reported on the About tab and in copied summaries so a
/// recorded score can be traced back to the code that produced it.
const String kAppVersion = '1.0.0';

/// Where the source, licence and issue tracker live.
const String kSourceUrl = 'https://github.com/jgfoster/GlobalMIR';

void main() => runApp(const GlobalMirApp());

class GlobalMirApp extends StatefulWidget {
  const GlobalMirApp({super.key});

  @override
  State<GlobalMirApp> createState() => _GlobalMirAppState();
}

class _GlobalMirAppState extends State<GlobalMirApp> {
  ThemeMode _mode = ThemeMode.light;

  ThemeData _theme(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E6F9E),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF7F8FA)
          : scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global MIR Calculator',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomePage(
        isDark: _mode == ThemeMode.dark,
        onToggleTheme: () => setState(() {
          _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
      ),
    );
  }
}

/// Accent colour for a rating level, used consistently across the app.
Color levelColor(double v, ColorScheme scheme) => switch (v) {
      0 => scheme.outline,
      0.5 => const Color(0xFF3E8FB0),
      1 => const Color(0xFFC98A1B),
      2 => const Color(0xFFD1652B),
      3 => const Color(0xFFB3372F),
      _ => scheme.outline,
    };

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.isDark, required this.onToggleTheme});

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  List<double> _scores = List<double>.filled(kDomains.length, 0);
  String? _loadedScenario;
  late final TabController _tabs = TabController(length: 4, vsync: this);

  MirResult get _result => scoreMir(_scores);

  void _set(int index, double value) {
    setState(() {
      _scores = List<double>.of(_scores)..[index] = value;
      _loadedScenario = null;
    });
  }

  void _reset() {
    setState(() {
      _scores = List<double>.filled(kDomains.length, 0);
      _loadedScenario = null;
    });
  }

  void _loadScenario(Scenario s) {
    setState(() {
      _scores = List<double>.of(s.scores);
      _loadedScenario = s.name;
      _tabs.index = 0;
    });
  }

  void _showTerms() => setState(() => _tabs.index = 3);

  Future<void> _copySummary() async {
    final MirResult r = _result;
    final StringBuffer b = StringBuffer('Global MIR summary')
      ..writeln()
      ..writeln('------------------');
    for (int i = 0; i < kDomains.length; i++) {
      b.writeln('${kDomains[i]}: ${fmt(_scores[i])}');
    }
    b
      ..writeln('------------------')
      ..writeln('Global MIR: ${fmt(r.global)} (${levelLabel(r.global)})')
      ..writeln('Rule applied: ${r.rule.id}')
      ..writeln('Sum of domains: ${fmt(r.sum)} of 36')
      ..writeln('------------------')
      ..writeln('Global MIR Calculator v$kAppVersion. A reference aid: verify')
      ..writeln('results and do not use them alone to guide patient care.');
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary copied to clipboard')),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            const Flexible(
              child: Text(
                'Global MIR Calculator',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (_loadedScenario != null) ...<Widget>[
              const SizedBox(width: 12),
              Flexible(
                child: Chip(
                  label: Text(_loadedScenario!, overflow: TextOverflow.ellipsis),
                  visualDensity: VisualDensity.compact,
                  onDeleted: _reset,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copy summary',
            onPressed: _copySummary,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'Reset all domains to 0',
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            tooltip: widget.isDark ? 'Light theme' : 'Dark theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: 'Rate'),
            Tab(text: 'Examples'),
            Tab(text: 'Rules'),
            Tab(text: 'About'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          _RateTab(
            scores: _scores,
            result: _result,
            onChanged: _set,
            onShowTerms: _showTerms,
          ),
          ExamplesTab(onLoad: _loadScenario),
          const RulesTab(),
          const AboutTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Rate tab

class _RateTab extends StatelessWidget {
  const _RateTab({
    required this.scores,
    required this.result,
    required this.onChanged,
    required this.onShowTerms,
  });

  final List<double> scores;
  final MirResult result;
  final void Function(int index, double value) onChanged;
  final VoidCallback onShowTerms;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool wide = c.maxWidth >= 1000;
        final Widget domains = DomainList(
          scores: scores,
          maxDomains: result.maxDomains,
          onChanged: onChanged,
        );
        final Widget summary = ResultPanel(
          scores: scores,
          result: result,
          onShowTerms: onShowTerms,
        );

        if (!wide) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[summary, const SizedBox(height: 16), domains],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[domains],
              ),
            ),
            SizedBox(
              width: 380,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                children: <Widget>[summary],
              ),
            ),
          ],
        );
      },
    );
  }
}

class DomainList extends StatelessWidget {
  const DomainList({
    super.key,
    required this.scores,
    required this.maxDomains,
    required this.onChanged,
  });

  final List<double> scores;
  final List<int> maxDomains;
  final void Function(int index, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Domain ratings', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Rate each of the twelve domains. 0 = normal, 0.5 = subtle/questionable, '
                  '1 = mild but definite, 2 = moderate, 3 = severe.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          for (int i = 0; i < kDomains.length; i++)
            DomainRow(
              index: i,
              value: scores[i],
              isMax: maxDomains.contains(i),
              onChanged: (double v) => onChanged(i, v),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class DomainRow extends StatelessWidget {
  const DomainRow({
    super.key,
    required this.index,
    required this.value,
    required this.isMax,
    required this.onChanged,
  });

  final int index;
  final double value;
  final bool isMax;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final Widget label = Row(
      children: <Widget>[
        SizedBox(
          width: 26,
          child: Text('${index + 1}.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(
            kDomains[index],
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: value > 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (isMax)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Tooltip(
              message: 'Highest rated domain',
              child: Icon(Icons.arrow_upward,
                  size: 16, color: levelColor(value, scheme)),
            ),
          ),
      ],
    );

    final Widget selector = RatingSelector(value: value, onChanged: onChanged);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        color: value > 0
            ? levelColor(value, scheme).withValues(alpha: 0.05)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          if (c.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                label,
                const SizedBox(height: 8),
                selector,
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: label),
              const SizedBox(width: 16),
              selector,
            ],
          );
        },
      ),
    );
  }
}

/// The 0 / 0.5 / 1 / 2 / 3 segmented picker for one domain.
class RatingSelector extends StatelessWidget {
  const RatingSelector({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      children: <Widget>[
        for (final double level in kLevels)
          _Segment(
            label: fmt(level),
            selected: value == level,
            color: levelColor(level, scheme),
            tooltip: '${fmt(level)} - ${levelLabel(level)}',
            onTap: () => onChanged(level),
          ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        selected: selected,
        button: true,
        label: tooltip,
        child: Material(
          color: selected ? color : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 46,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? color : scheme.outlineVariant,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Result panel

class ResultPanel extends StatelessWidget {
  const ResultPanel({
    super.key,
    required this.scores,
    required this.result,
    required this.onShowTerms,
  });

  final List<double> scores;
  final MirResult result;
  final VoidCallback onShowTerms;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = levelColor(result.global, scheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                color: accent.withValues(alpha: 0.10),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('GLOBAL MIR',
                              style: theme.textTheme.labelMedium?.copyWith(
                                letterSpacing: 1.2,
                                color: scheme.onSurfaceVariant,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            levelLabel(result.global),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: accent),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      fmt(result.global),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Rule ${result.rule.id}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.onSecondaryContainer)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(result.rule.description,
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Sum of domain ratings',
                              style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text('Continuous measure, 0 to 36',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text(
                      fmt(result.sum),
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: result.sum / 36,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const Divider(height: 28),
                _Stat(
                  label: 'Maximum domain rating',
                  value: result.max == 0 ? '0' : fmt(result.max),
                ),
                _Stat(
                  label: 'Domains at that maximum',
                  value: '${result.maxCount}',
                ),
                _Stat(
                  label: 'Domains rated above 0',
                  value: '${result.nonZeroCount} of ${kDomains.length}',
                ),
                if (result.maxDomains.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text('Highest rated:',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final int i in result.maxDomains)
                        Chip(
                          label: Text(kDomainsShort[i]),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A reference aid for qualified clinicians. Domain ratings must be '
          'assigned by a qualified examiner, and results should be '
          'independently re-checked. Not a substitute for clinical judgment.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        Center(
          child: TextButton(
            onPressed: onShowTerms,
            child: const Text('Terms of use and disclaimer'),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Examples tab

class ExamplesTab extends StatelessWidget {
  const ExamplesTab({super.key, required this.onLoad});

  final void Function(Scenario) onLoad;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<MirResult> results = <MirResult>[
      for (final Scenario s in kScenarios) scoreMir(s.scores),
    ];
    final int passing = <int>[
      for (int i = 0; i < kScenarios.length; i++)
        if (results[i].global == kScenarios[i].expectedGlobal) i,
    ].length;

    Widget cell(Widget child, {Alignment align = Alignment.center}) => Container(
          height: 38,
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: child,
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Published scoring examples',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'The ten worked examples from the Global MIR scoring table, '
                  'scored live by this application. Select a scenario to load it '
                  'into the calculator.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Icon(
                      passing == kScenarios.length
                          ? Icons.check_circle
                          : Icons.error,
                      color: passing == kScenarios.length
                          ? const Color(0xFF2E7D32)
                          : scheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$passing of ${kScenarios.length} scenarios match the '
                      'published global rating',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header row.
                Container(
                  color: scheme.surfaceContainerHighest,
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 190,
                        child: cell(
                          Text('Domain',
                              style: theme.textTheme.labelLarge),
                          align: Alignment.centerLeft,
                        ),
                      ),
                      for (int i = 0; i < kScenarios.length; i++)
                        SizedBox(
                          width: 62,
                          child: cell(InkWell(
                            onTap: () => onLoad(kScenarios[i]),
                            child: Text('${i + 1}',
                                style: theme.textTheme.labelLarge),
                          )),
                        ),
                    ],
                  ),
                ),
                for (int d = 0; d < kDomains.length; d++)
                  Container(
                    decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: scheme.outlineVariant)),
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 190,
                          child: cell(
                            Text(kDomainsShort[d],
                                style: theme.textTheme.bodyMedium),
                            align: Alignment.centerLeft,
                          ),
                        ),
                        for (final Scenario s in kScenarios)
                          SizedBox(
                            width: 62,
                            child: cell(Text(
                              fmt(s.scores[d]),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: s.scores[d] > 0
                                    ? levelColor(s.scores[d], scheme)
                                    : scheme.onSurfaceVariant,
                                fontWeight: s.scores[d] > 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            )),
                          ),
                      ],
                    ),
                  ),
                // Global row.
                Container(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    border:
                        Border(top: BorderSide(color: scheme.outlineVariant)),
                  ),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 190,
                        child: cell(
                          Text('GLOBAL MIR',
                              style: theme.textTheme.labelLarge),
                          align: Alignment.centerLeft,
                        ),
                      ),
                      for (final MirResult r in results)
                        SizedBox(
                          width: 62,
                          child: cell(Text(fmt(r.global),
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700))),
                        ),
                    ],
                  ),
                ),
                // Sum row.
                Container(
                  decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: scheme.outlineVariant)),
                  ),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 190,
                        child: cell(
                          Text('Sum of domains',
                              style: theme.textTheme.bodyMedium),
                          align: Alignment.centerLeft,
                        ),
                      ),
                      for (final MirResult r in results)
                        SizedBox(
                          width: 62,
                          child: cell(Text(fmt(r.sum),
                              style: theme.textTheme.bodyMedium)),
                        ),
                    ],
                  ),
                ),
                // Rule row.
                Container(
                  decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: scheme.outlineVariant)),
                  ),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 190,
                        child: cell(
                          Text('Rule applied',
                              style: theme.textTheme.bodyMedium),
                          align: Alignment.centerLeft,
                        ),
                      ),
                      for (final MirResult r in results)
                        SizedBox(
                          width: 62,
                          child: cell(Text(r.rule.id,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant))),
                        ),
                    ],
                  ),
                ),
                // Match row.
                Container(
                  decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: scheme.outlineVariant)),
                  ),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 190,
                        child: cell(
                          Text('Matches published',
                              style: theme.textTheme.bodyMedium),
                          align: Alignment.centerLeft,
                        ),
                      ),
                      for (int i = 0; i < kScenarios.length; i++)
                        SizedBox(
                          width: 62,
                          child: cell(
                            results[i].global == kScenarios[i].expectedGlobal
                                ? const Icon(Icons.check,
                                    size: 18, color: Color(0xFF2E7D32))
                                : Icon(Icons.close,
                                    size: 18, color: scheme.error),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child:
                    Text('Load a scenario', style: theme.textTheme.titleMedium),
              ),
              for (int i = 0; i < kScenarios.length; i++)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Text('${i + 1}',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                  title: Text(kScenarios[i].name),
                  subtitle: Text(
                    'Global ${fmt(results[i].global)} - rule '
                    '${results[i].rule.id} - sum ${fmt(results[i].sum)}',
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => onLoad(kScenarios[i]),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'The published table labels scenario 2 as rule 3A; its maximum rating '
          'is 0.5, so the condition actually met is rule 2. Both give a global '
          'rating of 0.5.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Rules tab

class RulesTab extends StatelessWidget {
  const RulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    Widget rule(String id, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                padding: const EdgeInsets.symmetric(vertical: 3),
                margin: const EdgeInsets.only(right: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(id,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.onSecondaryContainer)),
              ),
              Expanded(
                  child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Rating levels', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    for (final double l in kLevels)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 46,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: levelColor(l, scheme),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(fmt(l),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 12),
                            Text(levelLabel(l),
                                style: theme.textTheme.bodyLarge),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Global rating rules',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    rule('1', 'If all domains are 0, the global MIR score is 0.'),
                    rule('2',
                        'If the maximum domain score is 0.5, the global MIR score is 0.5.'),
                    Text(
                      'If the maximum domain score is above 0.5 in any domain, '
                      'then the following applies:',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 14),
                    rule('3A',
                        'If the maximum domain score is 1 and all other domains are 0, the global MIR score is 0.5.'),
                    rule('3B',
                        'If the maximum domain score is 2 or 3 and all other domains are 0, the global MIR score is 1.'),
                    rule('3C',
                        'If the maximum domain score occurs only once, and there is another rating besides zero, the global MIR score is one level lower than the level corresponding to maximum impairment (maximum 3 gives 2, maximum 2 gives 1, maximum 1 gives 0.5).'),
                    rule('3D',
                        'If the maximum domain score occurs more than once (for example 1 in two domains, or 2 in two domains), the global MIR score is that maximum domain score.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Sum of domain ratings',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Alongside the global rating, the twelve domain ratings are '
                      'added together to give a continuous measure ranging from 0 '
                      '(all domains normal) to 36 (all twelve domains severe).',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Domains', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (int i = 0; i < kDomains.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('${i + 1}. ${kDomains[i]}',
                            style: theme.textTheme.bodyMedium),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- About tab

/// Intended use, disclaimer, privacy statement, licence and references.
class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    Widget section(String title, List<String> paragraphs,
            {IconData? icon, Widget? trailing}) =>
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final String p in paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(p,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                  ),
                ?trailing,
              ],
            ),
          ),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // Headline notice, deliberately the first thing on the page.
            Card(
              child: Container(
                color: scheme.errorContainer.withValues(alpha: 0.45),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.info_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Read before use',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: scheme.onErrorContainer),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Calculated scores must be re-checked and should not be '
                            'used alone to guide patient care, nor should they '
                            'substitute for clinical judgment. By using this '
                            'calculator you accept the terms set out on this page.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.45, color: scheme.onErrorContainer),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            section(
              'What this tool does',
              <String>[
                'The Global Multidomain Impairment Rating (Global MIR) summarises '
                    'impairment across twelve domains. This calculator applies the '
                    'published scoring rules to twelve domain ratings you enter and '
                    'reports two results: the global MIR rating, together with the '
                    'rule that produced it, and the straight sum of the twelve '
                    'domain ratings as a continuous measure.',
                'It is a reference aid for qualified clinicians and researchers, '
                    'and it is arithmetic only. It does not perform the assessment: '
                    'each domain rating must be assigned by a qualified examiner on '
                    'the basis of their own evaluation. The calculator does not '
                    'interpret a score, stage a condition, establish a diagnosis, '
                    'or recommend treatment.',
              ],
              icon: Icons.calculate_outlined,
            ),
            const SizedBox(height: 16),
            section(
              'Medical disclaimer',
              <String>[
                'This calculator is provided for reference and educational purposes '
                    'and is intended for use by qualified healthcare professionals. '
                    'It is not a medical device, and no output of it constitutes '
                    'medical advice, diagnosis, or treatment.',
                'Results should be independently verified before being recorded or '
                    'acted upon. They must not be used as the sole basis for any '
                    'clinical decision, and they do not replace the judgment of a '
                    'qualified clinician who has evaluated the patient. Anyone '
                    'seeking advice about their own health should consult a '
                    'qualified healthcare provider.',
                'Responsibility for how a result is used, and for confirming that '
                    'the scoring rules implemented here match the version of the '
                    'instrument in use, rests with the user.',
              ],
              icon: Icons.medical_information_outlined,
            ),
            const SizedBox(height: 16),
            section(
              'Privacy: nothing leaves your browser',
              <String>[
                'Every rating is held in memory and every calculation runs locally '
                    'in your browser. Ratings are not transmitted to any server, '
                    'logged, or stored, and they are discarded when you close or '
                    'reload the page. There are no accounts and the application '
                    'sets no cookies and runs no analytics or tracking.',
                'To keep a record of a result, use the copy button in the toolbar '
                    'and paste the summary wherever you keep your notes. Whatever '
                    'you paste, and any hosting or clipboard behaviour of your own '
                    'device, is outside the control of this application.',
              ],
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 16),
            section(
              'No warranty',
              <String>[
                'This software is provided "as is", without warranty of any kind, '
                    'express or implied, including but not limited to the '
                    'warranties of merchantability, fitness for a particular '
                    'purpose, and non-infringement. In no event shall the authors '
                    'or copyright holders be liable for any claim, damages, or '
                    'other liability arising from, out of, or in connection with '
                    'the software or its use.',
                'The software is released under the MIT Licence, '
                    'Copyright (c) 2026 James Foster. The full licence text ships '
                    'with the source repository.',
              ],
              icon: Icons.gavel_outlined,
            ),
            const SizedBox(height: 16),
            section(
              'References',
              <String>[
                'TODO: add the citation for the Global MIR instrument and its '
                    'scoring rules (authors, title, journal, year, DOI).',
                'The scoring rules as implemented, and the ten published worked '
                    'examples used to verify them, are shown on the Rules and '
                    'Examples tabs. The published example table labels scenario 2 '
                    'as rule 3A; because its maximum rating is 0.5 the condition '
                    'actually met is rule 2. Both yield a global rating of 0.5, so '
                    'every published global rating is reproduced.',
              ],
              icon: Icons.menu_book_outlined,
            ),
            const SizedBox(height: 16),
            section(
              'Version and source',
              <String>[
                'Global MIR Calculator version $kAppVersion. The source code, '
                    'licence, and issue tracker are at $kSourceUrl. Copied score '
                    'summaries include the version number so a recorded result can '
                    'be traced to the code that produced it.',
              ],
              icon: Icons.code,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
