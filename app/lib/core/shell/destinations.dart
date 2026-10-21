import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/enums.dart';
import 'shell_common.dart';

/// Public + candidate (Spotlight) destinations.
const spotlightDestinations = [
  LuzDestination(
    label: 'Home',
    path: '/',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    group: 'LuzHire',
  ),
  LuzDestination(
    label: 'Jobs',
    path: '/jobs',
    icon: Icons.work_outline,
    selectedIcon: Icons.work,
    group: 'LuzHire',
  ),
  LuzDestination(
    label: 'Events',
    path: '/events',
    icon: Icons.event_outlined,
    selectedIcon: Icons.event,
    group: 'LuzHire',
  ),
  LuzDestination(
    label: 'Companies',
    path: '/companies',
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment,
    group: 'LuzHire',
  ),
  LuzDestination(
    label: 'News',
    path: '/news',
    icon: Icons.newspaper_outlined,
    selectedIcon: Icons.newspaper,
    group: 'LuzHire',
  ),
  LuzDestination(
    label: 'My LuzHire',
    path: '/me',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    group: 'Candidate',
  ),
];

/// Candidate sub-pages (tabs inside /me).
const candidateDestinations = [
  LuzDestination(
    label: 'Dashboard',
    path: '/me',
    icon: Icons.space_dashboard_outlined,
    group: 'Candidate',
  ),
  LuzDestination(
    label: 'Applications',
    path: '/me/applications',
    icon: Icons.send_outlined,
    group: 'Candidate',
  ),
  LuzDestination(
    label: 'Saved jobs',
    path: '/me/saved',
    icon: Icons.bookmark_border,
    group: 'Candidate',
  ),
  LuzDestination(
    label: 'Interviews',
    path: '/me/interviews',
    icon: Icons.event_outlined,
    group: 'Candidate',
  ),
  LuzDestination(
    label: 'Profile & resume',
    path: '/me/profile',
    icon: Icons.badge_outlined,
    group: 'Candidate',
  ),
];

/// Employer Workspace destinations.
const employerDestinations = [
  LuzDestination(
    label: 'Overview',
    path: '/employer',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
    group: 'Employer',
  ),
  LuzDestination(
    label: 'Jobs',
    path: '/employer/jobs',
    icon: Icons.work_outline,
    selectedIcon: Icons.work,
    group: 'Employer',
  ),
  LuzDestination(
    label: 'Pipeline',
    path: '/employer/pipeline',
    icon: Icons.view_kanban_outlined,
    selectedIcon: Icons.view_kanban,
    group: 'Employer',
  ),
  LuzDestination(
    label: 'Interviews',
    path: '/employer/interviews',
    icon: Icons.event_outlined,
    selectedIcon: Icons.event,
    group: 'Employer',
  ),
  LuzDestination(
    label: 'Analytics',
    path: '/employer/analytics',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    group: 'Employer',
  ),
  LuzDestination(
    label: 'Events',
    path: '/employer/events',
    icon: Icons.event_outlined,
    selectedIcon: Icons.event,
    group: 'Employer',
  ),
  LuzDestination(
    label: 'Company & team',
    path: '/employer/company',
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment,
    group: 'Employer',
  ),
];

/// Admin Workspace destinations.
const adminDestinations = [
  LuzDestination(
    label: 'Overview',
    path: '/admin',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
    group: 'Admin',
  ),
  LuzDestination(
    label: 'Verification',
    path: '/admin/verification',
    icon: Icons.verified_outlined,
    selectedIcon: Icons.verified,
    group: 'Admin',
  ),
  LuzDestination(
    label: 'Moderation',
    path: '/admin/moderation',
    icon: Icons.gavel_outlined,
    selectedIcon: Icons.gavel,
    group: 'Admin',
  ),
  LuzDestination(
    label: 'Users',
    path: '/admin/users',
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    group: 'Admin',
  ),
  LuzDestination(
    label: 'Announcements',
    path: '/admin/announcements',
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign,
    group: 'Admin',
  ),
  LuzDestination(
    label: 'Events',
    path: '/admin/events',
    icon: Icons.event_outlined,
    selectedIcon: Icons.event,
    group: 'Admin',
  ),
  LuzDestination(
    label: 'News',
    path: '/admin/news',
    icon: Icons.newspaper_outlined,
    selectedIcon: Icons.newspaper,
    group: 'Admin',
  ),
  LuzDestination(
    label: 'Audit log',
    path: '/admin/audit',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    group: 'Admin',
  ),
];

const devDestinations = [
  LuzDestination(
    label: 'Design gallery',
    path: '/dev/gallery',
    icon: Icons.palette_outlined,
    group: 'Developer',
  ),
];

/// What the command menu offers: public pages, plus the areas [role] may
/// open (the router enforces the same rules). The design gallery is listed
/// only in debug builds.
List<LuzDestination> destinationsFor(AppRole? role) => [
  // "My LuzHire" (/me) is the candidate home; others don't get it.
  for (final d in spotlightDestinations)
    if (d.group != 'Candidate' || role == AppRole.candidate) d,
  if (role == AppRole.candidate) ...candidateDestinations,
  if (role == AppRole.employer || role == AppRole.admin)
    ...employerDestinations,
  if (role == AppRole.admin) ...adminDestinations,
  if (kDebugMode) ...devDestinations,
];
