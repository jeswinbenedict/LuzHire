import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/failures.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/features/companies/data/companies_repository.dart';
import 'package:luzhire/features/jobs/application/location_providers.dart';
import 'package:luzhire/features/jobs/data/jobs_repository.dart';

final _now = DateTime.utc(2026, 10, 19, 12);

Job fakeJob(
  int i, {
  String? title,
  String company = 'Nimbus Labs',
  String? companyId = 'c-nimbus',
  WorkplaceType workplace = WorkplaceType.hybrid,
  EmploymentType type = EmploymentType.fullTime,
}) => Job(
  id: 'job-$i',
  slug: 'job-$i',
  title: title ?? 'Flutter Developer $i',
  companyName: company,
  companyId: companyId,
  employmentType: type,
  experienceLevel: ExperienceLevel.mid,
  workplace: workplace,
  status: JobStatus.published,
  location: 'Bengaluru, IN',
  salaryMin: 1200000,
  salaryMax: 1800000,
  salaryCurrency: 'INR',
  salaryPeriod: SalaryPeriod.year,
  summary: 'Build the LuzHire mobile app.',
  descriptionMd: '## The team\nWe build **tools** for hiring.\n\n- Ship features\n- Review code',
  responsibilities: const ['Own the job search screens'],
  qualifications: const ['2+ years of Flutter'],
  benefits: const ['Health insurance'],
  applicationCount: 7,
  publishedAt: _now.subtract(Duration(hours: i)),
);

/// [job] as `search_jobs` returns it: the card fields, no description.
Job searchRow(Job job) => Job(
  id: job.id,
  slug: job.slug,
  title: job.title,
  companyName: job.companyName,
  companyId: job.companyId,
  employmentType: job.employmentType,
  workplace: job.workplace,
  status: job.status,
  isExternal: job.isExternal,
  externalUrl: job.externalUrl,
  externalSource: job.externalSource,
  logoUrl: job.logoUrl,
  summary: job.summary,
  experienceLevel: job.experienceLevel,
  location: job.location,
  salaryMin: job.salaryMin,
  salaryMax: job.salaryMax,
  salaryCurrency: job.salaryCurrency,
  salaryPeriod: job.salaryPeriod,
  deadline: job.deadline,
  applicationCount: job.applicationCount,
  publishedAt: job.publishedAt,
  hasDetails: false,
);

/// [count] jobs at Nimbus Labs plus one remote internship at Orbit Works.
List<Job> fakeJobs([int count = 30]) => [
  for (var i = 1; i <= count; i++) fakeJob(i),
  fakeJob(
    count + 1,
    title: 'Design Intern',
    company: 'Orbit Works',
    companyId: 'c-orbit',
    workplace: WorkplaceType.remote,
    type: EmploymentType.internship,
  ),
];

const fakeCompanies = [
  Company(
    id: 'c-nimbus',
    name: 'Nimbus Labs',
    slug: 'nimbus-labs',
    verification: Verification.verified,
    industry: 'Software',
    sizeRange: '51-200',
    hqLocation: 'Bengaluru',
    description: 'Fictional company that builds developer tools.',
    benefits: ['Remote Fridays'],
  ),
  Company(
    id: 'c-orbit',
    name: 'Orbit Works',
    slug: 'orbit-works',
    verification: Verification.unverified,
    industry: 'Design',
  ),
];

/// An imported company, as `company_directory` lists it.
const fakeExternalCompany = Company(
  id: '',
  name: 'Askable',
  slug: 'jobs-at-askable',
  verification: Verification.unverified,
  externalLogoUrl: 'https://remotive.com/job/1/logo',
  openJobs: 1,
  isExternal: true,
);

/// A remote contract imported from Remotive, at [fakeExternalCompany].
Job fakeExternalJob() => Job(
  id: 'ext-askable',
  slug: 'ext-askable',
  title: 'Remote Flutter Engineer',
  companyName: 'Askable',
  employmentType: EmploymentType.contract,
  workplace: WorkplaceType.remote,
  status: JobStatus.published,
  isExternal: true,
  externalSource: 'remotive',
  externalUrl: 'https://remotive.com/remote-jobs/x-1',
  logoUrl: 'https://remotive.com/job/1/logo',
  publishedAt: _now.subtract(const Duration(minutes: 30)),
);

/// In-memory `search_jobs`: keyword, remote, type and company filters, newest
/// first, keyset pages of [searchRow]s. [bySlug] returns the full job.
class FakeJobsRepository implements JobsRepository {
  FakeJobsRepository([List<Job>? jobs]) : jobs = jobs ?? fakeJobs();
  final List<Job> jobs;
  final queries = <JobSearchQuery>[];

  /// Slugs of the full jobs loaded, in order.
  final detailLoads = <String>[];

  /// While set, [bySlug] waits for it to complete.
  Completer<void>? holdDetails;

  /// While true, [bySlug] fails like a dropped connection.
  bool failDetails = false;

  /// Cities on the hiring map; [near] calls are recorded in [nearCalls].
  List<HiringLocation> locations = const [
    HiringLocation(
      cityId: 1,
      name: 'Pune',
      state: 'Maharashtra',
      countryCode: 'IN',
      latitude: 18.52,
      longitude: 73.86,
      openJobs: 3,
    ),
    HiringLocation(
      cityId: 2,
      name: 'Kochi',
      state: 'Kerala',
      countryCode: 'IN',
      latitude: 9.93,
      longitude: 76.27,
      openJobs: 1,
    ),
  ];
  final nearCalls = <NearbyQuery>[];

