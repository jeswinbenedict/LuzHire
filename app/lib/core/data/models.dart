import 'package:flutter/foundation.dart';

import 'enums.dart';

typedef Json = Map<String, dynamic>;

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
double? _num(Object? v) => v == null ? null : (v as num).toDouble();
List<String> _strings(Object? v) =>
    v == null ? const [] : (v as List).map((e) => e as String).toList();

/// A job posting (native or aggregated). Mirrors public.jobs.
@immutable
class Job {
  const Job({
    required this.id,
    required this.slug,
    required this.title,
    required this.companyName,
    required this.employmentType,
    required this.workplace,
    required this.status,
    this.companyId,
    this.isExternal = false,
    this.externalUrl,
    this.externalSource,
    this.logoUrl,
    this.summary,
    this.descriptionMd = '',
    this.experienceLevel,
    this.location,
    this.salaryMin,
    this.salaryMax,
    this.salaryCurrency,
    this.salaryPeriod,
    this.responsibilities = const [],
    this.qualifications = const [],
    this.benefits = const [],
    this.deadline,
    this.applicationCount = 0,
    this.publishedAt,
    this.hasDetails = true,
    this.matchReasons = const [],
    this.distanceKm,
  });

  final String id;
  final String slug;
  final String title;
  final String companyName;
  final String? companyId;
  final bool isExternal;
  final String? externalUrl;
  final String? externalSource;
  final String? logoUrl;
  final String? summary;
  final String descriptionMd;
  final EmploymentType employmentType;
  final ExperienceLevel? experienceLevel;
  final WorkplaceType workplace;
  final String? location;
  final double? salaryMin;
  final double? salaryMax;
  final String? salaryCurrency;
  final SalaryPeriod? salaryPeriod;
  final List<String> responsibilities;
  final List<String> qualifications;
  final List<String> benefits;
  final JobStatus status;
  final DateTime? deadline;
  final int applicationCount;
  final DateTime? publishedAt;

  /// False for search results (`search_jobs`), which leave out the
  /// description, responsibilities, qualifications and benefits. The detail
  /// view loads the full job by slug.
  final bool hasDetails;

  /// Why `recommended_jobs` picked this job ("Matches 3 of your skills").
  final List<String> matchReasons;

  /// From `jobs_near`: how far the job is from the chosen point.
  final double? distanceKm;

  bool get hasSalary => salaryMin != null || salaryMax != null;

  factory Job.fromJson(Json j) => Job(
    id: j['id'] as String,
    slug: j['slug'] as String,
    title: j['title'] as String,
    companyName: j['company_name'] as String,
    companyId: j['company_id'] as String?,
    isExternal: j['source'] == 'external',
    externalUrl: j['external_url'] as String?,
    externalSource: j['external_source'] as String?,
    logoUrl: j['external_logo_url'] as String?,
    summary: j['summary'] as String?,
    descriptionMd: (j['description_md'] as String?) ?? '',
    employmentType: EmploymentType.fromDb(j['employment_type'] as String?),
    experienceLevel: ExperienceLevel.fromDbOrNull(
      j['experience_level'] as String?,
    ),
    workplace: WorkplaceType.fromDb(j['workplace'] as String?),
    location: j['location_text'] as String?,
    salaryMin: _num(j['salary_min']),
    salaryMax: _num(j['salary_max']),
    salaryCurrency: j['salary_currency'] as String?,
    salaryPeriod: SalaryPeriod.fromDbOrNull(j['salary_period'] as String?),
    responsibilities: _strings(j['responsibilities']),
    qualifications: _strings(j['qualifications']),
    benefits: _strings(j['benefits']),
    status: JobStatus.fromDb(j['status'] as String?),
    deadline: _date(j['deadline']),
    applicationCount: (j['application_count'] as num?)?.toInt() ?? 0,
    publishedAt: _date(j['published_at']),
    hasDetails: j.containsKey('description_md'),
    matchReasons: _strings(j['match_reasons']),
    distanceKm: _num(j['distance_km']),
  );

