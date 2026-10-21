// Dart mirrors of the Postgres enums in supabase/migrations/.
// test/data_test.dart fails if the two ever drift apart.

import 'package:flutter/material.dart' show IconData, Icons;

/// Common contract: every enum maps to/from its database value.
mixin DbEnum on Enum {
  String get dbValue;
}

T _fromDb<T extends DbEnum>(List<T> values, String? raw, T fallback) {
  for (final v in values) {
    if (v.dbValue == raw) return v;
  }
  return fallback;
}

enum AppRole with DbEnum {
  candidate('candidate'),
  employer('employer'),
  admin('admin');

  const AppRole(this.dbValue);
  @override
  final String dbValue;
  static AppRole fromDb(String? v) => _fromDb(values, v, candidate);
}

enum JobStatus with DbEnum {
  draft('draft', 'Draft'),
  pendingReview('pending_review', 'Pending review'),
  published('published', 'Published'),
  closed('closed', 'Closed'),
  archived('archived', 'Archived'),
  rejected('rejected', 'Rejected');

  const JobStatus(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static JobStatus fromDb(String? v) => _fromDb(values, v, draft);
}

enum EmploymentType with DbEnum {
  fullTime('full_time', 'Full-time'),
  partTime('part_time', 'Part-time'),
  contract('contract', 'Contract'),
  internship('internship', 'Internship'),
  temporary('temporary', 'Temporary');

  const EmploymentType(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static EmploymentType fromDb(String? v) => _fromDb(values, v, fullTime);
}

enum ExperienceLevel with DbEnum {
  entry('entry', 'Entry level'),
  mid('mid', 'Mid level'),
  senior('senior', 'Senior'),
  lead('lead', 'Lead');

  const ExperienceLevel(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static ExperienceLevel? fromDbOrNull(String? v) =>
      v == null ? null : _fromDb(values, v, mid);
}

enum WorkplaceType with DbEnum {
  onsite('onsite', 'On-site'),
  remote('remote', 'Remote'),
  hybrid('hybrid', 'Hybrid');

  const WorkplaceType(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static WorkplaceType fromDb(String? v) => _fromDb(values, v, onsite);
}

enum SalaryPeriod with DbEnum {
  hour('hour', 'hour'),
  month('month', 'month'),
  year('year', 'year');

  const SalaryPeriod(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static SalaryPeriod? fromDbOrNull(String? v) =>
      v == null ? null : _fromDb(values, v, year);
}

/// Recruitment pipeline stages (FR-08). UI styling lives in luz_chips.dart.
enum ApplicationStage with DbEnum {
  applied('applied', 'Applied'),
  underReview('under_review', 'Under review'),
  shortlisted('shortlisted', 'Shortlisted'),
  assessment('assessment', 'Assessment'),
  technicalInterview('technical_interview', 'Technical interview'),
  hrInterview('hr_interview', 'HR interview'),
  finalReview('final_review', 'Final review'),
  offerIssued('offer_issued', 'Offer issued'),
  hired('hired', 'Hired'),
  rejected('rejected', 'Rejected'),
  withdrawn('withdrawn', 'Withdrawn');

  const ApplicationStage(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;

  bool get isTerminal => this == hired || this == rejected || this == withdrawn;
  static ApplicationStage fromDb(String? v) => _fromDb(values, v, applied);
}

enum Verification with DbEnum {
  unverified('unverified'),
  pending('pending'),
  verified('verified'),
  rejected('rejected');

  const Verification(this.dbValue);
  @override
  final String dbValue;
  static Verification fromDb(String? v) => _fromDb(values, v, unverified);
}

enum InterviewMode with DbEnum {
  video('video', 'Video call', Icons.videocam_outlined),
  phone('phone', 'Phone call', Icons.call_outlined),
  onsite('onsite', 'In person', Icons.apartment_outlined);

