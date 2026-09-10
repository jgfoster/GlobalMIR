/// Global MIR scoring engine.
///
/// Twelve domains are each rated on the ordinal ladder
/// 0 / 0.5 / 1 / 2 / 3, and a single global rating is derived from the
/// pattern of those ratings by the published rule set (rules 1, 2, 3A-3D).
library;

/// The twelve MIR domains, in canonical order.
const List<String> kDomains = <String>[
  'Memory',
  'Orientation',
  'Judgment and Problem Solving',
  'Concentration and Multitasking',
  'Visuospatial Functioning',
  'Behavior, Comportment and Personality',
  'Psychiatric Symptoms',
  'Language',
  'Motor/Other',
  'Community Life',
  'Home Life',
  'Basic Activities of Daily Living (ADLs)',
];

/// Short labels, useful for compact layouts and the scenario matrix.
const List<String> kDomainsShort = <String>[
  'Memory',
  'Orientation',
  'Judgment',
  'Concentration',
  'Visuospatial',
  'Behavior',
  'Psychiatric',
  'Language',
  'Motor/Other',
  'Community',
  'Home Life',
  'Basic ADLs',
];

/// The ordinal ladder of legal ratings, ascending.
const List<double> kLevels = <double>[0, 0.5, 1, 2, 3];

/// Human-readable anchor for each rating level.
String levelLabel(double v) => switch (v) {
      0 => 'normal / no changes',
      0.5 => 'subtle / questionable',
      1 => 'mild but definite',
      2 => 'moderate',
      3 => 'severe',
      _ => '',
    };

/// Formats a rating without a trailing `.0` (0.5 stays 0.5).
String fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Which rule produced a global rating.
enum MirRule {
  allZero('1', 'All domains are 0.'),
  maxIsHalf('2', 'The maximum domain score is 0.5.'),
  singleMild('3A', 'The maximum domain score is 1 and all other domains are 0.'),
  singleSevere(
      '3B', 'The maximum domain score is 2 or 3 and all other domains are 0.'),
  uniqueMaxWithOthers('3C',
      'The maximum domain score occurs only once and there is another rating besides zero, so the global rating drops one level.'),
  repeatedMax('3D',
      'The maximum domain score occurs in more than one domain, so the global rating equals that maximum.');

  const MirRule(this.id, this.description);

  /// Rule identifier as printed in the scoring guide ("1", "2", "3A"...).
  final String id;

  /// Plain-language statement of the condition that fired.
  final String description;
}

/// The outcome of scoring one set of twelve domain ratings.
class MirResult {
  const MirResult({
    required this.global,
    required this.rule,
    required this.sum,
    required this.max,
    required this.maxCount,
    required this.nonZeroCount,
    required this.maxDomains,
  });

  /// The global MIR rating (0, 0.5, 1, 2 or 3).
  final double global;

  /// The rule that determined [global].
  final MirRule rule;

  /// Straight sum of all twelve domain ratings (the continuous measure).
  final double sum;

  /// Highest single domain rating.
  final double max;

  /// How many domains carry [max].
  final int maxCount;

  /// How many domains are rated above 0.
  final int nonZeroCount;

  /// Indices into [kDomains] of the domains carrying [max]; empty if all zero.
  final List<int> maxDomains;
}

/// Returns the rating one level below [v] on the ordinal ladder.
double oneLevelLower(double v) {
  final int i = kLevels.indexOf(v);
  if (i <= 0) return kLevels.first;
  return kLevels[i - 1];
}

