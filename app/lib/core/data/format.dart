import 'package:intl/intl.dart';

import 'enums.dart';
import 'models.dart';

/// "₹12–18 L / year", "$40–50 / hour", "€55k / year", or null when no salary.
/// Every salary shows its period, so mistakes like "$18–22 /yr" for an hourly
/// wage are visible at a glance.
String? formatSalary(Job job) => formatMoney(
  job.salaryMin,
  job.salaryMax,
  job.salaryCurrency,
  job.salaryPeriod,
);

/// Shared by job salaries and offers: a range (or single amount) with its
/// currency symbol and period; null when there is no amount.
String? formatMoney(
  double? lo,
  double? hi,
  String? currency,
  SalaryPeriod? salaryPeriod,
) {
  if (lo == null && hi == null) return null;
  final cur = currency ?? '';
  final symbol = switch (cur) {
    'INR' => '₹',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$cur ',
  };
  String amount(double v) {
    if (cur == 'INR' && v >= 100000) {
      final lakhs = v / 100000;
      return '${_trim(lakhs)} L';
    }
    if (v >= 1000) return '${_trim(v / 1000)}k';
    return _trim(v);
  }

  final range = switch ((lo, hi)) {
    (final a?, final b?) when a != b =>
      '$symbol${_stripUnit(amount(a), amount(b))}–${amount(b)}',
    (final a?, _) => '$symbol${amount(a)}${hi == null ? '+' : ''}',
    (_, final b?) => 'Up to $symbol${amount(b)}',
    _ => '',
  };
  final period = salaryPeriod?.label;
  return period == null ? range : '$range / $period';
}

// "12 L–18 L" reads better as "12–18 L" when both ends share a unit.
String _stripUnit(String lo, String hi) {
  for (final unit in const [' L', 'k']) {
    if (lo.endsWith(unit) && hi.endsWith(unit)) {
      return lo.substring(0, lo.length - unit.length);
    }
  }
  return lo;
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// A name as people write it: "JESWIN BENEDICT" (typed with caps lock, or
/// copied from a form) becomes "Jeswin Benedict". Mixed case is kept as
/// typed ("McKenzie", "de Souza").
String friendlyName(String name) {
  final trimmed = name.trim();
  if (trimmed.toUpperCase() != trimmed || trimmed.toLowerCase() == trimmed) {
    return trimmed;
  }
  return trimmed
      .split(RegExp(r'\s+'))
      .map((w) => w.length <= 1 ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');
}

/// "Just now", "5 min ago", "3 h ago", "2 days ago", then "12 Oct 2026".
String formatRelative(DateTime when, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(when);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return d.inDays == 1 ? 'Yesterday' : '${d.inDays} days ago';
  return DateFormat('d MMM y').format(when.toLocal());
}

/// "Bengaluru, IN · Hybrid".
String formatPlace(Job job) {
  final location = job.location ?? '';
  // "Remote (Worldwide)" already says remote; don't repeat it.
  final saysWorkplace = location.toLowerCase().contains(
    job.workplace.label.toLowerCase(),
  );
  final parts = [
    if (location.isNotEmpty) location,
    if ((job.workplace != WorkplaceType.onsite || location.isEmpty) &&
        !saysWorkplace)
      job.workplace.label,
  ];
  return parts.join(' · ');
}

/// Attribution for external job providers (their terms ask to name and link
/// them on every listing): display label and home page.
({String label, String name, String url})? jobSource(String? id) =>
    switch (id) {
      'remotive' => (
        label: 'via Remotive',
        name: 'Remotive',
        url: 'https://remotive.com',
      ),
      'adzuna' => (
        label: 'Jobs by Adzuna',
        name: 'Adzuna',
        url: 'https://www.adzuna.in',
      ),
      'himalayas' => (
        label: 'via Himalayas',
        name: 'Himalayas',
        url: 'https://himalayas.app',
      ),
      'jobicy' => (
        label: 'via Jobicy',
        name: 'Jobicy',
        url: 'https://jobicy.com',
      ),
      'remoteok' => (
        label: 'via Remote OK',
        name: 'Remote OK',
        url: 'https://remoteok.com',
      ),
      // The company's own careers board (an applicant-tracking system).
      'greenhouse' || 'lever' || 'ashby' => (
        label: 'From the company careers page',
        name: 'company site',
        url: '',
      ),
      null || '' => null,
      final other => (label: 'via $other', name: other, url: ''),
    };
