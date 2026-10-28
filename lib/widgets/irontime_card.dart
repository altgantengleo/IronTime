import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../state/fit_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// IronTime extras for the workout-complete screen:
/// a rough calorie / fat-equivalent guess and a richer streak summary.
class IronTimeInsightCard extends StatelessWidget {
  const IronTimeInsightCard({super.key, required this.sets});

  final int sets;

  static const _milestones = [3, 7, 14, 30, 50, 100, 200, 365];

  static DateTime _day(DateTime x) => DateTime(x.year, x.month, x.day);

  // Rough guess: MET from session density, net of resting energy.
  static ({int kcal, double fatG})? _burn() {
    if (fit.sessions.isEmpty) return null;
    final s = fit.sessions.last;
    final minutes = s.durationSec / 60;
    if (minutes < 5 || s.setCount == 0) return null;
    final perMin = s.setCount / minutes;
    final met = (3.5 + (perMin - 0.15) / 0.30 * 2.5).clamp(3.5, 6.0).toDouble();
    final kg = fit.latestBodyweight?.kg ?? fit.profile.weightKg;
    final body = kg > 0 ? kg : 75.0;
    final active = (met - 1) * body * minutes / 60;
    return (kcal: active.round(), fatG: active / 7.7);
  }

  static Set<DateTime> _activeDays() {
    final out = <DateTime>{};
    for (final s in fit.sessions) {
      out.add(_day(s.day));
    }
    for (final id in fit.checkins) {
      final p = id.split('-');
      if (p.length != 3) continue;
      final y = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final d = int.tryParse(p[2]);
      if (y != null && m != null && d != null) out.add(DateTime(y, m, d));
    }
    return out;
  }

  // Same rules as the app's streak: planned rest days neither add nor break.
  static int _bestStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final first = days.reduce((a, b) => a.isBefore(b) ? a : b);
    final today = _day(DateTime.now());
    bool rest(DateTime d) => fit.weeklyPlan.isNotEmpty && !fit.weeklyPlan.containsKey(d.weekday);
    var run = 0;
    var best = 0;
    for (var d = first; !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1)) {
      if (days.contains(d)) {
        run++;
        if (run > best) best = run;
      } else if (!rest(d) && d != today) {
        run = 0;
      }
    }
    return best;
  }

  static int? _nextMilestone(int current) {
    for (final m in _milestones) {
      if (m > current) return m;
    }
    return null;
  }

  static String _tier(int s) {
    if (s >= 100) return 'Inferno';
    if (s >= 30) return 'Blaze';
    if (s >= 7) return 'Flame';
    if (s >= 3) return 'Spark';
    return 'Ember';
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final burn = sets > 0 ? _burn() : null;
    final current = fit.currentStreak;
    final best = math.max(_bestStreak(_activeDays()), current);
    final next = _nextMilestone(current);

    final label = AppTheme.f(10.5, weight: FontWeight.w700, color: gc.accent, letterSpacing: 1.4);
    final small = AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary, height: 1.35);

    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (burn != null) ...[
            Text('ESTIMATED BURN', style: label),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('≈ ${fit.energyOf(burn.kcal)} ${fit.energyUnit}',
                    style: AppTheme.f(26, weight: FontWeight.w800, color: gc.text)),
                const Spacer(),
                Text('≈ ${burn.fatG.round()} g fat equivalent',
                    style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            Text('A rough guess from time, effort and your body weight. Not a measurement.', style: small),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Icon(PhosphorIconsFill.fire, size: 18, color: gc.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$current-day streak · ${_tier(current)}',
                    style: AppTheme.f(15, weight: FontWeight.w700, color: gc.text)),
              ),
              Text('Best $best', style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.textSecondary)),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: current / next,
                minHeight: 6,
                backgroundColor: gc.bgRaised2,
                color: gc.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text('${next - current} more ${next - current == 1 ? 'day' : 'days'} to a $next-day streak', style: small),
          ],
        ],
      ),
    );
  }
}
