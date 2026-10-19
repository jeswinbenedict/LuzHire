import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../candidate/data/profile_repository.dart' show slugify;
import '../../jobs/data/jobs_repository.dart' show notConfigured;

/// Editable job fields (the database fills slug, company name, counters,
/// published_at and moderation status).
class JobDraft {
  JobDraft({
    this.id,
    required this.companyId,
    this.title = '',
    this.summary = '',
    this.descriptionMd = '',
    this.employmentType = EmploymentType.fullTime,
    this.experienceLevel,
    this.workplace = WorkplaceType.onsite,
    this.location = '',
    this.salaryMin,
    this.salaryMax,
    this.salaryCurrency = 'INR',
    this.salaryPeriod = SalaryPeriod.year,
    this.responsibilities = const [],
    this.qualifications = const [],
    this.benefits = const [],
    this.deadline,
    this.skills = const [],
  });

  factory JobDraft.fromJob(Job j, {List<String> skills = const []}) => JobDraft(
    id: j.id,
    companyId: j.companyId ?? '',
    title: j.title,
    summary: j.summary ?? '',
    descriptionMd: j.descriptionMd,
    employmentType: j.employmentType,
    experienceLevel: j.experienceLevel,
    workplace: j.workplace,
    location: j.location ?? '',
    salaryMin: j.salaryMin,
    salaryMax: j.salaryMax,
    salaryCurrency: j.salaryCurrency ?? 'INR',
    salaryPeriod: j.salaryPeriod ?? SalaryPeriod.year,
    responsibilities: j.responsibilities,
    qualifications: j.qualifications,
    benefits: j.benefits,
    deadline: j.deadline,
    skills: skills,
  );

  final String? id;
  final String companyId;
  String title;
  String summary;
  String descriptionMd;
  EmploymentType employmentType;
  ExperienceLevel? experienceLevel;
  WorkplaceType workplace;
  String location;
  double? salaryMin;
  double? salaryMax;
  String salaryCurrency;
  SalaryPeriod salaryPeriod;
  List<String> responsibilities;
  List<String> qualifications;
  List<String> benefits;
  DateTime? deadline;
  List<String> skills;

  bool get hasSalary => salaryMin != null || salaryMax != null;

  Json toRow() => {
    'company_id': companyId,
    'company_name': '', // filled by the database from the company
    'title': title.trim(),
    'summary': summary.trim().isEmpty ? null : summary.trim(),
    'description_md': descriptionMd.trim(),
    'employment_type': employmentType.dbValue,
    'experience_level': experienceLevel?.dbValue,
    'workplace': workplace.dbValue,
    'location_text': location.trim().isEmpty ? null : location.trim(),
    'salary_min': salaryMin,
    'salary_max': salaryMax,
    'salary_currency': hasSalary ? salaryCurrency : null,
    'salary_period': hasSalary ? salaryPeriod.dbValue : null,
    'responsibilities': _clean(responsibilities),
    'qualifications': _clean(qualifications),
    'benefits': _clean(benefits),
    'deadline': dbDate(deadline),
  };

  /// A [Job] for the live card preview.
  Job preview(String companyName) => Job(
    id: id ?? 'preview',
    slug: 'preview',
    title: title.trim().isEmpty ? 'Job title' : title.trim(),
    companyName: companyName,
    companyId: companyId,
    employmentType: employmentType,
    experienceLevel: experienceLevel,
    workplace: workplace,
    status: JobStatus.draft,
    location: location.trim().isEmpty ? null : location.trim(),
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    salaryCurrency: hasSalary ? salaryCurrency : null,
    salaryPeriod: hasSalary ? salaryPeriod : null,
    summary: summary,
    descriptionMd: descriptionMd,
    responsibilities: _clean(responsibilities),
    qualifications: _clean(qualifications),
    benefits: _clean(benefits),
    deadline: deadline,
    publishedAt: DateTime.now(),
  );

  static List<String> _clean(List<String> v) => [
    for (final s in v)
      if (s.trim().isNotEmpty) s.trim(),
  ];
}

/// A candidate as the hiring team sees them (only after they applied).
class CandidateDetail {
  const CandidateDetail({
    required this.profile,
    required this.educations,
    required this.experiences,
    required this.skills,
  });
  final Profile profile;
  final List<Education> educations;
  final List<Experience> experiences;
  final List<String> skills;
}

