import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';

/// Candidate-side access to applications. Every rule (duplicates, deadlines,
/// stage transitions) is enforced in Postgres; this layer only shapes data
/// and turns errors into readable messages.
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
  Stream<List<JobApplication>> watchMine(String candidateId) => _db
      .from('applications')
      .stream(primaryKey: ['id'])
      .eq('candidate_id', candidateId)
      .order('created_at')
      .map(
        (rows) => [for (final r in rows.reversed) JobApplication.fromJson(r)],
      );

  /// Applications with their jobs, for list screens.
  Future<List<JobApplication>> mineWithJobs(String candidateId) =>
      guardDb(() async {
        final rows = await _db
            .from('applications')
            .select('*, jobs(*)')
            .eq('candidate_id', candidateId)
            .order('created_at', ascending: false);
        return [for (final r in rows) JobApplication.fromJson(r)];
      });

  Future<void> withdraw(String applicationId) => guardDb(
    () => _db
        .from('applications')
        .update({'stage': ApplicationStage.withdrawn.dbValue})
        .eq('id', applicationId),
  );
}

final applicationsRepositoryProvider = Provider<ApplicationsRepository>(
  (ref) => ApplicationsRepository(ref.watch(supabaseClientProvider)),
);