  @override
  Future<List<Job>> search(JobSearchQuery q, {Job? after}) async {
    queries.add(q);
    final kw = q.keyword.toLowerCase();
    final matches =
        jobs
            .where(
              (j) =>
                  (kw.isEmpty ||
                      j.title.toLowerCase().contains(kw) ||
                      j.companyName.toLowerCase().contains(kw)) &&
                  (!q.remoteOnly || j.workplace == WorkplaceType.remote) &&
                  (q.types.isEmpty || q.types.contains(j.employmentType)) &&
                  (q.companyId == null || j.companyId == q.companyId) &&
                  (q.employer == null ||
                      j.companyName.toLowerCase() == q.employer!.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
    final start = after == null ? 0 : matches.indexOf(after) + 1;
    return matches.skip(start).take(q.pageSize).map(searchRow).toList();
  }

  @override
  Future<Job?> bySlug(String slug) async {
    detailLoads.add(slug);
    await holdDetails?.future;
    if (failDetails) {
      throw const AppFailure("Couldn't reach LuzHire.", code: 'network');
    }
    return jobs.where((j) => j.slug == slug).firstOrNull;
  }

  @override
  Future<List<Job>> byIds(Iterable<String> ids) async =>
      jobs.where((j) => ids.contains(j.id)).toList();

  /// The first three jobs, as `recommended_jobs` explains them.
  @override
  Future<List<Job>> recommended({int pageSize = 12}) async => [
    for (final j in jobs.take(3))
      searchRow(j).withReasons(const ['Matches 2 of your skills', 'In Pune']),
  ];

  /// Jobs 1 and 2, 4 and 30 km from any point.
  @override
  Future<List<Job>> near({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int pageSize = 30,
  }) async {
    nearCalls.add((
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    ));
    return [
      searchRow(jobs[0]).withDistance(4),
      if (radiusKm >= 30) searchRow(jobs[1]).withDistance(30),
    ];
  }

  @override
  Future<List<HiringLocation>> hiringLocations() async => locations;

  @override
  Future<List<String>> jobSkills(String jobId) async => ['Dart', 'Flutter'];

  @override
  Future<List<({String slug, String name})>> skills() async => [
    (slug: 'dart', name: 'Dart'),
    (slug: 'flutter', name: 'Flutter'),
  ];
}

/// LuzHire employers plus [externals], like `company_directory`.
class FakeCompaniesRepository implements CompaniesRepository {
  FakeCompaniesRepository({this.externals = const []});
  final List<Company> externals;

  @override
  Future<List<Company>> list({
    String query = '',
    int offset = 0,
    int limit = 24,
  }) async => [...fakeCompanies, ...externals]
      .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
      .skip(offset)
      .take(limit)
      .toList();

  @override
  Future<Company?> bySlug(String slug) async =>
      [...fakeCompanies, ...externals].where((c) => c.slug == slug).firstOrNull;

  @override
  Future<Company?> byId(String id) async =>
      fakeCompanies.where((c) => c.id == id).firstOrNull;

  @override
  String? logoUrl(Company company) => company.externalLogoUrl;
}

/// Saved jobs with a live stream, like Supabase Realtime.
class FakeSavedJobsRepository implements SavedJobsRepository {
  final _ids = <String>{};
  final _changes = StreamController<Set<String>>.broadcast();

  Set<String> get ids => {..._ids};

  @override
  Stream<Set<String>> watchIds(String userId) async* {
    yield {..._ids};
    yield* _changes.stream;
  }

  @override
  Future<void> save(String userId, String jobId) async {
    _ids.add(jobId);
    _changes.add({..._ids});
  }

  @override
  Future<void> remove(String userId, String jobId) async {
    _ids.remove(jobId);
    _changes.add({..._ids});
  }
}

List<Override> jobBoardOverrides({
  FakeJobsRepository? jobs,
  FakeSavedJobsRepository? saved,
  FakeCompaniesRepository? companies,
}) => [
  jobsRepositoryProvider.overrideWithValue(jobs ?? FakeJobsRepository()),
  companiesRepositoryProvider.overrideWithValue(
    companies ?? FakeCompaniesRepository(),
  ),
  savedJobsRepositoryProvider.overrideWithValue(
    saved ?? FakeSavedJobsRepository(),
  ),
];

extension on Job {
  Job withReasons(List<String> reasons) => _copy(reasons: reasons);
  Job withDistance(double km) => _copy(distanceKm: km);

  Job _copy({List<String>? reasons, double? distanceKm}) => Job(
    id: id,
    slug: slug,
    title: title,
    companyName: companyName,
    companyId: companyId,
    employmentType: employmentType,
    workplace: workplace,
    status: status,
    location: location,
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    salaryCurrency: salaryCurrency,
    salaryPeriod: salaryPeriod,
    summary: summary,
    publishedAt: publishedAt,
    hasDetails: false,
    matchReasons: reasons ?? matchReasons,
    distanceKm: distanceKm ?? this.distanceKm,
  );
}

/// A device at a fixed point, or one that refuses with [failure].
class FakeLocationService implements LocationService {
  FakeLocationService({this.failure});
  final AppFailure? failure;

  @override
  Future<GeoPoint> current() async {
    if (failure != null) throw failure!;
    return (latitude: 18.6, longitude: 73.75);
  }
}
