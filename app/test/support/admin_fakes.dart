import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/features/admin/data/admin_repository.dart';

final _t0 = DateTime.utc(2026, 10, 19, 9);

/// In-memory admin data with the same state rules as the review RPCs.
class FakeAdminRepository implements AdminRepository {
  final companies = <Company>[
    const Company(
      id: 'co-p',
      name: 'Pending Co',
      slug: 'pending-co',
      verification: Verification.pending,
      industry: 'FinTech',
      description: 'Payments for small shops.',
    ),
  ];
  final jobs = <Job>[
    const Job(
      id: 'job-p',
      slug: 'job-p',
      title: 'Support Engineer',
      companyName: 'Pending Co',
      companyId: 'co-p',
      employmentType: EmploymentType.fullTime,
      workplace: WorkplaceType.remote,
      status: JobStatus.pendingReview,
    ),
  ];
  final reportList = <Report>[
    Report(
      id: 'rep-1',
      reporterId: 'cand-1',
      targetType: 'job',
      targetId: 'job-x',
      reason: 'Asks candidates to pay a fee',
      status: ReportStatus.open,
      createdAt: _t0,
    ),
  ];
  final people = <Profile>[
    Profile(
      id: 'admin-1',
      role: AppRole.admin,
      email: 'admin@example.com',
      displayName: 'Test admin',
      createdAt: _t0,
    ),
    Profile(
      id: 'u-2',
      role: AppRole.candidate,
      email: 'asha@example.com',
      displayName: 'Asha Verma',
      createdAt: _t0,
    ),
  ];
  final announcementList = <Announcement>[];
  final audits = [
    for (var i = 60; i > 0; i--)
      AuditEntry(
        id: i,
        actorId: 'admin-1',
        actorRole: 'admin',
        action: i.isEven ? 'jobs.update' : 'companies.update',
        targetTable: i.isEven ? 'jobs' : 'companies',
        targetId: 't-$i',
        diff: const {
          'status': ['pending_review', 'published'],
        },
        createdAt: _t0,
      ),
  ];
  final decisions = <String>[];

  @override
  Future<PlatformStats> stats() async => PlatformStats(
    users: const {'candidate': 12, 'employer': 4, 'admin': 1},
    companies: {
      'pending': companies
          .where((c) => c.verification == Verification.pending)
          .length,
      'verified': 3,
    },
    jobs: {
      'pending_review': jobs
          .where((j) => j.status == JobStatus.pendingReview)
          .length,
      'published': 9,
    },
    suspended: 0,
    applications: 21,
    openReports: reportList.where((r) => r.status == ReportStatus.open).length,
    signupsByWeek: [(week: DateTime(2026, 10, 12), count: 5)],
  );

  @override
  Future<List<Company>> pendingCompanies() async =>
      companies.where((c) => c.verification == Verification.pending).toList();

  @override
  Future<void> reviewCompany(
    String id, {
    required bool approve,
    String? note,
  }) async {
    decisions.add('company:$id:$approve:${note ?? ''}');
    final i = companies.indexWhere((c) => c.id == id);
    final c = companies[i];
    companies[i] = Company(
      id: c.id,
      name: c.name,
      slug: c.slug,
      verification: approve ? Verification.verified : Verification.rejected,
    );
  }

  @override
  Future<List<Job>> pendingJobs() async =>
      jobs.where((j) => j.status == JobStatus.pendingReview).toList();

  @override
  Future<void> reviewJob(
    String id, {
    required bool approve,
    String? note,
  }) async {
    decisions.add('job:$id:$approve:${note ?? ''}');
    jobs.removeWhere((j) => j.id == id);
  }

  @override
  Future<List<Report>> reports(ReportStatus status) async =>
      reportList.where((r) => r.status == status).toList();

  @override
  Future<Map<String, String>> targetNames(List<Report> reports) async => {
    'job:job-x': 'Data Entry (work from home)',
  };

  @override
  Future<void> resolveReport(String id, ReportStatus outcome) async {
    final i = reportList.indexWhere((r) => r.id == id);
    final r = reportList[i];
    reportList[i] = Report(
      id: r.id,
      reporterId: r.reporterId,
      targetType: r.targetType,
      targetId: r.targetId,
      reason: r.reason,
      status: outcome,
      createdAt: r.createdAt,
      resolvedAt: _t0,
    );
  }

  @override
  Future<List<Profile>> users({
    String query = '',
    AppRole? role,
    AccountStatus? status,
    int offset = 0,
    int limit = 25,
  }) async => people
      .where(
        (u) =>
            (query.isEmpty ||
                u.displayName.toLowerCase().contains(query.toLowerCase()) ||
                u.email.contains(query.toLowerCase())) &&
            (role == null || u.role == role) &&
            (status == null || u.accountStatus == status),
      )
      .toList();

  @override
  Future<List<Announcement>> announcements() async => [...announcementList];

  @override
  Future<void> saveAnnouncement({
    String? id,
    required String title,
    required String bodyMd,
    required AnnouncementAudience audience,
    required bool publish,
    required String adminId,
  }) async {
    announcementList
      ..removeWhere((a) => a.id == id)
      ..add(
        Announcement(
          id: id ?? 'ann-${announcementList.length + 1}',
          title: title.trim(),
          bodyMd: bodyMd.trim(),
          audience: audience,
          createdAt: _t0,
          publishedAt: publish
              ? DateTime.now().subtract(const Duration(minutes: 1))
              : null,
        ),
      );
  }

  @override
  Future<void> deleteAnnouncement(String id) async =>
      announcementList.removeWhere((a) => a.id == id);

  @override
  Future<List<AuditEntry>> audit({
    String? table,
    String? actorId,
    int? beforeId,
    int limit = 50,
  }) async => audits
      .where(
        (e) =>
            (table == null || e.targetTable == table) &&
            (beforeId == null || e.id < beforeId),
      )
      .take(limit)
      .toList();
}

class FakeGovernanceRepository implements GovernanceRepository {
  FakeGovernanceRepository(this.admin);
  final FakeAdminRepository admin;
  final reports = <String>[];

  @override
  Future<void> report({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
  }) async => reports.add('$targetType:$targetId:$reason');

  @override
  Future<List<Announcement>> activeAnnouncements() async =>
      admin.announcementList.where((a) => a.isPublished).toList();
}

List<Override> adminOverrides(
  FakeAdminRepository repo, [
  FakeGovernanceRepository? gov,
]) => [
  adminRepositoryProvider.overrideWithValue(repo),
  governanceRepositoryProvider.overrideWithValue(
    gov ?? FakeGovernanceRepository(repo),
  ),
];
