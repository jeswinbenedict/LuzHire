import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/failures.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/features/candidate/data/applications_repository.dart';
import 'package:luzhire/features/candidate/data/profile_repository.dart';
import 'package:luzhire/features/notifications/data/notifications_repository.dart';

final _t0 = DateTime.utc(2026, 10, 19, 9);

/// Profile store that recomputes completion like app.recompute_completion.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({required this.resumes});
  final FakeResumeRepository resumes;

  Profile profile = const Profile(
    id: 'candidate-1',
    role: AppRole.candidate,
    email: 'candidate@example.com',
    displayName: 'Asha Verma',
  );
  final educationList = <Education>[];
  final experienceList = <Experience>[];
  final skillList = <({int id, String name})>[];
  int _ids = 0;

  void _recompute() {
    final p = profile;
    var score = 0;
    for (final ok in [
      (p.headline ?? '').isNotEmpty,
      (p.bio ?? '').isNotEmpty,
      (p.location ?? '').isNotEmpty,
      p.avatarPath != null,
      (p.phone ?? '').isNotEmpty,
      p.links.values.any((v) => v.isNotEmpty),
      educationList.isNotEmpty,
      experienceList.isNotEmpty,
      skillList.length >= 3,
      resumes.items.any((r) => r.isPrimary),
    ]) {
      if (ok) score += 10;
    }
    profile = Profile(
      id: p.id,
      role: p.role,
      email: p.email,
      displayName: p.displayName,
      headline: p.headline,
      bio: p.bio,
      location: p.location,
      phone: p.phone,
      avatarPath: p.avatarPath,
      links: p.links,
      profileCompletion: score,
    );
  }

  @override
  Future<Profile> fetch(String uid) async {
    _recompute();
    return profile;
  }

  @override
  Future<void> updateBasics(
    String uid, {
    required String displayName,
    String? headline,
    String? bio,
    String? location,
    String? phone,
    Map<String, String> links = const {},
  }) async {
    String? b(String? v) => (v ?? '').trim().isEmpty ? null : v!.trim();
    profile = Profile(
      id: profile.id,
      role: profile.role,
      email: profile.email,
      displayName: displayName.trim(),
      headline: b(headline),
      bio: b(bio),
      location: b(location),
      phone: b(phone),
      avatarPath: profile.avatarPath,
      links: {
        for (final e in links.entries)
          if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
      },
    );
    _recompute();
  }

  @override
  Future<void> uploadAvatar(
    String uid,
    String fileName,
    Uint8List bytes, {
    String? previousPath,
  }) async {}

  @override
  String avatarUrl(String path) => '';

  @override
  Future<List<Education>> educations(String uid) async => [...educationList];

  @override
  Future<void> saveEducation(String uid, Education e) async {
    educationList
      ..removeWhere((x) => x.id == e.id)
      ..add(
        Education(
          id: e.id.isEmpty ? 'edu-${++_ids}' : e.id,
          institution: e.institution,
          degree: e.degree,
          field: e.field,
          startDate: e.startDate,
          endDate: e.endDate,
          grade: e.grade,
        ),
      );
  }

  @override
  Future<void> deleteEducation(String id) async =>
      educationList.removeWhere((e) => e.id == id);

  @override
  Future<List<Experience>> experiences(String uid) async => [...experienceList];

  @override
  Future<void> saveExperience(String uid, Experience e) async {
    experienceList
      ..removeWhere((x) => x.id == e.id)
      ..add(
        Experience(
          id: e.id.isEmpty ? 'exp-${++_ids}' : e.id,
          company: e.company,
          title: e.title,
          startDate: e.startDate,
          endDate: e.endDate,
          description: e.description,
        ),
      );
  }

  @override
  Future<void> deleteExperience(String id) async =>
      experienceList.removeWhere((e) => e.id == id);

  @override
  Future<List<({int id, String name})>> skills(String uid) async => [
    ...skillList,
  ];

  @override
  Future<void> addSkill(String uid, String name) async {
    if (slugify(name).isEmpty) throw const AppFailure('Enter a skill name.');
    if (skillList.any((s) => slugify(s.name) == slugify(name))) return;
    skillList.add((id: ++_ids, name: name.trim()));
  }

  @override
  Future<void> removeSkill(String uid, int skillId) async =>
      skillList.removeWhere((s) => s.id == skillId);
}

class FakeResumeRepository implements ResumeRepository {
  final items = <Resume>[];

  @override
  Future<List<Resume>> list(String uid) async => [...items];

  @override
  Future<Resume> upload(String uid, String fileName, Uint8List bytes) async {
    final r = Resume(
      id: 'res-${items.length + 1}',
      storagePath: '$uid/$fileName',
      fileName: fileName,
      isPrimary: items.isEmpty,
      createdAt: _t0,
    );
    items.add(r);
    return r;
  }

