import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';

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
    this.employer,
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

  /// Name of an imported company (no company id): its open roles.
  final String? employer;
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
    employer: employer,
    pageSize: pageSize,
  );

  /// [copyWith] can't clear nullable fields; these can.
  JobSearchQuery withMinSalary(num? value) =>
      _with(minAnnualSalary: value, postedWithinDays: postedWithinDays);
  JobSearchQuery withPostedWithin(int? days) =>
      _with(minAnnualSalary: minAnnualSalary, postedWithinDays: days);

  JobSearchQuery _with({num? minAnnualSalary, int? postedWithinDays}) =>
      JobSearchQuery(
        keyword: keyword,
        location: location,
        remoteOnly: remoteOnly,
        types: types,
        levels: levels,
        minAnnualSalary: minAnnualSalary,
        skills: skills,
        postedWithinDays: postedWithinDays,
        companyId: companyId,
        employer: employer,
        pageSize: pageSize,
      );

  /// Keyword and location kept; every filter cleared.
  JobSearchQuery clearFilters() =>
      JobSearchQuery(keyword: keyword, location: location);

  /// Filters beyond keyword/location (for the "Filters (n)" button).
  int get activeFilterCount =>
      (remoteOnly ? 1 : 0) +
      types.length +
      levels.length +
      (minAnnualSalary != null ? 1 : 0) +
      skills.length +
      (postedWithinDays != null ? 1 : 0);

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
    'employer': ?employer,
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
      other.employer == employer &&
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
    employer,
    pageSize,
  );
}

/// The job columns [Job.fromJson] reads: everything but the search vector
/// and bookkeeping, which would double the size of a job.
const _jobColumns =
    'id, source, company_id, company_name, external_logo_url, '
    'external_source, external_url, title, slug, description_md, summary, '
    'employment_type, experience_level, workplace, location_text, '
    'salary_min, salary_max, salary_currency, salary_period, '
    'responsibilities, qualifications, benefits, status, deadline, '
    'application_count, published_at, companies(logo_path)';

class JobsRepository {
  JobsRepository(this._db);
  final SupabaseClient _db;

  /// One page of results; pass the last job of the previous page as [after].
  /// Results are job cards without the description ([Job.hasDetails] is
  /// false); [bySlug] loads the full job.
  Future<List<Job>> search(JobSearchQuery query, {Job? after}) =>
      guardDb(() async {
        final rows = await _db.rpc<List<dynamic>>(
          'search_jobs',
          params: query.toRpcParams(after: after),
        );
        return [for (final r in rows) _job((r as Map).cast())];
      });

  /// Published jobs that arrived on LuzHire after [since]: imported rows
  /// (created) or employers' jobs (published). A count only, no rows.
  Future<int> countNewSince(DateTime since) => guardDb(() async {
    final at = since.toUtc().toIso8601String();
    final res = await _db
        .from('jobs')
        .select('id')
        .eq('status', 'published')
        .or('created_at.gt.$at,published_at.gt.$at')
        .count(CountOption.exact);
    return res.count;
  });

  Future<Job?> bySlug(String slug) => guardDb(() async {
    final row = await _db
        .from('jobs')
        .select(_jobColumns)
        .eq('slug', slug)
        .maybeSingle();
    return row == null ? null : _job(row);
  });

  /// A LuzHire company's own logo stands in where a feed logo would be.
  Job _job(Json row) {
    final path =
        row['company_logo_path'] as String? ??
        (row['companies'] as Map?)?['logo_path'] as String?;
    if (path == null || row['external_logo_url'] != null) {
      return Job.fromJson(row);
    }
    return Job.fromJson({
      ...row,
      'external_logo_url': _db.storage.from('company-media').getPublicUrl(path),
    });
  }

  /// Jobs ranked for the signed-in user, each with [Job.matchReasons];
  /// visitors get the newest jobs.
  Future<List<Job>> recommended({int pageSize = 12}) => guardDb(() async {
    final rows = await _db.rpc<List<dynamic>>(
      'recommended_jobs',
      params: {'page_size': pageSize},
    );
    return [for (final r in rows) _job((r as Map).cast())];
  });

  /// Jobs within [radiusKm] of a point, nearest first ([Job.distanceKm]).
  Future<List<Job>> near({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int pageSize = 30,
  }) => guardDb(() async {
    final rows = await _db.rpc<List<dynamic>>(
      'jobs_near',
      params: {
        'lat': latitude,
        'lng': longitude,
        'radius_km': radiusKm,
        'page_size': pageSize,
      },
    );
    return [for (final r in rows) _job((r as Map).cast())];
  });

  /// Cities with open roles, most first.
  Future<List<HiringLocation>> hiringLocations() => guardDb(() async {
    final rows = await _db
        .from('hiring_locations')
        .select()
        .order('open_jobs', ascending: false)
        .limit(300);
    return [for (final r in rows) HiringLocation.fromJson(r)];
  });

  /// Jobs by id (e.g. saved jobs), newest first. Unpublished ones drop out
  /// through RLS.
  Future<List<Job>> byIds(Iterable<String> ids) => guardDb(() async {
    if (ids.isEmpty) return const <Job>[];
    final rows = await _db
        .from('jobs')
        .select(_jobColumns)
        .inFilter('id', ids.toList())
        .order('published_at', ascending: false);
    return [for (final r in rows) _job(r)];
  });

  /// Names of the skills tagged on [jobId], alphabetical.
  Future<List<String>> jobSkills(String jobId) => guardDb(() async {
    final rows = await _db
        .from('job_skills')
        .select('skills(name)')
        .eq('job_id', jobId);
    return [
      for (final r in rows)
        if ((r['skills'] as Map?)?['name'] case final String name) name,
    ]..sort();
  });

  Future<List<({String slug, String name})>> skills() => guardDb(() async {
    final rows = await _db
        .from('skills')
        .select('slug, name')
        .order('name', ascending: true);
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

/// Thrown by data providers in builds without Supabase config.
const notConfigured = AppFailure(
  'Jobs are not available in this build.',
  code: 'not_configured',
);

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return JobsRepository(ref.watch(supabaseClientProvider));
});

final savedJobsRepositoryProvider = Provider<SavedJobsRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return SavedJobsRepository(ref.watch(supabaseClientProvider));
});