  @override
  bool operator ==(Object other) => other is Job && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Mirrors public.companies (public fields).
@immutable
class Company {
  const Company({
    required this.id,
    required this.name,
    required this.slug,
    required this.verification,
    this.description,
    this.industry,
    this.sizeRange,
    this.website,
    this.hqLocation,
    this.logoPath,
    this.benefits = const [],
    this.externalLogoUrl,
    this.openJobs,
    this.isExternal = false,
  });

  /// Empty for [isExternal] companies, which exist only through their jobs.
  final String id;
  final String name;
  final String slug;
  final Verification verification;
  final String? description;
  final String? industry;
  final String? sizeRange;
  final String? website;
  final String? hqLocation;
  final String? logoPath;
  final List<String> benefits;

  /// Logo from the job feed, for [isExternal] companies.
  final String? externalLogoUrl;

  /// Published jobs (from `company_directory`; null elsewhere).
  final int? openJobs;

  /// A company behind imported jobs (Remotive, Adzuna), with no LuzHire
  /// profile.
  final bool isExternal;

  bool get isVerified => verification == Verification.verified;

  factory Company.fromJson(Json j) => Company(
    id: (j['id'] as String?) ?? '',
    name: j['name'] as String,
    slug: j['slug'] as String,
    verification: Verification.fromDb(j['verification'] as String?),
    description: j['description'] as String?,
    industry: j['industry'] as String?,
    sizeRange: j['size_range'] as String?,
    website: j['website'] as String?,
    hqLocation: j['hq_location'] as String?,
    logoPath: j['logo_path'] as String?,
    benefits: _strings(j['benefits']),
    externalLogoUrl: j['external_logo_url'] as String?,
    openJobs: (j['open_jobs'] as num?)?.toInt(),
    isExternal: j['is_external'] == true,
  );
}

/// Mirrors public.profiles.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.email,
    required this.displayName,
    this.headline,
    this.bio,
    this.location,
    this.phone,
    this.avatarPath,
    this.links = const {},
    this.profileCompletion = 0,
    this.accountStatus = AccountStatus.active,
    this.createdAt,
  });

  final String id;
  final AppRole role;
  final String email;
  final String displayName;
  final String? headline;
  final String? bio;
  final String? location;
  final String? phone;
  final String? avatarPath;
  final Map<String, String> links;
  final int profileCompletion;
  final AccountStatus accountStatus;
  final DateTime? createdAt;

  factory Profile.fromJson(Json j) => Profile(
    id: j['id'] as String,
    role: AppRole.fromDb(j['role'] as String?),
    email: j['email'] as String,
    displayName: j['display_name'] as String,
    headline: j['headline'] as String?,
    bio: j['bio'] as String?,
    location: j['location'] as String?,
    phone: j['phone'] as String?,
    avatarPath: j['avatar_path'] as String?,
    links: ((j['links'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k as String, '$v'),
    ),
    profileCompletion: (j['profile_completion'] as num?)?.toInt() ?? 0,
    accountStatus: AccountStatus.fromDb(j['account_status'] as String?),
    createdAt: _date(j['created_at']),
  );
}

/// Mirrors public.applications.
@immutable
class JobApplication {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.candidateId,
    required this.stage,
    required this.createdAt,
    required this.updatedAt,
    this.resumeId,
    this.coverLetter,
    this.job,
  });

  final String id;
  final String jobId;
  final String candidateId;
  final ApplicationStage stage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resumeId;
  final String? coverLetter;

  /// Present when selected with `jobs(*)`.
  final Job? job;

  factory JobApplication.fromJson(Json j) => JobApplication(
    id: j['id'] as String,
    jobId: j['job_id'] as String,
    candidateId: j['candidate_id'] as String,
    stage: ApplicationStage.fromDb(j['stage'] as String?),
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
    resumeId: j['resume_id'] as String?,
    coverLetter: j['cover_letter'] as String?,
    job: j['jobs'] is Map ? Job.fromJson((j['jobs'] as Map).cast()) : null,
  );
}