  @override
  Future<void> setPrimary(String resumeId) async {
    for (var i = 0; i < items.length; i++) {
      final r = items[i];
      items[i] = Resume(
        id: r.id,
        storagePath: r.storagePath,
        fileName: r.fileName,
        isPrimary: r.id == resumeId,
        createdAt: r.createdAt,
      );
    }
  }

  @override
  Future<void> delete(Resume r) async => items.removeWhere((x) => x.id == r.id);

  @override
  Future<String> signedUrl(String storagePath) async =>
      'https://example.com/$storagePath';
}

/// Applications with a Realtime-like stream; [setStage] plays the employer.
class FakeApplicationsRepository implements ApplicationsRepository {
  final apps = <JobApplication>[];
  final eventsById = <String, List<ApplicationEvent>>{};
  final interviewList = <Interview>[];
  final offerList = <Offer>[];
  final _changes = StreamController<List<JobApplication>>.broadcast();
  int _events = 0;

  void _emit() => _changes.add([...apps.reversed]);

  void _event(String appId, ApplicationStage? from, ApplicationStage to) =>
      (eventsById[appId] ??= []).add(
        ApplicationEvent(
          id: ++_events,
          fromStage: from,
          toStage: to,
          createdAt: _t0.add(Duration(hours: _events)),
        ),
      );

  /// What the employer's pipeline would do.
  void setStage(String appId, ApplicationStage stage) {
    final i = apps.indexWhere((a) => a.id == appId);
    final a = apps[i];
    _event(appId, a.stage, stage);
    apps[i] = JobApplication(
      id: a.id,
      jobId: a.jobId,
      candidateId: a.candidateId,
      stage: stage,
      createdAt: a.createdAt,
      updatedAt: _t0.add(const Duration(days: 1)),
      resumeId: a.resumeId,
      coverLetter: a.coverLetter,
    );
    _emit();
  }

  @override
  Future<JobApplication> apply({
    required String candidateId,
    required String jobId,
    String? resumeId,
    String? coverLetter,
  }) async {
    if (apps.any((a) => a.jobId == jobId)) {
      throw const AppFailure(
        'This already exists — for example, you have already applied.',
      );
    }
    final a = JobApplication(
      id: 'app-${apps.length + 1}',
      jobId: jobId,
      candidateId: candidateId,
      stage: ApplicationStage.applied,
      createdAt: _t0,
      updatedAt: _t0,
      resumeId: resumeId,
      coverLetter: coverLetter,
    );
    apps.add(a);
    _event(a.id, null, ApplicationStage.applied);
    _emit();
    return a;
  }

  @override
  Stream<List<JobApplication>> watchMine(String candidateId) async* {
    yield [...apps.reversed];
    yield* _changes.stream;
  }

  @override
  Future<List<ApplicationEvent>> events(String applicationId) async => [
    ...?eventsById[applicationId],
  ];

  @override
  Future<void> withdraw(String applicationId) async =>
      setStage(applicationId, ApplicationStage.withdrawn);

  @override
  Future<List<Interview>> interviews() async => [...interviewList];

  @override
  Future<List<Offer>> offers() async => [...offerList];

  @override
  Future<void> respondToOffer(String offerId, {required bool accept}) async {
    final i = offerList.indexWhere((o) => o.id == offerId);
    final o = offerList[i];
    offerList[i] = Offer(
      id: o.id,
      applicationId: o.applicationId,
      status: accept ? OfferStatus.accepted : OfferStatus.declined,
      salary: o.salary,
      currency: o.currency,
      salaryPeriod: o.salaryPeriod,
      respondedAt: _t0,
    );
    if (accept) setStage(o.applicationId, ApplicationStage.hired);
  }

  @override
  Future<String> offerLetterUrl(String path) async =>
      'https://example.com/$path';
}

class FakeNotificationsRepository implements NotificationsRepository {
  final items = <AppNotification>[];
  final _changes = StreamController<List<AppNotification>>.broadcast();

  void push(AppNotification n) {
    items.insert(0, n);
    _changes.add([...items]);
  }

  @override
  Stream<List<AppNotification>> watch(String userId) async* {
    yield [...items];
    yield* _changes.stream;
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead(String userId) async {}

  @override
  Future<void> delete(String id) async {}
}

class CandidateFakes {
  final resumes = FakeResumeRepository();
  late final profile = FakeProfileRepository(resumes: resumes);
  final applications = FakeApplicationsRepository();
  final notifications = FakeNotificationsRepository();

  List<Override> get overrides => [
    profileRepositoryProvider.overrideWithValue(profile),
    resumeRepositoryProvider.overrideWithValue(resumes),
    applicationsRepositoryProvider.overrideWithValue(applications),
    notificationsRepositoryProvider.overrideWithValue(notifications),
  ];
}
