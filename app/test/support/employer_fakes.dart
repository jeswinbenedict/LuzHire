import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/failures.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/features/employer/data/employer_repository.dart';

final _t0 = DateTime.utc(2026, 10, 19, 9);

/// The database's transition table (applications migration).
const _transitions = {
  ApplicationStage.applied: {
    ApplicationStage.underReview,
    ApplicationStage.shortlisted,
    ApplicationStage.rejected,
    ApplicationStage.withdrawn,
  },
  ApplicationStage.underReview: {
    ApplicationStage.shortlisted,
    ApplicationStage.rejected,
    ApplicationStage.withdrawn,
  },
  ApplicationStage.shortlisted: {
    ApplicationStage.assessment,
    ApplicationStage.technicalInterview,
    ApplicationStage.hrInterview,
    ApplicationStage.rejected,
    ApplicationStage.withdrawn,
  },
  ApplicationStage.assessment: {
    ApplicationStage.technicalInterview,
    ApplicationStage.hrInterview,
    ApplicationStage.finalReview,
    ApplicationStage.rejected,
    ApplicationStage.withdrawn,
  },
  ApplicationStage.technicalInterview: {
    ApplicationStage.hrInterview,
    ApplicationStage.finalReview,
    ApplicationStage.rejected,
    ApplicationStage.withdrawn,
  },
  ApplicationStage.hrInterview: {
    ApplicationStage.finalReview,
    ApplicationStage.offerIssued,
    ApplicationStage.rejected,
    ApplicationStage.withdrawn,
  },
  ApplicationStage.finalReview: {
    ApplicationStage.offerIssued,
    ApplicationStage.rejected,
    ApplicationStage.withdrawn,
  },
  ApplicationStage.offerIssued: {
    ApplicationStage.hired,
    ApplicationStage.rejected,
    ApplicationStage.withdrawn,
  },
};

/// In-memory workspace that applies the same rules as Postgres where the UI
/// depends on them.
class FakeEmployerRepository implements EmployerRepository {
  FakeEmployerRepository({
    this.role = MemberRole.owner,
    bool withCompany = true,
    this.verified = false,
  }) {
    if (withCompany) {
      companies.add(
        Company(
          id: 'co-1',
          name: 'Nimbus Labs',
          slug: 'nimbus-labs',
          verification: verified
              ? Verification.verified
              : Verification.unverified,
          industry: 'Software',
        ),
      );
    }
  }

  MemberRole role;
  final bool verified;
  final companies = <Company>[];
  final jobs = <Job>[];
  final apps = <JobApplication>[];
  final profilesById = <String, Profile>{};
  final interviewsList = <Interview>[];
  final offersList = <Offer>[];
  final invitesList = <CompanyInvite>[];
  final membersList = <CompanyMember>[
    const CompanyMember(
      userId: 'employer-1',
      role: MemberRole.owner,
      displayName: 'Test employer',
      email: 'employer@example.com',
    ),
  ];
  final _appChanges = StreamController<void>.broadcast();
  int _n = 0;

  /// Adds a published job with [count] applicants at [stage].
  Job seedJob({
    String title = 'Backend Engineer',
    int count = 2,
    ApplicationStage stage = ApplicationStage.applied,
  }) {
    final job = Job(
      id: 'job-${++_n}',
      slug: 'job-$_n',
      title: title,
      companyName: 'Nimbus Labs',
      companyId: 'co-1',
      employmentType: EmploymentType.fullTime,
      workplace: WorkplaceType.hybrid,
      status: JobStatus.published,
      applicationCount: count,
      publishedAt: _t0,
    );
    jobs.add(job);
    for (var i = 0; i < count; i++) {
      final uid = 'cand-${++_n}';
      profilesById[uid] = Profile(
        id: uid,
        role: AppRole.candidate,
        email: '$uid@example.com',
        displayName: 'Candidate $_n',
        headline: 'Go developer',
      );
      apps.add(
        JobApplication(
          id: 'app-$_n',
          jobId: job.id,
          candidateId: uid,
          stage: stage,
          createdAt: _t0,
          updatedAt: _t0,
        ),
      );
    }
    return job;
  }