/// Everything the employer workspace reads and writes. Permissions (owner /
/// recruiter / viewer, verification, stage rules) are enforced by Postgres.
class EmployerRepository {
  EmployerRepository(this._db);
  final SupabaseClient _db;

  // ---------------------------------------------------------- companies

  /// Companies the user belongs to, with their role, oldest first.
  Future<List<({Company company, MemberRole role})>> myCompanies(String uid) =>
      guardDb(() async {
        final rows = await _db
            .from('company_members')
            .select('member_role, created_at, companies(*)')
            .eq('user_id', uid)
            .order('created_at');
        return [
          for (final r in rows)
            if (r['companies'] is Map)
              (
                company: Company.fromJson((r['companies'] as Map).cast()),
                role: MemberRole.fromDb(r['member_role'] as String?),
              ),
        ];
      });

  Future<Company> createCompany(String uid, Json fields) => guardDb(() async {
    final row = await _db
        .from('companies')
        .insert({'owner_id': uid, ...fields})
        .select()
        .single();
    return Company.fromJson(row);
  });

  Future<void> updateCompany(String id, Json fields) =>
      guardDb(() => _db.from('companies').update(fields).eq('id', id));

  /// unverified/rejected → pending (the only change owners may make).
  Future<void> requestVerification(String id) => guardDb(
    () => _db
        .from('companies')
        .update({'verification': Verification.pending.dbValue})
        .eq('id', id),
  );