/// Mirrors public.notifications.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body,
    this.data = const {},
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final Json data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Json j) => AppNotification(
    id: j['id'] as String,
    type: j['type'] as String,
    title: j['title'] as String,
    body: j['body'] as String?,
    data: ((j['data'] as Map?) ?? const {}).cast<String, dynamic>(),
    createdAt: DateTime.parse(j['created_at'] as String),
    readAt: _date(j['read_at']),
  );
}

DateTime? _day(Object? v) => v == null ? null : DateTime.parse(v as String);

/// "2026-10-19" for date columns.
String? dbDate(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

/// Mirrors public.educations.
@immutable
class Education {
  const Education({
    required this.id,
    required this.institution,
    this.degree,
    this.field,
    this.startDate,
    this.endDate,
    this.grade,
  });

  final String id;
  final String institution;
  final String? degree;
  final String? field;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? grade;

  factory Education.fromJson(Json j) => Education(
    id: j['id'] as String,
    institution: j['institution'] as String,
    degree: j['degree'] as String?,
    field: j['field'] as String?,
    startDate: _day(j['start_date']),
    endDate: _day(j['end_date']),
    grade: j['grade'] as String?,
  );

  Json toRow() => {
    'institution': institution.trim(),
    'degree': _blank(degree),
    'field': _blank(field),
    'start_date': dbDate(startDate),
    'end_date': dbDate(endDate),
    'grade': _blank(grade),
  };
}

/// Mirrors public.experiences.
@immutable
class Experience {
  const Experience({
    required this.id,
    required this.company,
    required this.title,
    this.startDate,
    this.endDate,
    this.description,
  });

  final String id;
  final String company;
  final String title;
  final DateTime? startDate;

  /// Null while this is the current role.
  final DateTime? endDate;
  final String? description;

  factory Experience.fromJson(Json j) => Experience(
    id: j['id'] as String,
    company: j['company'] as String,
    title: j['title'] as String,
    startDate: _day(j['start_date']),
    endDate: _day(j['end_date']),
    description: j['description'] as String?,
  );

  Json toRow() => {
    'company': company.trim(),
    'title': title.trim(),
    'start_date': dbDate(startDate),
    'end_date': dbDate(endDate),
    'description': _blank(description),
  };
}

String? _blank(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

/// Mirrors public.resumes.
@immutable
class Resume {
  const Resume({
    required this.id,
    required this.storagePath,
    required this.fileName,
    required this.isPrimary,
    required this.createdAt,
  });

  final String id;
  final String storagePath;
  final String fileName;
  final bool isPrimary;
  final DateTime createdAt;

  factory Resume.fromJson(Json j) => Resume(
    id: j['id'] as String,
    storagePath: j['storage_path'] as String,
    fileName: j['file_name'] as String,
    isPrimary: j['is_primary'] as bool? ?? false,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

/// One row of public.application_events (the application timeline).
@immutable
class ApplicationEvent {
  const ApplicationEvent({
    required this.id,
    required this.toStage,
    required this.createdAt,
    this.fromStage,
    this.note,
  });

  final int id;
  final ApplicationStage? fromStage;
  final ApplicationStage toStage;
  final DateTime createdAt;
  final String? note;

  factory ApplicationEvent.fromJson(Json j) => ApplicationEvent(
    id: (j['id'] as num).toInt(),
    fromStage: j['from_stage'] == null
        ? null
        : ApplicationStage.fromDb(j['from_stage'] as String),
    toStage: ApplicationStage.fromDb(j['to_stage'] as String?),
    createdAt: DateTime.parse(j['created_at'] as String),
    note: j['note'] as String?,
  );
}

/// Candidate view of an interview (public.candidate_interviews: no private
/// notes or feedback).
@immutable
class Interview {
  const Interview({
    required this.id,
    required this.applicationId,
    required this.jobId,
    required this.scheduledAt,
    required this.durationMin,
    required this.mode,
    required this.status,
    this.meetingUrl,
    this.location,
    this.notes,
  });

  final String id;
  final String applicationId;
  final String jobId;
  final DateTime scheduledAt;
  final int durationMin;
  final InterviewMode mode;
  final InterviewStatus status;
  final String? meetingUrl;
  final String? location;

  /// Hiring-team notes; never present on the candidate's view.
  final String? notes;

  DateTime get endsAt => scheduledAt.add(Duration(minutes: durationMin));

  /// Accepts the candidate view (job_id column) and the employer query
  /// (`applications(job_id)` embedded).
  factory Interview.fromJson(Json j) => Interview(
    id: j['id'] as String,
    applicationId: j['application_id'] as String,
    jobId: (j['job_id'] ?? (j['applications'] as Map?)?['job_id']) as String,
    scheduledAt: DateTime.parse(j['scheduled_at'] as String),
    durationMin: (j['duration_min'] as num?)?.toInt() ?? 45,
    mode: InterviewMode.fromDb(j['mode'] as String?),
    status: InterviewStatus.fromDb(j['status'] as String?),
    meetingUrl: j['meeting_url'] as String?,
    location: j['location'] as String?,
    notes: j['notes'] as String?,
  );
}

/// Mirrors public.offers.
@immutable
class Offer {
  const Offer({
    required this.id,
    required this.applicationId,
    required this.status,
    this.salary,
    this.currency,
    this.salaryPeriod,
    this.startDate,
    this.letterPath,
    this.expiresAt,
    this.respondedAt,
  });

  final String id;
  final String applicationId;
  final OfferStatus status;
  final double? salary;
  final String? currency;
  final SalaryPeriod? salaryPeriod;
  final DateTime? startDate;
  final String? letterPath;
  final DateTime? expiresAt;
  final DateTime? respondedAt;

  bool get awaitingReply => status == OfferStatus.issued;

  factory Offer.fromJson(Json j) => Offer(
    id: j['id'] as String,
    applicationId: j['application_id'] as String,
    status: OfferStatus.fromDb(j['status'] as String?),
    salary: _num(j['salary']),
    currency: j['currency'] as String?,
    salaryPeriod: SalaryPeriod.fromDbOrNull(j['salary_period'] as String?),
    startDate: _day(j['start_date']),
    letterPath: j['letter_path'] as String?,
    expiresAt: _date(j['expires_at']),
    respondedAt: _date(j['responded_at']),
  );
}

/// A teammate (public.company_members + their profile).
@immutable
class CompanyMember {
  const CompanyMember({
    required this.userId,
    required this.role,
    required this.displayName,
    required this.email,
  });

  final String userId;
  final MemberRole role;
  final String displayName;
  final String email;

  factory CompanyMember.fromJson(Json j) {
    final p = (j['profiles'] as Map?) ?? const {};
    return CompanyMember(
      userId: j['user_id'] as String,
      role: MemberRole.fromDb(j['member_role'] as String?),
      displayName: (p['display_name'] as String?) ?? 'Teammate',
      email: (p['email'] as String?) ?? '',
    );
  }
}

/// Mirrors public.company_invites.
@immutable
class CompanyInvite {
  const CompanyInvite({
    required this.id,
    required this.companyId,
    required this.email,
    required this.role,
    required this.createdAt,
    this.companyName,
  });

  final String id;
  final String companyId;
  final String email;
  final MemberRole role;
  final DateTime createdAt;

  /// Present when selected with `companies(name)`.
  final String? companyName;

  factory CompanyInvite.fromJson(Json j) => CompanyInvite(
    id: j['id'] as String,
    companyId: j['company_id'] as String,
    email: j['email'] as String,
    role: MemberRole.fromDb(j['member_role'] as String?),
    createdAt: DateTime.parse(j['created_at'] as String),
    companyName: (j['companies'] as Map?)?['name'] as String?,
  );
}

/// Result of public.company_hiring_stats.
@immutable
class HiringStats {
  const HiringStats({
    required this.stages,
    required this.jobs,
    required this.applicationsByWeek,
    this.avgDaysToHire,
  });

  final Map<ApplicationStage, int> stages;
  final Map<String, int> jobs;
  final List<({DateTime week, int count})> applicationsByWeek;
  final double? avgDaysToHire;

  int get totalApplications => stages.values.fold(0, (a, b) => a + b);

  factory HiringStats.fromJson(Json j) => HiringStats(
    stages: {
      for (final e in ((j['stages'] as Map?) ?? const {}).entries)
        ApplicationStage.fromDb(e.key as String): (e.value as num).toInt(),
    },
    jobs: {
      for (final e in ((j['jobs'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    applicationsByWeek: [
      for (final w in (j['applications_by_week'] as List?) ?? const [])
        (
          week: DateTime.parse((w as Map)['week'] as String),
          count: (w['count'] as num).toInt(),
        ),
    ],
    avgDaysToHire: _num(j['avg_days_to_hire']),
  );
}

/// Mirrors public.reports.
@immutable
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String reporterId;

  /// job, company or profile.
  final String targetType;
  final String targetId;
  final String reason;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  factory Report.fromJson(Json j) => Report(
    id: j['id'] as String,
    reporterId: j['reporter_id'] as String,
    targetType: j['target_type'] as String,
    targetId: j['target_id'] as String,
    reason: j['reason'] as String,
    status: ReportStatus.fromDb(j['status'] as String?),
    createdAt: DateTime.parse(j['created_at'] as String),
    resolvedAt: _date(j['resolved_at']),
  );
}

/// Mirrors public.announcements.
@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.bodyMd,
    required this.audience,
    required this.createdAt,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String bodyMd;
  final AnnouncementAudience audience;
  final DateTime createdAt;
  final DateTime? publishedAt;

  bool get isPublished =>
      publishedAt != null && !publishedAt!.isAfter(DateTime.now());

  factory Announcement.fromJson(Json j) => Announcement(
    id: j['id'] as String,
    title: j['title'] as String,
    bodyMd: j['body_md'] as String,
    audience: AnnouncementAudience.fromDb(j['audience'] as String?),
    createdAt: DateTime.parse(j['created_at'] as String),
    publishedAt: _date(j['published_at']),
  );
}

/// One row of public.audit_logs.
@immutable
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.targetTable,
    required this.createdAt,
    this.actorId,
    this.actorRole,
    this.targetId,
    this.diff,
  });

  final int id;
  final String? actorId;
  final String? actorRole;
  final String action;
  final String targetTable;
  final String? targetId;
  final Object? diff;
  final DateTime createdAt;

  factory AuditEntry.fromJson(Json j) => AuditEntry(
    id: (j['id'] as num).toInt(),
    actorId: j['actor_id'] as String?,
    actorRole: j['actor_role'] as String?,
    action: j['action'] as String,
    targetTable: j['target_table'] as String,
    targetId: j['target_id'] as String?,
    diff: j['diff'],
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

/// Result of public.admin_platform_stats.
@immutable
class PlatformStats {
  const PlatformStats({
    required this.users,
    required this.companies,
    required this.jobs,
    required this.suspended,
    required this.applications,
    required this.openReports,
    required this.signupsByWeek,
  });

  final Map<String, int> users;
  final Map<String, int> companies;
  final Map<String, int> jobs;
  final int suspended;
  final int applications;
  final int openReports;
  final List<({DateTime week, int count})> signupsByWeek;

  static Map<String, int> _counts(Object? v) => {
    for (final e in ((v as Map?) ?? const {}).entries)
      e.key as String: (e.value as num).toInt(),
  };

  factory PlatformStats.fromJson(Json j) => PlatformStats(
    users: _counts(j['users']),
    companies: _counts(j['companies']),
    jobs: _counts(j['jobs']),
    suspended: (j['suspended'] as num?)?.toInt() ?? 0,
    applications: (j['applications'] as num?)?.toInt() ?? 0,
    openReports: (j['open_reports'] as num?)?.toInt() ?? 0,
    signupsByWeek: [
      for (final w in (j['signups_by_week'] as List?) ?? const [])
        (
          week: DateTime.parse((w as Map)['week'] as String),
          count: (w['count'] as num).toInt(),
        ),
    ],
  );
}

/// One row of public.ingest_runs (daily job imports).
/// Mirrors public.app_errors (admin-only error log).
@immutable
class AppErrorEntry {
  const AppErrorEntry({
    required this.source,
    required this.message,
    required this.createdAt,
    this.route,
    this.release,
  });

  final String source;
  final String message;
  final DateTime createdAt;
  final String? route;
  final String? release;

  factory AppErrorEntry.fromJson(Json j) => AppErrorEntry(
    source: j['source'] as String,
    message: j['message'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    route: j['route'] as String?,
    release: j['release'] as String?,
  );
}

@immutable
class IngestRun {
  const IngestRun({
    required this.source,
    required this.startedAt,
    required this.fetched,
    required this.inserted,
    required this.updated,
    required this.skipped,
    required this.closed,
    this.error,
  });

  final String source;
  final DateTime startedAt;
  final int fetched;
  final int inserted;
  final int updated;
  final int skipped;
  final int closed;
  final String? error;

  factory IngestRun.fromJson(Json j) => IngestRun(
    source: j['source'] as String,
    startedAt: DateTime.parse(j['started_at'] as String),
    fetched: (j['fetched'] as num).toInt(),
    inserted: (j['inserted'] as num).toInt(),
    updated: (j['updated'] as num).toInt(),
    skipped: (j['skipped'] as num).toInt(),
    closed: (j['closed'] as num).toInt(),
    error: j['error'] as String?,
  );
}

/// One row of public.news_articles: a headline imported from a career feed
/// (opens the publisher's site) or an article written by LuzHire admins
/// (read in the app at /news/:slug).
@immutable
class NewsItem {
  const NewsItem({
    required this.id,
    required this.source,
    required this.title,
    required this.publishedAt,
    this.isArticle = false,
    this.url,
    this.slug,
    this.summary,
    this.imageUrl,
    this.categories = const [],
    this.isFeatured = false,
    this.isPublished = true,
    this.bodyMd,
    this.authorName,
  });

  final String id;
  final String source;
  final String title;
  final DateTime publishedAt;
  final bool isArticle;
  final String? url;
  final String? slug;
  final String? summary;
  final String? imageUrl;
  final List<String> categories;
  final bool isFeatured;
  final bool isPublished;

  /// Articles only, and only when loaded for reading.
  final String? bodyMd;
  final String? authorName;

  /// Minutes to read an article (about 200 words a minute).
  int get readMinutes =>
      ((bodyMd ?? '').split(RegExp(r'\s+')).length / 200).ceil().clamp(1, 60);

  factory NewsItem.fromJson(Json j) => NewsItem(
    id: j['id'] as String,
    source: j['source'] as String,
    title: j['title'] as String,
    publishedAt: DateTime.parse(j['published_at'] as String),
    isArticle: j['kind'] == 'article',
    url: j['url'] as String?,
    slug: j['slug'] as String?,
    summary: j['summary'] as String?,
    imageUrl: j['image_url'] as String?,
    categories: _strings(j['categories']),
    isFeatured: j['is_featured'] == true,
    isPublished: (j['status'] as String? ?? 'published') == 'published',
    bodyMd: j['body_md'] as String?,
    authorName: j['author_name'] as String?,
  );

  @override
  bool operator ==(Object other) => other is NewsItem && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// A city with open roles (public.hiring_locations), for the hiring map.
@immutable
class HiringLocation {
  const HiringLocation({
    required this.cityId,
    required this.name,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.openJobs,
    this.state,
    this.companies = 0,
    this.events = 0,
  });

  final int cityId;
  final String name;
  final String? state;
  final String countryCode;
  final double latitude;
  final double longitude;
  final int openJobs;
  final int companies;

  /// Upcoming in-person or hybrid events in the city.
  final int events;

  /// "Pune, Maharashtra" or "Singapore, SG".
  String get label => '$name, ${state ?? countryCode}';

  factory HiringLocation.fromJson(Json j) => HiringLocation(
    cityId: (j['city_id'] as num).toInt(),
    name: j['name'] as String,
    state: j['state'] as String?,
    countryCode: j['country_code'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    openJobs: (j['open_jobs'] as num?)?.toInt() ?? 0,
    companies: (j['companies'] as num?)?.toInt() ?? 0,
    events: (j['events'] as num?)?.toInt() ?? 0,
  );
}

/// A hiring drive, hackathon, competition or webinar (public.events).
@immutable
class Opportunity {
  const Opportunity({
    required this.id,
    required this.slug,
    required this.kind,
    required this.status,
    required this.title,
    required this.organizerName,
    required this.mode,
    required this.startsAt,
    this.summary,
    this.descriptionMd = '',
    this.companyId,
    this.venue,
    this.location,
    this.endsAt,
    this.registrationDeadline,
    this.registrationUrl,
    this.eligibility,
    this.prize,
    this.teamMin = 1,
    this.teamMax = 1,
    this.capacity,
    this.registrationCount = 0,
  });

  final String id;
  final String slug;
  final EventKind kind;
  final EventStatus status;
  final String title;
  final String organizerName;
  final EventMode mode;
  final DateTime startsAt;
  final String? summary;
  final String descriptionMd;
  final String? companyId;
  final String? venue;
  final String? location;
  final DateTime? endsAt;
  final DateTime? registrationDeadline;

  /// Set when registration happens on the organiser's site.
  final String? registrationUrl;
  final String? eligibility;
  final String? prize;
  final int teamMin;
  final int teamMax;
  final int? capacity;
  final int registrationCount;

  bool get isTeamEvent => teamMax > 1;
  bool get registersInApp => registrationUrl == null;
  DateTime get closesAt => registrationDeadline ?? startsAt;
  bool isOpenAt(DateTime now) =>
      status == EventStatus.published && closesAt.isAfter(now) && !isFull;
  bool get isFull => capacity != null && registrationCount >= capacity!;

  factory Opportunity.fromJson(Json j) => Opportunity(
    id: j['id'] as String,
    slug: j['slug'] as String,
    kind: EventKind.fromDb(j['kind'] as String?),
    status: EventStatus.fromDb(j['status'] as String?),
    title: j['title'] as String,
    organizerName: j['organizer_name'] as String,
    mode: EventMode.fromDb(j['mode'] as String?),
    startsAt: DateTime.parse(j['starts_at'] as String),
    summary: j['summary'] as String?,
    descriptionMd: (j['description_md'] as String?) ?? '',
    companyId: j['company_id'] as String?,
    venue: j['venue'] as String?,
    location: j['location_text'] as String?,
    endsAt: _date(j['ends_at']),
    registrationDeadline: _date(j['registration_deadline']),
    registrationUrl: j['registration_url'] as String?,
    eligibility: j['eligibility'] as String?,
    prize: j['prize'] as String?,
    teamMin: (j['team_min'] as num?)?.toInt() ?? 1,
    teamMax: (j['team_max'] as num?)?.toInt() ?? 1,
    capacity: (j['capacity'] as num?)?.toInt(),
    registrationCount: (j['registration_count'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) => other is Opportunity && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Someone registered for an event (public.event_registrants).
@immutable
class EventRegistrant {
  const EventRegistrant({
    required this.userId,
    required this.name,
    required this.email,
    required this.registeredAt,
    this.headline,
    this.teamName,
  });
  final String userId;
  final String name;
  final String email;
  final DateTime registeredAt;
  final String? headline;
  final String? teamName;

  factory EventRegistrant.fromJson(Json j) => EventRegistrant(
    userId: j['user_id'] as String,
    name: j['display_name'] as String,
    email: j['email'] as String,
    registeredAt: DateTime.parse(j['registered_at'] as String),
    headline: j['headline'] as String?,
    teamName: j['team_name'] as String?,
  );
}
