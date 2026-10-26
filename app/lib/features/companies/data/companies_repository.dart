import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/jobs_repository.dart' show notConfigured;

/// Public company directory (FR-06): LuzHire employers plus the companies
/// behind imported jobs (`company_directory`). RLS hides rejected companies.
class CompaniesRepository {
  CompaniesRepository(this._db);
  final SupabaseClient _db;

  /// One page of hiring companies, most open roles first; [query] matches
  /// anywhere in the name.
  Future<List<Company>> list({
    String query = '',
    int offset = 0,
    int limit = 24,
  }) => guardDb(() async {
    var filter = _db.from('company_directory').select();
    final q = query.trim().replaceAll(RegExp(r'[%_\\]'), '');
    if (q.isNotEmpty) filter = filter.ilike('name', '%$q%');
    final rows = await filter
        .order('open_jobs', ascending: false)
        .order('name', ascending: true)
        .order('slug', ascending: true)
        .range(offset, offset + limit - 1);
    return [for (final r in rows) Company.fromJson(r)];
  });

  /// A LuzHire company profile, or else an imported company.
  Future<Company?> bySlug(String slug) => guardDb(() async {
    final row =
        await _db.from('companies').select().eq('slug', slug).maybeSingle() ??
        await _db
            .from('company_directory')
            .select()
            .eq('slug', slug)
            .eq('is_external', true)
            .maybeSingle();
    return row == null ? null : Company.fromJson(row);
  });

  Future<Company?> byId(String id) => guardDb(() async {
    final row = await _db.from('companies').select().eq('id', id).maybeSingle();
    return row == null ? null : Company.fromJson(row);
  });

  /// The feed logo of an imported company, or the public URL of a logo in
  /// the `company-media` bucket.
  String? logoUrl(Company company) =>
      company.externalLogoUrl ??
      (company.logoPath == null
          ? null
          : _db.storage.from('company-media').getPublicUrl(company.logoPath!));
}

final companiesRepositoryProvider = Provider<CompaniesRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return CompaniesRepository(ref.watch(supabaseClientProvider));
});
