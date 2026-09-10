import 'package:flutter_test/flutter_test.dart';
import 'package:global_mir/scoring.dart';

void main() {
  group('published scenario table', () {
    for (final Scenario s in kScenarios) {
      test('${s.name} -> global ${fmt(s.expectedGlobal)} (rule ${s.expectedRule})',
          () {
        final MirResult r = scoreMir(s.scores);
        expect(r.global, s.expectedGlobal);
        expect(r.rule.id, s.expectedRule);
      });
    }

    test('straight sums of each scenario column', () {
      const List<double> expected = <double>[
        0.5, 0.5, 2, 3, 5, 7, 4, 7, 10, 17.5,
      ];
      for (int i = 0; i < kScenarios.length; i++) {
        expect(scoreMir(kScenarios[i].scores).sum, expected[i],
            reason: kScenarios[i].name);
      }
    });
  });

  List<double> ratings(Map<int, double> overrides) => <double>[
        for (int i = 0; i < kDomains.length; i++) overrides[i] ?? 0,
      ];

  group('rule 1 - all zero', () {
    test('all domains 0 gives 0', () {
      final MirResult r = scoreMir(ratings(<int, double>{}));
      expect(r.global, 0);
      expect(r.rule, MirRule.allZero);
      expect(r.sum, 0);
      expect(r.maxDomains, isEmpty);
    });
  });

  group('rule 2 - maximum is 0.5', () {
    test('single 0.5 gives 0.5', () {
      expect(scoreMir(ratings(<int, double>{0: 0.5})).rule, MirRule.maxIsHalf);
    });

    test('every domain 0.5 still gives 0.5', () {
      final MirResult r = scoreMir(List<double>.filled(kDomains.length, 0.5));
      expect(r.global, 0.5);
      expect(r.rule, MirRule.maxIsHalf);
      expect(r.sum, 6);
    });
  });

  group('rule 3A - lone 1', () {
    test('single 1 with all others 0 gives 0.5', () {
      final MirResult r = scoreMir(ratings(<int, double>{6: 1}));
      expect(r.global, 0.5);
      expect(r.rule, MirRule.singleMild);
    });
  });

  group('rule 3B - lone 2 or 3', () {
    test('single 2 with all others 0 gives 1', () {
      final MirResult r = scoreMir(ratings(<int, double>{4: 2}));
      expect(r.global, 1);
      expect(r.rule, MirRule.singleSevere);
    });

    test('single 3 with all others 0 gives 1', () {
      final MirResult r = scoreMir(ratings(<int, double>{11: 3}));
      expect(r.global, 1);
      expect(r.rule, MirRule.singleSevere);
    });
  });

  group('rule 3C - unique maximum with other non-zero domains', () {
    test('max 1 plus a 0.5 gives 0.5', () {
      final MirResult r = scoreMir(ratings(<int, double>{0: 1, 1: 0.5}));
      expect(r.global, 0.5);
      expect(r.rule, MirRule.uniqueMaxWithOthers);
    });

    test('max 2 plus a 0.5 gives 1', () {
      final MirResult r = scoreMir(ratings(<int, double>{0: 2, 1: 0.5}));
      expect(r.global, 1);
      expect(r.rule, MirRule.uniqueMaxWithOthers);
    });

    test('max 3 plus a 1 gives 2', () {
      final MirResult r = scoreMir(ratings(<int, double>{0: 3, 5: 1}));
      expect(r.global, 2);
      expect(r.rule, MirRule.uniqueMaxWithOthers);
    });

    test('a 0.5 elsewhere is enough to demote a lone 3 from rule 3B', () {
      expect(scoreMir(ratings(<int, double>{7: 3})).global, 1);
      expect(scoreMir(ratings(<int, double>{7: 3, 8: 0.5})).global, 2);
    });
  });

  group('rule 3D - repeated maximum', () {
    test('two 1s give 1', () {
      final MirResult r = scoreMir(ratings(<int, double>{0: 1, 1: 1}));
      expect(r.global, 1);
      expect(r.rule, MirRule.repeatedMax);
      expect(r.maxCount, 2);
    });

    test('two 2s give 2 even with lower ratings present', () {
      final MirResult r =
          scoreMir(ratings(<int, double>{0: 2, 1: 2, 2: 1, 3: 0.5}));
      expect(r.global, 2);
      expect(r.rule, MirRule.repeatedMax);
    });

    test('two 3s give 3', () {
      expect(scoreMir(ratings(<int, double>{0: 3, 1: 3})).global, 3);
    });

    test('all domains 3 gives 3 and a sum of 36', () {
      final MirResult r = scoreMir(List<double>.filled(kDomains.length, 3));
      expect(r.global, 3);
      expect(r.rule, MirRule.repeatedMax);
      expect(r.sum, 36);
      expect(r.maxCount, 12);
    });
  });

  group('derived statistics', () {
    test('max, counts and domain indices are reported', () {
      final MirResult r =
          scoreMir(ratings(<int, double>{0: 2, 5: 2, 8: 1, 9: 0.5}));
      expect(r.max, 2);
      expect(r.maxCount, 2);
      expect(r.nonZeroCount, 4);
      expect(r.maxDomains, <int>[0, 5]);
      expect(r.sum, 5.5);
    });

    test('oneLevelLower walks the ordinal ladder', () {
      expect(oneLevelLower(3), 2);
      expect(oneLevelLower(2), 1);
      expect(oneLevelLower(1), 0.5);
      expect(oneLevelLower(0.5), 0);
      expect(oneLevelLower(0), 0);
    });
  });

  group('input validation', () {
    test('rejects the wrong number of domains', () {
      expect(() => scoreMir(<double>[0, 0, 0]), throwsArgumentError);
    });

    test('rejects ratings off the ladder', () {
      expect(() => scoreMir(ratings(<int, double>{0: 1.5})), throwsArgumentError);
      expect(() => scoreMir(ratings(<int, double>{0: 4})), throwsArgumentError);
    });
  });

  group('domain metadata', () {
    test('twelve domains with matching short labels and anchors', () {
      expect(kDomains, hasLength(12));
      expect(kDomainsShort, hasLength(12));
      expect(kLevels, <double>[0, 0.5, 1, 2, 3]);
      for (final double l in kLevels) {
        expect(levelLabel(l), isNotEmpty);
      }
    });

    test('fmt drops trailing zeros but keeps halves', () {
      expect(fmt(0), '0');
      expect(fmt(0.5), '0.5');
      expect(fmt(3), '3');
      expect(fmt(17.5), '17.5');
    });
  });
}
