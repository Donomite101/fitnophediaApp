// core/constants/app_constants.dart
class AppConstants {
  static const String appName = 'Gym Management';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String gymsCollection = 'gyms';
  static const String ticketsCollection = 'tickets';
  static const String subscriptionsCollection = 'subscriptions';

  // User Roles
  static const String roleSuperAdmin = 'superadmin';
  static const String roleGymOwner = 'gym_owner';
  static const String roleTrainer = 'trainer';
  static const String roleMember = 'member';

  // Gym Status
  static const String gymStatusPending = 'pending';
  static const String gymStatusApproved = 'approved';
  static const String gymStatusRejected = 'rejected';
  static const String gymStatusSuspended = 'suspended';

  // Ticket Status
  static const String ticketStatusOpen = 'open';
  static const String ticketStatusInProgress = 'in_progress';
  static const String ticketStatusResolved = 'resolved';
  static const String ticketStatusClosed = 'closed';

  // All Roles List (for dropdowns)
  static const List<String> allUserRoles = [
    roleSuperAdmin,
    roleGymOwner,
    roleTrainer,
    roleMember,
  ];
}