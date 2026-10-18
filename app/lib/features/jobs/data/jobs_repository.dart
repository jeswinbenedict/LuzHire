import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';

/// Filters for the public job search (FR-05). Maps 1:1 to the
/// `public.search_jobs` RPC parameters.
@immutable
class JobSearchQuery {
  const JobSearchQuery({
    this.keyword = '',
    this.location = '',
    this.remoteOnly = false,
    this.types = const {},
    this.levels = const {},
    this.minAnnualSalary,
    this.skills = const {},
    this.postedWithinDays,
    this.companyId,
    this.pageSize = 20,
  });

  final String keyword;
  final String location;
  final bool remoteOnly;
  final Set<EmploymentType> types;
  final Set<ExperienceLevel> levels;
  final num? minAnnualSalary;
  final Set<String> skills; // skill slugs
  final int? postedWithinDays;
  final String? companyId;
  final int pageSize;

  JobSearchQuery copyWith({
    String? keyword,
    String? location,
    bool? remoteOnly,
    Set<EmploymentType>? types,
    Set<ExperienceLevel>? levels,
    num? minAnnualSalary,
    Set<String>? skills,
    int? postedWithinDays,
  }) => JobSearchQuery(
    keyword: keyword ?? this.keyword,
    location: location ?? this.location,
    remoteOnly: remoteOnly ?? this.remoteOnly,
    types: types ?? this.types,
    levels: levels ?? this.levels,
    minAnnualSalary: minAnnualSalary ?? this.minAnnualSalary,
    skills: skills ?? this.skills,
    postedWithinDays: postedWithinDays ?? this.postedWithinDays,
    companyId: companyId,
    pageSize: pageSize,
  );

  /// Parameters for `search_jobs`, with [after] as the keyset cursor.
  Map<String, dynamic> toRpcParams({Job? after}) => {
    if (keyword.trim().isNotEmpty) 'q': keyword.trim(),
    if (location.trim().isNotEmpty) 'location': location.trim(),
    if (remoteOnly) 'remote_only': true,
    if (types.isNotEmpty) 'types': [for (final t in types) t.dbValue],
    if (levels.isNotEmpty) 'levels': [for (final l in levels) l.dbValue],
    'min_annual_salary': ?minAnnualSalary,
    if (skills.isNotEmpty) 'skill_slugs': skills.toList(),
    'posted_within_days': ?postedWithinDays,
    'company': ?companyId,
    if (after != null) ...{
      'after_published': after.publishedAt?.toUtc().toIso8601String(),
      'after_id': after.id,
    },
    'page_size': pageSize,
  };

  /// Shareable URL query (`/jobs?q=flutter&remote=1`).
  Map<String, String> toUrlParams() => {
    if (keyword.trim().isNotEmpty) 'q': keyword.trim(),
    if (location.trim().isNotEmpty) 'location': location.trim(),
    if (remoteOnly) 'remote': '1',
    if (types.isNotEmpty) 'type': types.map((t) => t.dbValue).join(','),
    if (levels.isNotEmpty) 'level': levels.map((l) => l.dbValue).join(','),
    if (minAnnualSalary != null) 'salary': '${minAnnualSalary!.round()}',
    if (skills.isNotEmpty) 'skills': skills.join(','),
    if (postedWithinDays != null) 'days': '$postedWithinDays',
  };

  factory JobSearchQuery.fromUrlParams(Map<String, String> p) {
    Set<T> parse<T extends DbEnum>(String? raw, List<T> all) => {
      for (final v in (raw ?? '').split(','))
        ...all.where((e) => e.dbValue == v),
    };
    return JobSearchQuery(
      keyword: p['q'] ?? '',
      location: p['location'] ?? '',
      remoteOnly: p['remote'] == '1',
      types: parse(p['type'], EmploymentType.values),
      levels: parse(p['level'], ExperienceLevel.values),
      minAnnualSalary: num.tryParse(p['salary'] ?? ''),
      skills: {
        for (final s in (p['skills'] ?? '').split(','))
          if (s.isNotEmpty) s,
      },
      postedWithinDays: int.tryParse(p['days'] ?? ''),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is JobSearchQuery &&
      other.keyword == keyword &&
      other.location == location &&
      other.remoteOnly == remoteOnly &&
      setEquals(other.types, types) &&
      setEquals(other.levels, levels) &&
      other.minAnnualSalary == minAnnualSalary &&
      setEquals(other.skills, skills) &&
      other.postedWithinDays == postedWithinDays &&
      other.companyId == companyId &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(
    keyword,
    location,
    remoteOnly,
    Object.hashAllUnordered(types),
    Object.hashAllUnordered(levels),
    minAnnualSalary,
    Object.hashAllUnordered(skills),
    postedWithinDays,
    companyId,
    pageSize,
  );
}

class JobsRepository {
  JobsRepository(this._db);
  final SupabaseClient _db;

  /// One page of results; pass the last job of the previous page as [after].
  Future<List<Job>> search(JobSearchQuery query, {Job? after}) =>
      guardDb(() async {
        final rows = await _db.rpc<List<dynamic>>(
          'search_jobs',
          params: query.toRpcParams(after: after),
        );
        return [for (final r in rows) Job.fromJson((r as Map).cast())];
      });

  Future<Job?> bySlug(String slug) => guardDb(() async {
    final row = await _db.from('jobs').select().eq('slug', slug).maybeSingle();
    return row == null ? null : Job.fromJson(row);
  });

  Future<List<({String slug, String name})>> skills() => guardDb(() async {
    final rows = await _db.from('skills').select('slug, name').order('name');
    return [
      for (final r in rows)
        (slug: r['slug'] as String, name: r['name'] as String),
    ];
  });
}

class SavedJobsRepository {
  SavedJobsRepository(this._db);
  final SupabaseClient _db;

  /// Live set of saved job ids for [userId] (synced across devices, FR-07).
  Stream<Set<String>> watchIds(String userId) => _db
      .from('saved_jobs')
      .stream(primaryKey: ['user_id', 'job_id'])
      .eq('user_id', userId)
      .map((rows) => {for (final r in rows) r['job_id'] as String});

  Future<void> save(String userId, String jobId) => guardDb(
    () => _db.from('saved_jobs').upsert({'user_id': userId, 'job_id': jobId}),
  );

  Future<void> remove(String userId, String jobId) => guardDb(
    () => _db.from('saved_jobs').delete().match({
      'user_id': userId,
      'job_id': jobId,
    }),
  );
}

final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => JobsRepository(ref.watch(supabaseClientProvider)),
);

final savedJobsRepositoryProvider = Provider<SavedJobsRepository>(
  (ref) => SavedJobsRepository(ref.watch(supabaseClientProvider)),
);