/// Scores twelve domain ratings into a global MIR rating.
///
/// Throws [ArgumentError] if [scores] is not twelve ratings drawn from
/// [kLevels].
MirResult scoreMir(List<double> scores) {
  if (scores.length != kDomains.length) {
    throw ArgumentError.value(
        scores.length, 'scores', 'expected ${kDomains.length} domain ratings');
  }
  for (final double s in scores) {
    if (!kLevels.contains(s)) {
      throw ArgumentError.value(s, 'scores', 'not a legal MIR rating');
    }
  }

  final double sum = scores.fold<double>(0, (double a, double b) => a + b);
  final double max = scores.reduce((double a, double b) => a > b ? a : b);
  final List<int> maxDomains = <int>[
    for (int i = 0; i < scores.length; i++)
      if (max > 0 && scores[i] == max) i,
  ];
  final int maxCount = maxDomains.length;
  final int nonZeroCount = scores.where((double s) => s > 0).length;

  final double global;
  final MirRule rule;

  if (max == 0) {
    // Rule 1.
    global = 0;
    rule = MirRule.allZero;
  } else if (max == 0.5) {
    // Rule 2.
    global = 0.5;
    rule = MirRule.maxIsHalf;
  } else if (nonZeroCount == 1) {
    // Rule 3A / 3B: a lone elevated domain, everything else normal.
    if (max == 1) {
      global = 0.5;
      rule = MirRule.singleMild;
    } else {
      global = 1;
      rule = MirRule.singleSevere;
    }
  } else if (maxCount == 1) {
    // Rule 3C: unique maximum alongside other non-zero domains.
    global = oneLevelLower(max);
    rule = MirRule.uniqueMaxWithOthers;
  } else {
    // Rule 3D: the maximum repeats.
    global = max;
    rule = MirRule.repeatedMax;
  }

  return MirResult(
    global: global,
    rule: rule,
    sum: sum,
    max: max,
    maxCount: maxCount,
    nonZeroCount: nonZeroCount,
    maxDomains: maxDomains,
  );
}

/// A worked example from the published "Global MIR Scoring Examples" table.
class Scenario {
  const Scenario({
    required this.name,
    required this.scores,
    required this.expectedGlobal,
    required this.expectedRule,
  });

  final String name;
  final List<double> scores;
  final double expectedGlobal;

  /// Rule id as printed in the published table.
  final String expectedRule;
}

/// The ten published scenarios, in table order.
///
/// Domain order matches [kDomains].
const List<Scenario> kScenarios = <Scenario>[
  Scenario(
    name: 'Scenario 1',
    scores: <double>[0, 0, 0, 0, 0, 0.5, 0, 0, 0, 0, 0, 0],
    expectedGlobal: 0.5,
    expectedRule: '2',
  ),
  Scenario(
    name: 'Scenario 2',
    scores: <double>[0, 0, 0, 0, 0, 0, 0, 0, 0.5, 0, 0, 0],
    expectedGlobal: 0.5,
    // The published table labels this 3A; the condition actually met is
    // rule 2 (maximum is 0.5). Both yield a global rating of 0.5.
    expectedRule: '2',
  ),
  Scenario(
    name: 'Scenario 3',
    scores: <double>[0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0],
    expectedGlobal: 1,
    expectedRule: '3B',
  ),
  Scenario(
    name: 'Scenario 4',
    scores: <double>[0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0],
    expectedGlobal: 1,
    expectedRule: '3B',
  ),
  Scenario(
    name: 'Scenario 5',
    scores: <double>[1, 0, 0.5, 0, 0, 0, 0, 2, 0.5, 0, 1, 0],
    expectedGlobal: 1,
    expectedRule: '3C',
  ),
  Scenario(
    name: 'Scenario 6',
    scores: <double>[0, 0, 1, 1, 0, 2, 0, 1, 1, 1, 0, 0],
    expectedGlobal: 1,
    expectedRule: '3C',
  ),
  Scenario(
    name: 'Scenario 7',
    scores: <double>[0, 0, 0, 0.5, 0, 1, 0.5, 0.5, 0.5, 0.5, 0.5, 0],
    expectedGlobal: 0.5,
    expectedRule: '3C',
  ),
  Scenario(
    name: 'Scenario 8',
    scores: <double>[0, 0, 2, 1, 0, 2, 1, 0, 1, 0, 0, 0],
    expectedGlobal: 2,
    expectedRule: '3D',
  ),
  Scenario(
    name: 'Scenario 9',
    scores: <double>[2, 0.5, 0.5, 1, 0, 2, 1, 0, 1, 0.5, 0.5, 1],
    expectedGlobal: 2,
    expectedRule: '3D',
  ),
  Scenario(
    name: 'Scenario 10',
    scores: <double>[1, 1, 3, 2, 0.5, 3, 2, 1, 1, 1, 1, 1],
    expectedGlobal: 3,
    expectedRule: '3D',
  ),
];
