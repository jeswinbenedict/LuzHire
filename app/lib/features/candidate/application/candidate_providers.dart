import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../jobs/application/job_board_providers.dart';
import '../../jobs/data/jobs_repository.dart';
import '../../notifications/application/notification_providers.dart';
import '../../notifications/data/notifications_repository.dart';
import '../data/applications_repository.dart';
import '../data/profile_repository.dart';

export '../../notifications/application/notification_providers.dart'
    show myNotificationsProvider;

String _uid(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw const AppFailure('Sign in to see this page.', code: 'signed_out');
  }
  return uid;
}

// ---------------------------------------------------------------- profile

final myProfileProvider = FutureProvider.autoDispose<Profile>(
  (ref) => ref.watch(profileRepositoryProvider).fetch(_uid(ref)),
);

final myEducationsProvider = FutureProvider.autoDispose<List<Education>>(
  (ref) => ref.watch(profileRepositoryProvider).educations(_uid(ref)),
);

final myExperiencesProvider = FutureProvider.autoDispose<List<Experience>>(
  (ref) => ref.watch(profileRepositoryProvider).experiences(_uid(ref)),
);

final mySkillsProvider =
    FutureProvider.autoDispose<List<({int id, String name})>>(
      (ref) => ref.watch(profileRepositoryProvider).skills(_uid(ref)),
    );

final myResumesProvider = FutureProvider.autoDispose<List<Resume>>(
  (ref) => ref.watch(resumeRepositoryProvider).list(_uid(ref)),
);

// ---------------------------------------------------------------- applications

/// Live applications (Realtime): stage changes appear without a refresh.
final myApplicationsProvider = StreamProvider.autoDispose<List<JobApplication>>(
  (ref) => ref.watch(applicationsRepositoryProvider).watchMine(_uid(ref)),
);

/// Jobs for a set of applications, keyed by job id. [idsKey] is the sorted
/// job ids joined by commas, so it refetches only when the set changes.
final jobsByIdsProvider = FutureProvider.autoDispose
    .family<Map<String, Job>, String>((ref, idsKey) async {
      if (idsKey.isEmpty) return const {};
      final jobs = await ref
          .watch(jobsRepositoryProvider)
          .byIds(idsKey.split(','));
      return {for (final j in jobs) j.id: j};
    });

String jobIdsKey(Iterable<String> ids) =>
    (ids.toSet().toList()..sort()).join(',');

/// The candidate's application for [jobId], if any.
final myApplicationForJobProvider = Provider.autoDispose
    .family<JobApplication?, String>((ref, jobId) {
      final apps = ref.watch(myApplicationsProvider).value ?? const [];
      return apps.where((a) => a.jobId == jobId).firstOrNull;
    });

final applicationEventsProvider = FutureProvider.autoDispose
    .family<List<ApplicationEvent>, String>((ref, applicationId) {
      // Re-read the timeline whenever the live application list changes.
      ref.watch(myApplicationsProvider);
      return ref.watch(applicationsRepositoryProvider).events(applicationId);
    });

// ---------------------------------------------------------------- interviews / offers

/// Interviews and offers follow application and notification changes, so a
/// newly scheduled interview or issued offer shows up without a reload.
final myInterviewsProvider = FutureProvider.autoDispose<List<Interview>>((ref) {
  ref.watch(myApplicationsProvider);
  ref.watch(myNotificationsProvider);
  return ref.watch(applicationsRepositoryProvider).interviews();
});

final myOffersProvider = FutureProvider.autoDispose<List<Offer>>((ref) {
  ref.watch(myApplicationsProvider);
  ref.watch(myNotificationsProvider);
  return ref.watch(applicationsRepositoryProvider).offers();
});

// ---------------------------------------------------------------- actions

/// Writes from candidate screens. Each refreshes what it changed and throws
/// [AppFailure] with a readable message on failure.
class CandidateActions {
  CandidateActions(this._ref);
  final Ref _ref;

