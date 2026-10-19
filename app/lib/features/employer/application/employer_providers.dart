import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../candidate/application/candidate_providers.dart'
    show jobIdsKey, myNotificationsProvider;
import '../../jobs/application/job_board_providers.dart';
import '../data/employer_repository.dart';

String _uid(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw const AppFailure('Sign in to see this page.', code: 'signed_out');
  }
  return uid;
}

typedef Membership = ({Company company, MemberRole role});

// ---------------------------------------------------------------- company

final myCompaniesProvider = FutureProvider.autoDispose<List<Membership>>(
  (ref) => ref.watch(employerRepositoryProvider).myCompanies(_uid(ref)),
);

/// The company picked in the switcher; null means "the first one".
class SelectedCompany extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String id) => state = id;
}

final selectedCompanyProvider = NotifierProvider<SelectedCompany, String?>(
  SelectedCompany.new,
);

/// The company the workspace is showing, or null when the user has none yet.
final currentMembershipProvider = FutureProvider.autoDispose<Membership?>((
  ref,
) async {
  final list = await ref.watch(myCompaniesProvider.future);
  if (list.isEmpty) return null;
  final picked = ref.watch(selectedCompanyProvider);
  return list.where((m) => m.company.id == picked).firstOrNull ?? list.first;
});

final membersProvider = FutureProvider.autoDispose
    .family<List<CompanyMember>, String>(
      (ref, companyId) =>
          ref.watch(employerRepositoryProvider).members(companyId),
    );

/// Invitations visible to the user (their company's and their own).
final invitesProvider = FutureProvider.autoDispose<List<CompanyInvite>>((ref) {
  ref.watch(myNotificationsProvider); // a new invite arrives as a notification
  return ref.watch(employerRepositoryProvider).invites();
});

// ---------------------------------------------------------------- jobs

final companyJobsProvider = FutureProvider.autoDispose
    .family<List<Job>, String>(
      (ref, companyId) =>
          ref.watch(employerRepositoryProvider).companyJobs(companyId),
    );

/// Every application across the company's jobs (interviews, analytics).
final companyApplicationsProvider = FutureProvider.autoDispose
    .family<List<JobApplication>, String>((ref, companyId) async {
      final jobs = await ref.watch(companyJobsProvider(companyId).future);
      return ref
          .watch(employerRepositoryProvider)
          .applicationsFor(jobs.map((j) => j.id));
    });

// ---------------------------------------------------------------- pipeline

/// Live applications for one job: moves by teammates appear at once.
final jobApplicationsProvider = StreamProvider.autoDispose
    .family<List<JobApplication>, String>(
      (ref, jobId) =>
          ref.watch(employerRepositoryProvider).watchJobApplications(jobId),
    );

final transitionsProvider =
    FutureProvider<Map<ApplicationStage, Set<ApplicationStage>>>(
      (ref) => ref.watch(employerRepositoryProvider).transitions(),
    );

/// Applicant profiles keyed by id; [idsKey] from [jobIdsKey].
final applicantProfilesProvider = FutureProvider.autoDispose
    .family<Map<String, Profile>, String>(
      (ref, idsKey) => idsKey.isEmpty
          ? Future.value(const {})
          : ref.watch(employerRepositoryProvider).profiles(idsKey.split(',')),
    );

final candidateDetailProvider = FutureProvider.autoDispose
    .family<CandidateDetail, String>(
      (ref, uid) => ref.watch(employerRepositoryProvider).candidate(uid),
    );

final employerEventsProvider = FutureProvider.autoDispose
    .family<List<ApplicationEvent>, String>(
      (ref, applicationId) =>
          ref.watch(employerRepositoryProvider).events(applicationId),
    );

final employerInterviewsProvider = FutureProvider.autoDispose
    .family<List<Interview>, String>((ref, appIdsKey) {
      if (appIdsKey.isEmpty) return Future.value(const []);
      return ref
          .watch(employerRepositoryProvider)
          .interviews(appIdsKey.split(','));
    });

final employerOffersProvider = FutureProvider.autoDispose
    .family<List<Offer>, String>((ref, appIdsKey) {
      ref.watch(myNotificationsProvider); // candidate replies notify the team
      if (appIdsKey.isEmpty) return Future.value(const []);
      return ref.watch(employerRepositoryProvider).offers(appIdsKey.split(','));
    });

