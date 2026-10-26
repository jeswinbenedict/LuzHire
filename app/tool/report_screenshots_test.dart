// Screenshots of the signed-in screens for the project report, rendered with
// the app's fonts and fictional demo data (the public screens are captured
// from the live site; see docs/screenshots/README.md).
//
// Not part of `flutter test` (it lives outside test/). Regenerate with:
//   flutter test tool/report_screenshots_test.dart --update-goldens
@Tags(['screenshots'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/core/theme/theme_mode_provider.dart';

import '../test/support/admin_fakes.dart';
import '../test/support/candidate_fakes.dart';
import '../test/support/employer_fakes.dart';
import '../test/support/fakes.dart';
import '../test/support/job_fakes.dart';

class _Dark extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.dark;
}

class _Light extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in manifest.cast<Map<String, dynamic>>()) {
    final family = (f['family'] as String).split('/').last;
    final loader = FontLoader(family);
    for (final a in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(a['asset'] as String));
    }
    await loader.load();
  }
}

final _t0 = DateTime(2026, 10, 19, 10);

/// A candidate part-way through a search: a fuller profile, three
/// applications at different stages and an interview coming up.
Future<CandidateFakes> _candidate() async {
  final f = CandidateFakes();
  f.profile.profile = const Profile(
    id: 'candidate-1',
    role: AppRole.candidate,
    email: 'asha.verma@example.com',
    displayName: 'Asha Verma',
    headline: 'Flutter developer · 3 years',
    location: 'Bengaluru, IN',
    phone: '+91 98450 00000',
  );
  for (final s in ['Flutter', 'Dart', 'Firebase', 'REST APIs']) {
    await f.profile.addSkill('candidate-1', s);
  }
  await f.resumes.upload('candidate-1', 'Asha-Verma-CV.pdf', Uint8List(10));
  final a1 = (await f.applications.apply(
    candidateId: 'candidate-1',
    jobId: 'job-1',
  )).id;
  final a2 = (await f.applications.apply(
    candidateId: 'candidate-1',
    jobId: 'job-2',
  )).id;
  await f.applications.apply(candidateId: 'candidate-1', jobId: 'job-3');
  f.applications.setStage(a1, ApplicationStage.technicalInterview);
  f.applications.setStage(a2, ApplicationStage.shortlisted);
  f.applications.interviewList.add(
    Interview(
      id: 'int-1',
      applicationId: a1,
      jobId: 'job-1',
      scheduledAt: DateTime.now().add(const Duration(days: 2, hours: 2)),
      durationMin: 45,
      mode: InterviewMode.video,
      status: InterviewStatus.scheduled,
      meetingUrl: 'https://meet.example.com/luzhire-demo',
    ),
  );
  f.notifications.push(
    AppNotification(
      id: 'n1',
      type: 'interview.scheduled',
      title: 'Interview scheduled',
      body: 'Nimbus Labs booked a video interview for Flutter Developer 1.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
  );
  f.notifications.push(
    AppNotification(
      id: 'n2',
      type: 'application.stage',
      title: 'You were shortlisted',
      body: 'Flutter Developer 2 at Nimbus Labs moved to Shortlisted.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  );
  return f;
}

/// An employer with three open roles and applicants spread across the
/// pipeline, with fictional names.
FakeEmployerRepository _employer() {
  final repo = FakeEmployerRepository(verified: true);
  final job = repo.seedJob(title: 'Flutter Developer', count: 9);
  repo
    ..seedJob(title: 'Backend Engineer', count: 4)
    ..seedJob(title: 'Product Designer', count: 2);
  const people = [
    ('Aarav Sharma', 'Flutter developer · 2 years', ApplicationStage.applied),
    ('Diya Nair', 'Mobile engineer at a fintech', ApplicationStage.applied),
    ('Kabir Mehta', 'Final-year B.Tech, CSE', ApplicationStage.underReview),
    (
      'Ishaan Rao',
      'Android and Flutter, 4 years',
      ApplicationStage.underReview,
    ),
    ('Meera Iyer', 'Flutter developer · 3 years', ApplicationStage.shortlisted),
    ('Rohan Gupta', 'Full-stack, Dart and Go', ApplicationStage.assessment),
    (
      'Sana Qureshi',
      'Senior Flutter engineer',
      ApplicationStage.technicalInterview,
    ),
    ('Vikram Joshi', 'Mobile lead · 6 years', ApplicationStage.hrInterview),
    ('Ananya Das', 'Flutter developer · 5 years', ApplicationStage.offerIssued),
  ];
  final mine = [
    for (final a in repo.apps)
      if (a.jobId == job.id) a,
  ];
  for (var i = 0; i < mine.length && i < people.length; i++) {
    final a = mine[i];
    final (name, headline, stage) = people[i];
    repo.profilesById[a.candidateId] = Profile(
      id: a.candidateId,
      role: AppRole.candidate,
      email: '${name.split(' ').first.toLowerCase()}@example.com',
      displayName: name,
      headline: headline,
    );
    repo.apps[repo.apps.indexOf(a)] = JobApplication(
      id: a.id,
      jobId: a.jobId,
      candidateId: a.candidateId,
      stage: stage,
      createdAt: _t0.subtract(Duration(days: i)),
      updatedAt: _t0,
    );
  }
  return repo;
}

void main() {
  setUpAll(_loadFonts);

  final shots = <(String, String, AppRole, double, double, bool)>[
    ('08-candidate-dashboard', '/me', AppRole.candidate, 1440, 1300, false),
    (
      '08-candidate-dashboard-phone',
      '/me',
      AppRole.candidate,
      390,
      1700,
      false,
    ),
    ('08-candidate-dashboard-dark', '/me', AppRole.candidate, 1440, 1300, true),
    (
      '09-application-tracker',
      '/me/applications',
      AppRole.candidate,
      1440,
      1000,
      false,
    ),
    (
      '10-employer-pipeline',
      '/employer/pipeline?job=job-1',
      AppRole.employer,
      1440,
      900,
      false,
    ),
    (
      '10-employer-pipeline-phone',
      '/employer/pipeline?job=job-1',
      AppRole.employer,
      390,
      1000,
      false,
    ),
    (
      '10-employer-pipeline-dark',
      '/employer/pipeline?job=job-1',
      AppRole.employer,
      1440,
      900,
      true,
    ),
    (
      '11-job-editor',
      '/employer/jobs/new',
      AppRole.employer,
      1440,
      1100,
      false,
    ),
    (
      '12-employer-analytics',
      '/employer/analytics',
      AppRole.employer,
      1440,
      800,
      false,
    ),
    ('13-admin-overview', '/admin', AppRole.admin, 1440, 1000, false),
    ('14-admin-audit-log', '/admin/audit', AppRole.admin, 1440, 900, false),
  ];

  for (final (name, path, role, w, h, dark) in shots) {
    testWidgets(name, (tester) async {
      final candidate = await _candidate();
      final admin = FakeAdminRepository();
      await pumpLuzHire(
        tester,
        location: path,
        size: Size(w, h),
        gateway: FakeAuthGateway(
          signedIn: FakeAccount(
            uid: '${role.dbValue}-1',
            email: '${role.dbValue}@example.com',
            password: 'demo-only',
            name: switch (role) {
              AppRole.candidate => 'Asha Verma',
              AppRole.employer => 'Meera Nair',
              AppRole.admin => 'LuzHire Admin',
            },
            role: role,
          ),
        ),
        overrides: [
          ...jobBoardOverrides(),
          ...candidate.overrides,
          ...employerOverrides(_employer()),
          ...adminOverrides(admin, FakeGovernanceRepository(admin)),
          themeModeProvider.overrideWith(dark ? _Dark.new : _Light.new),
        ],
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../docs/screenshots/$name.png'),
      );
    });
  }
}
