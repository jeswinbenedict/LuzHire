import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/failures.dart';
import 'package:luzhire/core/data/format.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/features/jobs/data/jobs_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads `create type public.<name> as enum (...)` values from the migration.
Map<String, List<String>> sqlEnums() {
  final sql = File('../supabase/migrations/20261018120000_foundation.sql')
      .readAsStringSync();
  final re = RegExp(
    r"create type public\.(\w+)\s+as enum \(([^)]*)\)",
    multiLine: true,
  );
  return {
    for (final m in re.allMatches(sql))
      m.group(1)!: RegExp(r"'([^']+)'")
          .allMatches(m.group(2)!)
          .map((e) => e.group(1)!)
          .toList(),
  };
}

Json jobRow({Map<String, Object?> overrides = const {}}) => {
  'id': '00000000-0000-4000-b000-000000000001',
  'slug': 'flutter-developer-00000001',
  'title': 'Flutter Developer',
  'company_name': 'Northwind Labs',
  'company_id': '00000000-0000-4000-a000-000000000008',
  'source': 'native',
  'employment_type': 'full_time',
  'experience_level': 'mid',
  'workplace': 'hybrid',
  'location_text': 'Bengaluru, IN',
  'salary_min': 1200000,
  'salary_max': 1800000,
  'salary_currency': 'INR',
  'salary_period': 'year',
  'responsibilities': ['Build features'],
  'qualifications': <String>[],
  'benefits': ['Health insurance'],
  'status': 'published',
  'deadline': null,
  'application_count': 3,
  'published_at': '2026-10-18T09:00:00+00:00',
  ...overrides,
};

void main() {
  group('Dart enums mirror the Postgres enums', () {
    final sql = sqlEnums();
    void same(String type, List<DbEnum> dart) => test(type, () {
      expect(sql[type], isNotNull, reason: 'enum $type not found in SQL');
      expect([for (final v in dart) v.dbValue], sql[type]);
    });
    same('app_role', AppRole.values);
    same('job_status', JobStatus.values);
    same('employment_type', EmploymentType.values);
    same('experience_level', ExperienceLevel.values);
    same('workplace_type', WorkplaceType.values);
    same('salary_period', SalaryPeriod.values);
    same('application_stage', ApplicationStage.values);
    same('verification', Verification.values);
    same('interview_mode', InterviewMode.values);
    same('interview_status', InterviewStatus.values);
    same('offer_status', OfferStatus.values);
  });

  group('Job', () {
    test('parses a database row', () {
      final job = Job.fromJson(jobRow());
      expect(job.title, 'Flutter Developer');
      expect(job.employmentType, EmploymentType.fullTime);
      expect(job.workplace, WorkplaceType.hybrid);
      expect(job.salaryPeriod, SalaryPeriod.year);
      expect(job.isExternal, isFalse);
      expect(job.publishedAt, DateTime.utc(2026, 10, 18, 9));
    });

    test('salary always shows its period', () {
      expect(formatSalary(Job.fromJson(jobRow())), '₹12–18 L / year');
      expect(
        formatSalary(
          Job.fromJson(
            jobRow(
              overrides: {
                'salary_min': 40,
                'salary_max': 50,
                'salary_currency': 'USD',
                'salary_period': 'hour',
              },
            ),
          ),
        ),
        r'$40–50 / hour',
      );
      expect(
        formatSalary(
          Job.fromJson(
            jobRow(
              overrides: {
                'salary_min': 55000,
                'salary_max': null,
                'salary_currency': 'EUR',
              },
            ),
          ),
        ),
        '€55k+ / year',
      );
      expect(
        formatSalary(
          Job.fromJson(
            jobRow(overrides: {'salary_min': null, 'salary_max': null}),
          ),
        ),
        isNull,
      );
    });

    test('place combines city and workplace', () {
      expect(formatPlace(Job.fromJson(jobRow())), 'Bengaluru, IN · Hybrid');
      expect(
        formatPlace(Job.fromJson(jobRow(overrides: {'workplace': 'onsite'}))),
        'Bengaluru, IN',
      );
    });
  });

  test('relative time', () {
    final now = DateTime(2026, 10, 18, 12);
    expect(
      formatRelative(now.subtract(const Duration(seconds: 20)), now: now),
      'Just now',
    );
    expect(
      formatRelative(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(
      formatRelative(now.subtract(const Duration(hours: 3)), now: now),
      '3 h ago',
    );
    expect(
      formatRelative(now.subtract(const Duration(days: 1)), now: now),
      'Yesterday',
    );
    expect(formatRelative(DateTime(2026, 9, 1), now: now), '1 Sep 2026');
  });

  group('JobSearchQuery', () {
    const query = JobSearchQuery(
      keyword: ' flutter ',
      remoteOnly: true,
      types: {EmploymentType.fullTime, EmploymentType.internship},
      minAnnualSalary: 600000,
      skills: {'dart'},
    );

    test('maps to search_jobs RPC parameters', () {
      final p = query.toRpcParams();
      expect(p['q'], 'flutter');
      expect(p['remote_only'], isTrue);
      expect(p['types'], containsAll(['full_time', 'internship']));
      expect(p['min_annual_salary'], 600000);
      expect(p['skill_slugs'], ['dart']);
      expect(p.containsKey('location'), isFalse);
      expect(p['page_size'], 20);
    });

    test('adds a keyset cursor for the next page', () {
      final last = Job.fromJson(jobRow());
      final p = query.toRpcParams(after: last);
      expect(p['after_id'], last.id);
      expect(p['after_published'], '2026-10-18T09:00:00.000Z');
    });

    test('round-trips through shareable URL parameters', () {
      final back = JobSearchQuery.fromUrlParams(query.toUrlParams());
      expect(back, query.copyWith(keyword: 'flutter'));
    });
  });

  group('database errors become readable messages', () {
    test('duplicate application', () {
      final f = mapDbError(
        const PostgrestException(message: 'dup', code: '23505'),
      );
      expect(f.message, contains('already applied'));
    });
    test('business rules pass through the trigger message', () {
      final f = mapDbError(
        const PostgrestException(
          message: 'The application deadline has passed',
          code: '23514',
        ),
      );
      expect(f.message, 'The application deadline has passed');
    });
    test('permission', () {
      final f = mapDbError(
        const PostgrestException(message: 'rls', code: '42501'),
      );
      expect(f.message, "You don't have permission to do that.");
    });
  });
}