  Future<void> uploadLogo(
    String companyId,
    String fileName,
    Uint8List bytes, {
    String? previousPath,
  }) => guardDb(() async {
    final ext = fileName.split('.').last.toLowerCase();
    const types = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
    };
    final type = types[ext];
    if (type == null) throw const AppFailure('Use PNG, JPEG, WebP or SVG.');
    if (bytes.length > 5 * 1024 * 1024) {
      throw const AppFailure('That image is larger than 5 MB.');
    }
    final path =
        '$companyId/logo-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage
        .from('company-media')
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type));
    await _db.from('companies').update({'logo_path': path}).eq('id', companyId);
    if (previousPath != null) {
      await _db.storage.from('company-media').remove([previousPath]);
    }
  });

  String logoUrl(String path) =>
      _db.storage.from('company-media').getPublicUrl(path);

  // ---------------------------------------------------------- team

  Future<List<CompanyMember>> members(String companyId) => guardDb(() async {
    final rows = await _db
        .from('company_members')
        .select('user_id, member_role, profiles(display_name, email)')
        .eq('company_id', companyId)
        .order('created_at');
    return [for (final r in rows) CompanyMember.fromJson(r)];
  });

  Future<void> setMemberRole(String companyId, String userId, MemberRole r) =>
      guardDb(
        () => _db
            .from('company_members')
            .update({'member_role': r.dbValue})
            .match({'company_id': companyId, 'user_id': userId}),
      );

  Future<void> removeMember(String companyId, String userId) => guardDb(
    () => _db.from('company_members').delete().match({
      'company_id': companyId,
      'user_id': userId,
    }),
  );

  /// Invitations visible to the user: the company's (owners) and their own.
  Future<List<CompanyInvite>> invites() => guardDb(() async {
    final rows = await _db
        .from('company_invites')
        .select('*, companies(name)')
        .order('created_at');
    return [for (final r in rows) CompanyInvite.fromJson(r)];
  });

  Future<void> invite(String companyId, String email, MemberRole role) =>
      guardDb(
        () => _db.from('company_invites').insert({
          'company_id': companyId,
          'email': email.trim().toLowerCase(),
          'member_role': role.dbValue,
        }),
      );

  /// Revoke (owner) or decline (invitee).
  Future<void> deleteInvite(String id) =>
      guardDb(() => _db.from('company_invites').delete().eq('id', id));

  Future<void> acceptInvite(String id) => guardDb(
    () => _db.rpc<dynamic>('accept_company_invite', params: {'invite': id}),
  );

  // ---------------------------------------------------------- jobs

  /// All of the company's jobs (drafts included), newest first.
  Future<List<Job>> companyJobs(String companyId) => guardDb(() async {
    final rows = await _db
        .from('jobs')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return [for (final r in rows) Job.fromJson(r)];
  });

  /// Inserts or updates [draft] with [status] and replaces its skills.
  /// Returns the saved job: publishing an unverified company's job comes
  /// back as `pending_review`.
  Future<Job> saveJob(JobDraft draft, JobStatus status) => guardDb(() async {
    final row = {...draft.toRow(), 'status': status.dbValue};
    final saved = draft.id == null
        ? await _db.from('jobs').insert(row).select().single()
        : await _db
              .from('jobs')
              .update(row..remove('company_id'))
              .eq('id', draft.id!)
              .select()
              .single();
    final job = Job.fromJson(saved);
    await _setSkills(job.id, draft.skills);
    return job;
  });

  Future<void> setJobStatus(String jobId, JobStatus status) => guardDb(
    () => _db.from('jobs').update({'status': status.dbValue}).eq('id', jobId),
  );

  Future<void> deleteJob(String jobId) =>
      guardDb(() => _db.from('jobs').delete().eq('id', jobId));

  Future<void> _setSkills(String jobId, List<String> names) async {
    final ids = <int>[];
    for (final name in names.map((n) => n.trim()).where((n) => n.isNotEmpty)) {
      final slug = slugify(name);
      if (slug.isEmpty) continue;
      final found = await _db
          .from('skills')
          .select('id')
          .eq('slug', slug)
          .maybeSingle();
      final id =
          found?['id'] ??
          (await _db
              .from('skills')
              .insert({'name': name, 'slug': slug})
              .select('id')
              .single())['id'];
      ids.add((id as num).toInt());
    }
    await _db.from('job_skills').delete().eq('job_id', jobId);
    if (ids.isNotEmpty) {
      await _db.from('job_skills').insert([
        for (final id in ids.toSet()) {'job_id': jobId, 'skill_id': id},
      ]);
    }
  }

  // ---------------------------------------------------------- pipeline

  /// Live applications for one job (Realtime, filtered by RLS).
  Stream<List<JobApplication>> watchJobApplications(String jobId) => _db
      .from('applications')
      .stream(primaryKey: ['id'])
      .eq('job_id', jobId)
      .order('created_at')
      .map((rows) => [for (final r in rows) JobApplication.fromJson(r)]);

  /// Applications across [jobIds], newest first.
  Future<List<JobApplication>> applicationsFor(Iterable<String> jobIds) =>
      guardDb(() async {
        if (jobIds.isEmpty) return const [];
        final rows = await _db
            .from('applications')
            .select()
            .inFilter('job_id', jobIds.toSet().toList())
            .order('created_at', ascending: false);
        return [for (final r in rows) JobApplication.fromJson(r)];
      });

  /// Allowed stage moves (public.application_stage_transitions).
  Future<Map<ApplicationStage, Set<ApplicationStage>>> transitions() =>
      guardDb(() async {
        final rows = await _db.from('application_stage_transitions').select();
        final map = <ApplicationStage, Set<ApplicationStage>>{};
        for (final r in rows) {
          (map[ApplicationStage.fromDb(r['from_stage'] as String)] ??= {}).add(
            ApplicationStage.fromDb(r['to_stage'] as String),
          );
        }
        return map;
      });

  Future<void> moveStage(String applicationId, ApplicationStage stage) =>
      guardDb(
        () => _db
            .from('applications')
            .update({'stage': stage.dbValue})
            .eq('id', applicationId),
      );

  /// Profiles of applicants, by id (visible only after they applied).
  Future<Map<String, Profile>> profiles(Iterable<String> ids) =>
      guardDb(() async {
        if (ids.isEmpty) return const {};
        final rows = await _db
            .from('profiles')
            .select()
            .inFilter('id', ids.toSet().toList());
        return {for (final r in rows) r['id'] as String: Profile.fromJson(r)};
      });

  Future<CandidateDetail> candidate(String uid) => guardDb(() async {
    final p = await _db.from('profiles').select().eq('id', uid).single();
    final edu = await _db
        .from('educations')
        .select()
        .eq('user_id', uid)
        .order('start_date', ascending: false, nullsFirst: true);
    final exp = await _db
        .from('experiences')
        .select()
        .eq('user_id', uid)
        .order('start_date', ascending: false, nullsFirst: true);
    final skills = await _db
        .from('profile_skills')
        .select('skills(name)')
        .eq('user_id', uid);
    return CandidateDetail(
      profile: Profile.fromJson(p),
      educations: [for (final r in edu) Education.fromJson(r)],
      experiences: [for (final r in exp) Experience.fromJson(r)],
      skills: [
        for (final r in skills)
          if ((r['skills'] as Map?)?['name'] case final String n) n,
      ],
    );
  });

  /// Signed link to the resume attached to [application].
  Future<String?> resumeUrl(JobApplication application) => guardDb(() async {
    if (application.resumeId == null) return null;
    final r = await _db
        .from('resumes')
        .select('storage_path')
        .eq('id', application.resumeId!)
        .maybeSingle();
    if (r == null) return null;
    return _db.storage
        .from('resumes')
        .createSignedUrl(r['storage_path'] as String, 600);
  });

  Future<List<ApplicationEvent>> events(String applicationId) =>
      guardDb(() async {
        final rows = await _db
            .from('application_events')
            .select()
            .eq('application_id', applicationId)
            .order('created_at');
        return [for (final r in rows) ApplicationEvent.fromJson(r)];
      });

  // ---------------------------------------------------------- interviews / offers

  /// Interviews for the given applications, soonest first.
  Future<List<Interview>> interviews(Iterable<String> applicationIds) =>
      guardDb(() async {
        if (applicationIds.isEmpty) return const [];
        final rows = await _db
            .from('interviews')
            .select('*, applications(job_id)')
            .inFilter('application_id', applicationIds.toSet().toList())
            .order('scheduled_at');
        return [for (final r in rows) Interview.fromJson(r)];
      });

  Future<void> scheduleInterview({
    required String applicationId,
    required DateTime at,
    required int durationMin,
    required InterviewMode mode,
    String? meetingUrl,
    String? location,
    String? notes,
  }) => guardDb(
    () => _db.from('interviews').insert({
      'application_id': applicationId,
      'scheduled_at': at.toUtc().toIso8601String(),
      'duration_min': durationMin,
      'mode': mode.dbValue,
      'meeting_url': (meetingUrl ?? '').trim().isEmpty
          ? null
          : meetingUrl!.trim(),
      'location': (location ?? '').trim().isEmpty ? null : location!.trim(),
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
    }),
  );

  Future<void> setInterviewStatus(String id, InterviewStatus status) => guardDb(
    () =>
        _db.from('interviews').update({'status': status.dbValue}).eq('id', id),
  );

  /// Offers for the given applications.
  Future<List<Offer>> offers(Iterable<String> applicationIds) =>
      guardDb(() async {
        if (applicationIds.isEmpty) return const [];
        final rows = await _db
            .from('offers')
            .select()
            .inFilter('application_id', applicationIds.toSet().toList());
        return [for (final r in rows) Offer.fromJson(r)];
      });

  /// Creates the offer (the database moves the application to "Offer
  /// issued" and notifies the candidate), with an optional PDF letter.
  Future<void> makeOffer({
    required String applicationId,
    required double salary,
    required String currency,
    required SalaryPeriod period,
    DateTime? startDate,
    DateTime? expiresAt,
    ({String name, Uint8List bytes})? letter,
  }) => guardDb(() async {
    String? letterPath;
    if (letter != null) {
      letterPath =
          '$applicationId/offer-${DateTime.now().millisecondsSinceEpoch}.pdf';
      await _db.storage
          .from('offer-letters')
          .uploadBinary(
            letterPath,
            letter.bytes,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );
    }
    await _db.from('offers').insert({
      'application_id': applicationId,
      'salary': salary,
      'currency': currency,
      'salary_period': period.dbValue,
      'start_date': dbDate(startDate),
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'letter_path': letterPath,
    });
  });

  Future<void> withdrawOffer(String offerId) => guardDb(
    () => _db
        .from('offers')
        .update({'status': OfferStatus.withdrawn.dbValue})
        .eq('id', offerId),
  );

  // ---------------------------------------------------------- analytics

  Future<HiringStats> stats(String companyId) => guardDb(() async {
    final json = await _db.rpc<dynamic>(
      'company_hiring_stats',
      params: {'company': companyId},
    );
    return HiringStats.fromJson((json as Map).cast());
  });
}

final employerRepositoryProvider = Provider<EmployerRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return EmployerRepository(ref.watch(supabaseClientProvider));
});
