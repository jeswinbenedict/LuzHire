import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/features/companies/data/companies_repository.dart';
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

/// In-memory `search_jobs`: keyword, remote, type and company filters, newest
/// first, keyset pages.
class FakeJobsRepository implements JobsRepository {
  FakeJobsRepository([List<Job>? jobs]) : jobs = jobs ?? fakeJobs();
  final List<Job> jobs;
  final queries = <JobSearchQuery>[];

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
                  (q.companyId == null || j.companyId == q.companyId),
            )
            .toList()
          ..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
    final start = after == null ? 0 : matches.indexOf(after) + 1;
    return matches.skip(start).take(q.pageSize).toList();
  }

  @override
  Future<Job?> bySlug(String slug) async =>
      jobs.where((j) => j.slug == slug).firstOrNull;

  @override
  Future<List<Job>> byIds(Iterable<String> ids) async =>
      jobs.where((j) => ids.contains(j.id)).toList();

  @override
  Future<List<String>> jobSkills(String jobId) async => ['Dart', 'Flutter'];

  @override
  Future<List<({String slug, String name})>> skills() async => [
    (slug: 'dart', name: 'Dart'),
    (slug: 'flutter', name: 'Flutter'),
  ];
}

class FakeCompaniesRepository implements CompaniesRepository {
  @override
  Future<List<Company>> list({
    String query = '',
    int offset = 0,
    int limit = 24,
  }) async => fakeCompanies
      .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
      .skip(offset)
      .take(limit)
      .toList();

  @override
  Future<Company?> bySlug(String slug) async =>
      fakeCompanies.where((c) => c.slug == slug).firstOrNull;

  @override
  Future<Company?> byId(String id) async =>
      fakeCompanies.where((c) => c.id == id).firstOrNull;

  @override
  String? logoUrl(Company company) => null;
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
}) => [
  jobsRepositoryProvider.overrideWithValue(jobs ?? FakeJobsRepository()),
  companiesRepositoryProvider.overrideWithValue(FakeCompaniesRepository()),
  savedJobsRepositoryProvider.overrideWithValue(
    saved ?? FakeSavedJobsRepository(),
  ),
];