  const InterviewMode(this.dbValue, this.label, this.icon);
  @override
  final String dbValue;
  final String label;
  final IconData icon;
  static InterviewMode fromDb(String? v) => _fromDb(values, v, video);
}

enum InterviewStatus with DbEnum {
  scheduled('scheduled', 'Scheduled'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  noShow('no_show', 'Missed');

  const InterviewStatus(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static InterviewStatus fromDb(String? v) => _fromDb(values, v, scheduled);
}

enum OfferStatus with DbEnum {
  issued('issued', 'Awaiting your reply'),
  accepted('accepted', 'Accepted'),
  declined('declined', 'Declined'),
  withdrawn('withdrawn', 'Withdrawn'),
  expired('expired', 'Expired');

  const OfferStatus(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static OfferStatus fromDb(String? v) => _fromDb(values, v, issued);
}

enum MemberRole with DbEnum {
  owner('owner', 'Owner'),
  recruiter('recruiter', 'Recruiter'),
  viewer('viewer', 'Viewer');

  const MemberRole(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;

  /// Owners and recruiters can edit jobs, move candidates and book interviews.
  bool get canEdit => this != viewer;
  static MemberRole fromDb(String? v) => _fromDb(values, v, viewer);
}

enum AccountStatus with DbEnum {
  active('active', 'Active'),
  suspended('suspended', 'Suspended'),
  deleted('deleted', 'Deleted');

  const AccountStatus(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static AccountStatus fromDb(String? v) => _fromDb(values, v, active);
}

enum AnnouncementAudience with DbEnum {
  all('all', 'Everyone'),
  candidates('candidates', 'Candidates'),
  employers('employers', 'Employers');

  const AnnouncementAudience(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static AnnouncementAudience fromDb(String? v) => _fromDb(values, v, all);
}

enum ReportStatus with DbEnum {
  open('open', 'Open'),
  actioned('actioned', 'Actioned'),
  dismissed('dismissed', 'Dismissed');

  const ReportStatus(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static ReportStatus fromDb(String? v) => _fromDb(values, v, open);
}

/// Preference groups for notifications (public.notification_category).
enum NotificationCategory with DbEnum {
  applications(
    'applications',
    'Applications',
    'New applications, status changes and withdrawals',
    Icons.description_outlined,
  ),
  interviews(
    'interviews',
    'Interviews',
    'Interviews scheduled, moved or cancelled',
    Icons.event_outlined,
  ),
  offers(
    'offers',
    'Offers',
    'Offers and replies to offers',
    Icons.handshake_outlined,
  ),
  team('team', 'Team', 'Invitations and new teammates', Icons.group_outlined),
  account(
    'account',
    'Account and reviews',
    'Company and job reviews, report outcomes and test messages',
    Icons.verified_user_outlined,
  );

  const NotificationCategory(
    this.dbValue,
    this.label,
    this.description,
    this.icon,
  );
  @override
  final String dbValue;
  final String label;
  final String description;
  final IconData icon;
  static NotificationCategory fromDb(String? v) => _fromDb(values, v, account);

  /// The groups that can actually reach someone with [role].
  static List<NotificationCategory> forRole(AppRole role) => switch (role) {
    AppRole.candidate => const [applications, interviews, offers, account],
    AppRole.employer => const [applications, offers, team, account],
    AppRole.admin => values,
  };
}

enum PushPlatform with DbEnum {
  web('web'),
  android('android'),
  ios('ios');

  const PushPlatform(this.dbValue);
  @override
  final String dbValue;
}

enum DeliveryChannel with DbEnum {
  push('push'),
  email('email');

  const DeliveryChannel(this.dbValue);
  @override
  final String dbValue;
}

enum DeliveryStatus with DbEnum {
  sent('sent'),
  failed('failed'),
  skipped('skipped');

  const DeliveryStatus(this.dbValue);
  @override
  final String dbValue;
}

/// Mirrors public.event_kind. [isHiring] kinds are recruitment events.
enum EventKind with DbEnum {
  walkIn('walk_in', 'Walk-in drive', Icons.directions_walk, true),
  campusDrive('campus_drive', 'Campus drive', Icons.school_outlined, true),
  hiringChallenge(
    'hiring_challenge',
    'Hiring challenge',
    Icons.emoji_events_outlined,
    true,
  ),
  hackathon('hackathon', 'Hackathon', Icons.code, false),
  competition(
    'competition',
    'Competition',
    Icons.military_tech_outlined,
    false,
  ),
  webinar('webinar', 'Webinar', Icons.cast_for_education_outlined, false);

  const EventKind(this.dbValue, this.label, this.icon, this.isHiring);
  @override
  final String dbValue;
  final String label;
  final IconData icon;
  final bool isHiring;
  static EventKind fromDb(String? v) => _fromDb(values, v, walkIn);
}

enum EventMode with DbEnum {
  inPerson('in_person', 'In person', Icons.place_outlined),
  online('online', 'Online', Icons.wifi),
  hybrid('hybrid', 'Hybrid', Icons.sync_alt);

  const EventMode(this.dbValue, this.label, this.icon);
  @override
  final String dbValue;
  final String label;
  final IconData icon;
  static EventMode fromDb(String? v) => _fromDb(values, v, online);
}

enum EventStatus with DbEnum {
  draft('draft', 'Draft'),
  pendingReview('pending_review', 'Pending review'),
  published('published', 'Published'),
  cancelled('cancelled', 'Cancelled'),
  rejected('rejected', 'Rejected');

  const EventStatus(this.dbValue, this.label);
  @override
  final String dbValue;
  final String label;
  static EventStatus fromDb(String? v) => _fromDb(values, v, draft);
}