  void _setStage(String appId, ApplicationStage to) {
    final i = apps.indexWhere((a) => a.id == appId);
    final a = apps[i];
    if (!(_transitions[a.stage] ?? const {}).contains(to)) {
      throw AppFailure(
        'Cannot move an application from ${a.stage.label} to ${to.label}',
      );
    }
    apps[i] = JobApplication(
      id: a.id,
      jobId: a.jobId,
      candidateId: a.candidateId,
      stage: to,
      createdAt: a.createdAt,
      updatedAt: _t0,
      resumeId: a.resumeId,
      coverLetter: a.coverLetter,
    );
    _appChanges.add(null);
  }

  @override
  Future<List<({Company company, MemberRole role})>> myCompanies(
    String uid,
  ) async => [for (final c in companies) (company: c, role: role)];

  @override
  Future<Company> createCompany(String uid, Map<String, dynamic> fields) async {
    final c = Company(
      id: 'co-${companies.length + 1}',
      name: fields['name'] as String,
      slug: 'co',
      verification: Verification.unverified,
      industry: fields['industry'] as String?,
    );
    companies.add(c);
    return c;
  }

  @override
  Future<void> updateCompany(String id, Map<String, dynamic> fields) async {}

  @override
  Future<void> requestVerification(String id) async {
    final i = companies.indexWhere((c) => c.id == id);
    final c = companies[i];
    companies[i] = Company(
      id: c.id,
      name: c.name,
      slug: c.slug,
      verification: Verification.pending,
      industry: c.industry,
    );
  }

  @override
  Future<void> uploadLogo(
    String companyId,
    String fileName,
    Uint8List bytes, {
    String? previousPath,
  }) async {}

  @override
  String logoUrl(String path) => '';

  @override
  Future<List<CompanyMember>> members(String companyId) async => [
    ...membersList,
  ];

  @override
  Future<void> setMemberRole(
    String companyId,
    String userId,
    MemberRole r,
  ) async {}

  @override
  Future<void> removeMember(String companyId, String userId) async =>
      membersList.removeWhere((m) => m.userId == userId);

  @override
  Future<List<CompanyInvite>> invites() async => [...invitesList];

  @override
  Future<void> invite(String companyId, String email, MemberRole role) async {
    invitesList.add(
      CompanyInvite(
        id: 'inv-${++_n}',
        companyId: companyId,
        email: email,
        role: role,
        createdAt: _t0,
      ),
    );
  }

  @override
  Future<void> deleteInvite(String id) async =>
      invitesList.removeWhere((i) => i.id == id);

  @override
  Future<void> acceptInvite(String id) async {
    final inv = invitesList.firstWhere((i) => i.id == id);
    invitesList.remove(inv);
    role = inv.role;
    companies.add(
      Company(
        id: inv.companyId,
        name: inv.companyName ?? 'Team Co',
        slug: 'team-co',
        verification: Verification.verified,
      ),
    );
  }

  @override
  Future<List<Job>> companyJobs(String companyId) async =>
      jobs.where((j) => j.companyId == companyId).toList();

  @override
  Future<Job> saveJob(JobDraft draft, JobStatus status) async {
    // Unverified companies: publishing becomes "pending review".
    final effective = status == JobStatus.published && !verified
        ? JobStatus.pendingReview
        : status;
    final job = Job(
      id: draft.id ?? 'job-${++_n}',
      slug: 'job-$_n',
      title: draft.title,
      companyName: 'Nimbus Labs',
      companyId: draft.companyId,
      employmentType: draft.employmentType,
      workplace: draft.workplace,
      status: effective,
    );
    jobs
      ..removeWhere((j) => j.id == job.id)
      ..add(job);
    return job;
  }

  @override
  Future<void> setJobStatus(String jobId, JobStatus status) async {}

  @override
  Future<void> deleteJob(String jobId) async =>
      jobs.removeWhere((j) => j.id == jobId);

