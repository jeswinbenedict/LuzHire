import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/jobs_repository.dart' show notConfigured;

/// Candidate-side access to applications, interviews and offers. Every rule
/// (duplicates, deadlines, stage transitions, who may answer an offer) is
/// enforced in Postgres; this layer only shapes data and turns errors into
/// readable messages.
class ApplicationsRepository {
  ApplicationsRepository(this._db);
  final SupabaseClient _db;

  Future<JobApplication> apply({
    required String candidateId,
    required String jobId,
    String? resumeId,
    String? coverLetter,
  }) => guardDb(() async {
    final row = await _db
        .from('applications')
        .insert({
          'candidate_id': candidateId,
          'job_id': jobId,
          'resume_id': ?resumeId,
          if (coverLetter != null && coverLetter.trim().isNotEmpty)
            'cover_letter': coverLetter.trim(),
        })
        .select()
        .single();
    return JobApplication.fromJson(row);
  });

  /// Live list of the candidate's applications, newest first (FR-08).
  /// Stage changes by the employer arrive through Realtime.
  Stream<List<JobApplication>> watchMine(String candidateId) => _db
      .from('applications')
      .stream(primaryKey: ['id'])
      .eq('candidate_id', candidateId)
      .order('created_at')
      .map(
        (rows) => [for (final r in rows.reversed) JobApplication.fromJson(r)],
      );

  /// Stage history, oldest first.
  Future<List<ApplicationEvent>> events(String applicationId) =>
      guardDb(() async {
        final rows = await _db
            .from('application_events')
            .select()
            .eq('application_id', applicationId)
            .order('created_at');
        return [for (final r in rows) ApplicationEvent.fromJson(r)];
      });

  Future<void> withdraw(String applicationId) => guardDb(
    () => _db
        .from('applications')
        .update({'stage': ApplicationStage.withdrawn.dbValue})
        .eq('id', applicationId),
  );

  /// Interviews without the hiring team's private notes, soonest first.
  Future<List<Interview>> interviews() => guardDb(() async {
    final rows = await _db
        .from('candidate_interviews')
        .select()
        .order('scheduled_at');
    return [for (final r in rows) Interview.fromJson(r)];
  });

  Future<List<Offer>> offers() => guardDb(() async {
    final rows = await _db
        .from('offers')
        .select()
        .order('created_at', ascending: false);
    return [for (final r in rows) Offer.fromJson(r)];
  });

  /// Accepting also marks the application as hired (database trigger).
  Future<void> respondToOffer(String offerId, {required bool accept}) =>
      guardDb(
        () => _db
            .from('offers')
            .update({
              'status': (accept ? OfferStatus.accepted : OfferStatus.declined)
                  .dbValue,
              'responded_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', offerId),
      );

  Future<String> offerLetterUrl(String path) => guardDb(
    () => _db.storage.from('offer-letters').createSignedUrl(path, 600),
  );
}

final applicationsRepositoryProvider = Provider<ApplicationsRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return ApplicationsRepository(ref.watch(supabaseClientProvider));
});
