import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/jobs_repository.dart' show notConfigured;

/// The candidate's own profile, education, experience and skills (FR-03).
/// Completion is computed by Postgres triggers; clients never write it.
class ProfileRepository {
  ProfileRepository(this._db);
  final SupabaseClient _db;

  Future<Profile> fetch(String uid) => guardDb(() async {
    final row = await _db.from('profiles').select().eq('id', uid).single();
    return Profile.fromJson(row);
  });

  Future<void> updateBasics(
    String uid, {
    required String displayName,
    String? headline,
    String? bio,
    String? location,
    String? phone,
    Map<String, String> links = const {},
  }) => guardDb(
    () => _db
        .from('profiles')
        .update({
          'display_name': displayName.trim(),
          'headline': _blank(headline),
          'bio': _blank(bio),
          'location': _blank(location),
          'phone': _blank(phone),
          'links': {
            for (final e in links.entries)
              if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
          },
        })
        .eq('id', uid),
  );

  /// Uploads a PNG/JPEG/WebP (≤ 2 MB) to the public `avatars` bucket and
  /// replaces the previous picture.
  Future<void> uploadAvatar(
    String uid,
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
    };
    final type = types[ext];
    if (type == null) throw const AppFailure('Use a PNG, JPEG or WebP image.');
    if (bytes.length > 2 * 1024 * 1024) {
      throw const AppFailure('That image is larger than 2 MB.');
    }
    final path = '$uid/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage
        .from('avatars')
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type));
    await _db.from('profiles').update({'avatar_path': path}).eq('id', uid);
    if (previousPath != null) {
      await _db.storage.from('avatars').remove([previousPath]);
    }
  });

  String avatarUrl(String path) =>
      _db.storage.from('avatars').getPublicUrl(path);

  // ---------------------------------------------------------- education

  Future<List<Education>> educations(String uid) => guardDb(() async {
    final rows = await _db
        .from('educations')
        .select()
        .eq('user_id', uid)
        .order('start_date', ascending: false, nullsFirst: true);
    return [for (final r in rows) Education.fromJson(r)];
  });

  Future<void> saveEducation(String uid, Education e) => guardDb(
    () => e.id.isEmpty
        ? _db.from('educations').insert({'user_id': uid, ...e.toRow()})
        : _db.from('educations').update(e.toRow()).eq('id', e.id),
  );

  Future<void> deleteEducation(String id) =>
      guardDb(() => _db.from('educations').delete().eq('id', id));

  // ---------------------------------------------------------- experience

  Future<List<Experience>> experiences(String uid) => guardDb(() async {
    final rows = await _db
        .from('experiences')
        .select()
        .eq('user_id', uid)
        .order('start_date', ascending: false, nullsFirst: true);
    return [for (final r in rows) Experience.fromJson(r)];
  });

  Future<void> saveExperience(String uid, Experience e) => guardDb(
    () => e.id.isEmpty
        ? _db.from('experiences').insert({'user_id': uid, ...e.toRow()})
        : _db.from('experiences').update(e.toRow()).eq('id', e.id),
  );

  Future<void> deleteExperience(String id) =>
      guardDb(() => _db.from('experiences').delete().eq('id', id));

  // ---------------------------------------------------------- skills

  Future<List<({int id, String name})>> skills(String uid) => guardDb(() async {
    final rows = await _db
        .from('profile_skills')
        .select('skill_id, skills(name)')
        .eq('user_id', uid);
    return [
      for (final r in rows)
        (
          id: (r['skill_id'] as num).toInt(),
          name: ((r['skills'] as Map?)?['name'] as String?) ?? '',
        ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  });

  /// Adds [name] to the profile, creating the skill if it is new.
  Future<void> addSkill(String uid, String name) => guardDb(() async {
    final clean = name.trim();
    final slug = slugify(clean);
    if (slug.isEmpty) throw const AppFailure('Enter a skill name.');
    // Matched by slug, the column Postgres keeps unique ("C" and "c" are one).
    final existing = await _db
        .from('skills')
        .select('id')
        .eq('slug', slug)
        .maybeSingle();
    final int id;
    if (existing != null) {
      id = (existing['id'] as num).toInt();
    } else {
      final created = await _db
          .from('skills')
          .insert({'name': clean, 'slug': slug})
          .select('id')
          .single();
      id = (created['id'] as num).toInt();
    }
    await _db.from('profile_skills').upsert({'user_id': uid, 'skill_id': id});
  });

  Future<void> removeSkill(String uid, int skillId) => guardDb(
    () => _db.from('profile_skills').delete().match({
      'user_id': uid,
      'skill_id': skillId,
    }),
  );
}

/// Mirrors `app.slugify` in SQL (lowercase, non-alphanumerics → "-").
String slugify(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String? _blank(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

/// Resumes in the private `resumes` bucket under `<uid>/` (FR-04).
class ResumeRepository {
  ResumeRepository(this._db);
  final SupabaseClient _db;

  static const maxBytes = 5 * 1024 * 1024;
  static const types = {
    'pdf': 'application/pdf',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  Future<List<Resume>> list(String uid) => guardDb(() async {
    final rows = await _db
        .from('resumes')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return [for (final r in rows) Resume.fromJson(r)];
  });

  /// Uploads a PDF/DOCX (≤ 5 MB). The first resume becomes the primary one.
  Future<Resume> upload(String uid, String fileName, Uint8List bytes) =>
      guardDb(() async {
        final ext = fileName.split('.').last.toLowerCase();
        final type = types[ext];
        if (type == null) {
          throw const AppFailure('Upload a PDF or Word (.docx) file.');
        }
        if (bytes.length > maxBytes) {
          throw const AppFailure('That file is larger than 5 MB.');
        }
        final safe = fileName
            .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
            .replaceAll(RegExp(r'_+'), '_');
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}-$safe';
        await _db.storage
            .from('resumes')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: type),
            );
        final hasAny = (await list(uid)).isNotEmpty;
        final row = await _db
            .from('resumes')
            .insert({
              'user_id': uid,
              'storage_path': path,
              'file_name': fileName,
              'is_primary': !hasAny,
            })
            .select()
            .single();
        return Resume.fromJson(row);
      });

  Future<void> setPrimary(String resumeId) => guardDb(
    () => _db.rpc<void>('set_primary_resume', params: {'resume': resumeId}),
  );

  /// Deletes the row, then the file. Applications keep working: their
  /// resume link is set to null by the foreign key.
  Future<void> delete(Resume r) => guardDb(() async {
    await _db.from('resumes').delete().eq('id', r.id);
    await _db.storage.from('resumes').remove([r.storagePath]);
  });

  /// Short-lived link for viewing a private resume.
  Future<String> signedUrl(String storagePath) => guardDb(
    () => _db.storage.from('resumes').createSignedUrl(storagePath, 600),
  );
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final resumeRepositoryProvider = Provider<ResumeRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return ResumeRepository(ref.watch(supabaseClientProvider));
});
