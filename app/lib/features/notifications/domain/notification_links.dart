import '../../../core/data/enums.dart';
import '../../../core/data/models.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

String? _id(Json data, String key) {
  final v = data[key];
  return v is String && _uuid.hasMatch(v) ? v : null;
}

/// The screen a notification opens. Mirrors linkFor() in
/// api/_lib/notify/messages.ts, which builds the links in pushes and emails.
String notificationLink(String type, Json data, AppRole role) {
  final application = _id(data, 'application_id');
  final job = _id(data, 'job_id');
  switch (role) {
    case AppRole.candidate:
      if (application != null) return '/me/applications/$application';
      if (type.startsWith('interview.')) return '/me/interviews';
      return '/me/notifications';
    case AppRole.employer:
      if (type == 'application.new' || type == 'application.withdrawn') {
        return job == null
            ? '/employer/pipeline'
            : '/employer/pipeline?job=$job';
      }
      if (type.startsWith('offer.')) return '/employer/pipeline';
      if (type.startsWith('job.')) {
        return job == null ? '/employer/jobs' : '/employer/jobs/$job';
      }
      if (type.startsWith('company.')) return '/employer/company';
      return '/employer';
    case AppRole.admin:
      return '/admin';
  }
}