  @override
  Stream<List<JobApplication>> watchJobApplications(String jobId) async* {
    List<JobApplication> mine() => apps.where((a) => a.jobId == jobId).toList();
    yield mine();
    await for (final _ in _appChanges.stream) {
      yield mine();
    }
  }

  @override
  Future<List<JobApplication>> applicationsFor(Iterable<String> jobIds) async =>
      apps.where((a) => jobIds.contains(a.jobId)).toList();

  @override
  Future<Map<ApplicationStage, Set<ApplicationStage>>> transitions() async =>
      _transitions;

  @override
  Future<void> moveStage(String applicationId, ApplicationStage stage) async =>
      _setStage(applicationId, stage);

  @override
  Future<Map<String, Profile>> profiles(Iterable<String> ids) async => {
    for (final id in ids)
      if (profilesById[id] != null) id: profilesById[id]!,
  };

  @override
  Future<CandidateDetail> candidate(String uid) async => CandidateDetail(
    profile: profilesById[uid]!,
    educations: const [],
    experiences: const [],
    skills: const ['Go', 'PostgreSQL'],
  );

  @override
  Future<String?> resumeUrl(JobApplication application) async => null;

  @override
  Future<List<ApplicationEvent>> events(String applicationId) async => [];

  @override
  Future<List<Interview>> interviews(Iterable<String> applicationIds) async =>
      interviewsList
          .where((i) => applicationIds.contains(i.applicationId))
          .toList();

  @override
  Future<void> scheduleInterview({
    required String applicationId,
    required DateTime at,
    required int durationMin,
    required InterviewMode mode,
    String? meetingUrl,
    String? location,
    String? notes,
  }) async {
    final a = apps.firstWhere((x) => x.id == applicationId);
    interviewsList.add(
      Interview(
        id: 'int-${++_n}',
        applicationId: applicationId,
        jobId: a.jobId,
        scheduledAt: at,
        durationMin: durationMin,
        mode: mode,
        status: InterviewStatus.scheduled,
        meetingUrl: meetingUrl,
        notes: notes,
      ),
    );
  }

  @override
  Future<void> setInterviewStatus(String id, InterviewStatus status) async {}

  @override
  Future<List<Offer>> offers(Iterable<String> applicationIds) async =>
      offersList
          .where((o) => applicationIds.contains(o.applicationId))
          .toList();

  @override
  Future<void> makeOffer({
    required String applicationId,
    required double salary,
    required String currency,
    required SalaryPeriod period,
    DateTime? startDate,
    DateTime? expiresAt,
    ({String name, Uint8List bytes})? letter,
  }) async {
    offersList.add(
      Offer(
        id: 'off-${++_n}',
        applicationId: applicationId,
        status: OfferStatus.issued,
        salary: salary,
        currency: currency,
        salaryPeriod: period,
      ),
    );
    _setStage(applicationId, ApplicationStage.offerIssued);
  }

  @override
  Future<void> withdrawOffer(String offerId) async {}

  @override
  Future<HiringStats> stats(String companyId) async {
    final stages = <ApplicationStage, int>{};
    for (final a in apps) {
      stages[a.stage] = (stages[a.stage] ?? 0) + 1;
    }
    return HiringStats(
      stages: stages,
      jobs: {
        'published': jobs.where((j) => j.status == JobStatus.published).length,
      },
      applicationsByWeek: apps.isEmpty
          ? const []
          : [(week: DateTime(2026, 10, 12), count: apps.length)],
      avgDaysToHire: stages[ApplicationStage.hired] == null ? null : 12.5,
    );
  }
}

List<Override> employerOverrides(FakeEmployerRepository repo) => [
  employerRepositoryProvider.overrideWithValue(repo),
];

class CompanyInviteFixture {
  static CompanyInvite forEmail(String email) => CompanyInvite(
    id: 'inv-x',
    companyId: 'co-9',
    email: email,
    role: MemberRole.recruiter,
    createdAt: _t0,
    companyName: 'Team Co',
  );
}