final hiringStatsProvider = FutureProvider.autoDispose
    .family<HiringStats, String>(
      (ref, companyId) =>
          ref.watch(employerRepositoryProvider).stats(companyId),
    );

String idsKey(Iterable<String> ids) => jobIdsKey(ids);

// ---------------------------------------------------------------- actions

/// Writes from the workspace. Each refreshes what it changed; failures are
/// [AppFailure]s with readable messages (often straight from Postgres).
class EmployerActions {
  EmployerActions(this._ref);
  final Ref _ref;

  EmployerRepository get _repo => _ref.read(employerRepositoryProvider);

  String get _me {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) throw const AppFailure('Sign in first.');
    return uid;
  }

  Future<Company> createCompany(Map<String, dynamic> fields) async {
    final c = await _repo.createCompany(_me, fields);
    _ref.invalidate(myCompaniesProvider);
    return c;
  }

  Future<void> updateCompany(String id, Map<String, dynamic> fields) async {
    await _repo.updateCompany(id, fields);
    _ref.invalidate(myCompaniesProvider);
  }

  Future<void> requestVerification(String id) async {
    await _repo.requestVerification(id);
    _ref.invalidate(myCompaniesProvider);
  }

  Future<void> uploadLogo(Company c, String name, Uint8List bytes) async {
    await _repo.uploadLogo(c.id, name, bytes, previousPath: c.logoPath);
    _ref.invalidate(myCompaniesProvider);
  }

  Future<void> invite(String companyId, String email, MemberRole role) async {
    await _repo.invite(companyId, email, role);
    _ref.invalidate(invitesProvider);
  }

  Future<void> deleteInvite(String id) async {
    await _repo.deleteInvite(id);
    _ref.invalidate(invitesProvider);
  }

  Future<void> acceptInvite(String id) async {
    await _repo.acceptInvite(id);
    _ref
      ..invalidate(invitesProvider)
      ..invalidate(myCompaniesProvider);
  }

  Future<void> setMemberRole(String companyId, String uid, MemberRole r) async {
    await _repo.setMemberRole(companyId, uid, r);
    _ref.invalidate(membersProvider(companyId));
  }

  Future<void> removeMember(String companyId, String uid) async {
    await _repo.removeMember(companyId, uid);
    _ref.invalidate(membersProvider(companyId));
  }

  Future<Job> saveJob(JobDraft draft, JobStatus status) async {
    final job = await _repo.saveJob(draft, status);
    _ref.invalidate(companyJobsProvider(draft.companyId));
    return job;
  }

  Future<void> setJobStatus(Job job, JobStatus status) async {
    await _repo.setJobStatus(job.id, status);
    _ref.invalidate(companyJobsProvider(job.companyId ?? ''));
  }

  Future<void> deleteJob(Job job) async {
    await _repo.deleteJob(job.id);
    _ref.invalidate(companyJobsProvider(job.companyId ?? ''));
  }

  Future<void> moveStage(String applicationId, ApplicationStage stage) async {
    await _repo.moveStage(applicationId, stage);
    _ref.invalidate(employerEventsProvider(applicationId));
  }

  Future<void> scheduleInterview({
    required String applicationId,
    required DateTime at,
    required int durationMin,
    required InterviewMode mode,
    String? meetingUrl,
    String? location,
    String? notes,
  }) async {
    await _repo.scheduleInterview(
      applicationId: applicationId,
      at: at,
      durationMin: durationMin,
      mode: mode,
      meetingUrl: meetingUrl,
      location: location,
      notes: notes,
    );
    _ref.invalidate(employerInterviewsProvider);
  }

  Future<void> setInterviewStatus(String id, InterviewStatus s) async {
    await _repo.setInterviewStatus(id, s);
    _ref.invalidate(employerInterviewsProvider);
  }

  Future<void> makeOffer({
    required String applicationId,
    required double salary,
    required String currency,
    required SalaryPeriod period,
    DateTime? startDate,
    DateTime? expiresAt,
    ({String name, Uint8List bytes})? letter,
  }) async {
    await _repo.makeOffer(
      applicationId: applicationId,
      salary: salary,
      currency: currency,
      period: period,
      startDate: startDate,
      expiresAt: expiresAt,
      letter: letter,
    );
    _ref.invalidate(employerOffersProvider);
  }

  Future<void> withdrawOffer(String id) async {
    await _repo.withdrawOffer(id);
    _ref.invalidate(employerOffersProvider);
  }
}

final employerActionsProvider = Provider<EmployerActions>(EmployerActions.new);