  String get _me {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) {
      throw const AppFailure('Sign in first.', code: 'signed_out');
    }
    return uid;
  }

  Future<void> saveBasics({
    required String displayName,
    String? headline,
    String? bio,
    String? location,
    String? phone,
    Map<String, String> links = const {},
  }) async {
    await _ref
        .read(profileRepositoryProvider)
        .updateBasics(
          _me,
          displayName: displayName,
          headline: headline,
          bio: bio,
          location: location,
          phone: phone,
          links: links,
        );
    _ref.invalidate(myProfileProvider);
  }

  Future<void> uploadAvatar(String fileName, Uint8List bytes) async {
    final previous = _ref.read(myProfileProvider).value?.avatarPath;
    await _ref
        .read(profileRepositoryProvider)
        .uploadAvatar(_me, fileName, bytes, previousPath: previous);
    _ref.invalidate(myProfileProvider);
  }

  Future<void> saveEducation(Education e) async {
    await _ref.read(profileRepositoryProvider).saveEducation(_me, e);
    _ref
      ..invalidate(myEducationsProvider)
      ..invalidate(myProfileProvider);
  }

  Future<void> deleteEducation(String id) async {
    await _ref.read(profileRepositoryProvider).deleteEducation(id);
    _ref
      ..invalidate(myEducationsProvider)
      ..invalidate(myProfileProvider);
  }

  Future<void> saveExperience(Experience e) async {
    await _ref.read(profileRepositoryProvider).saveExperience(_me, e);
    _ref
      ..invalidate(myExperiencesProvider)
      ..invalidate(myProfileProvider);
  }

  Future<void> deleteExperience(String id) async {
    await _ref.read(profileRepositoryProvider).deleteExperience(id);
    _ref
      ..invalidate(myExperiencesProvider)
      ..invalidate(myProfileProvider);
  }

  Future<void> addSkill(String name) async {
    await _ref.read(profileRepositoryProvider).addSkill(_me, name);
    _ref
      ..invalidate(mySkillsProvider)
      ..invalidate(myProfileProvider);
  }

  Future<void> removeSkill(int skillId) async {
    await _ref.read(profileRepositoryProvider).removeSkill(_me, skillId);
    _ref
      ..invalidate(mySkillsProvider)
      ..invalidate(myProfileProvider);
  }

  Future<Resume> uploadResume(String fileName, Uint8List bytes) async {
    final r = await _ref
        .read(resumeRepositoryProvider)
        .upload(_me, fileName, bytes);
    _ref
      ..invalidate(myResumesProvider)
      ..invalidate(myProfileProvider);
    return r;
  }

  Future<void> setPrimaryResume(String id) async {
    await _ref.read(resumeRepositoryProvider).setPrimary(id);
    _ref.invalidate(myResumesProvider);
  }

  Future<void> deleteResume(Resume r) async {
    await _ref.read(resumeRepositoryProvider).delete(r);
    _ref
      ..invalidate(myResumesProvider)
      ..invalidate(myProfileProvider);
  }

  Future<JobApplication> apply({
    required String jobId,
    String? resumeId,
    String? coverLetter,
  }) => _ref
      .read(applicationsRepositoryProvider)
      .apply(
        candidateId: _me,
        jobId: jobId,
        resumeId: resumeId,
        coverLetter: coverLetter,
      );

  Future<void> withdraw(String applicationId) =>
      _ref.read(applicationsRepositoryProvider).withdraw(applicationId);

  Future<void> respondToOffer(String offerId, {required bool accept}) async {
    await _ref
        .read(applicationsRepositoryProvider)
        .respondToOffer(offerId, accept: accept);
    _ref.invalidate(myOffersProvider);
  }

  Future<void> markNotificationRead(String id) =>
      _ref.read(notificationsRepositoryProvider).markRead(id);

  Future<void> markAllNotificationsRead() =>
      _ref.read(notificationsRepositoryProvider).markAllRead(_me);
}

final candidateActionsProvider = Provider<CandidateActions>(
  CandidateActions.new,
);
