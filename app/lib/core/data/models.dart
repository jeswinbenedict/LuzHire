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
  });

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

  bool get isVerified => verification == Verification.verified;

  factory Company.fromJson(Json j) => Company(
    id: j['id'] as String,
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
    this.avatarPath,
    this.links = const {},
    this.profileCompletion = 0,
  });

  final String id;
  final AppRole role;
  final String email;
  final String displayName;
  final String? headline;
  final String? bio;
  final String? location;
  final String? avatarPath;
  final Map<String, String> links;
  final int profileCompletion;

  factory Profile.fromJson(Json j) => Profile(
    id: j['id'] as String,
    role: AppRole.fromDb(j['role'] as String?),
    email: j['email'] as String,
    displayName: j['display_name'] as String,
    headline: j['headline'] as String?,
    bio: j['bio'] as String?,
    location: j['location'] as String?,
    avatarPath: j['avatar_path'] as String?,
    links: ((j['links'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k as String, '$v'),
    ),
    profileCompletion: (j['profile_completion'] as num?)?.toInt() ?? 0,
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
