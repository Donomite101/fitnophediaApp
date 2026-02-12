import 'package:flutter/material.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/member/diet/screens/daily_diet_plan_screen.dart';
import '../features/member/notifications/member_notification.dart';
import '../features/member/profile/MemberProfileScreen.dart';
import '../features/member/profile/my_team_screen.dart';
import '../features/member/profile/terms_conditions_screen.dart';
import '../features/onboarding/gym_onboarding_screen.dart';
import '../features/onboarding/approval_waiting_screen.dart';
import '../features/gym_owner/app_subscription/gym_owner_subscription_screen.dart';
import '../features/workout/presentation/screens/exercise_detail_screen.dart';
import '../features/super_admin/super_admin_dashboard.dart';
import '../features/gym_owner/gym_owner_dashboard.dart';
import '../features/member/dashboard/member_dashboard_screen.dart';
import '../features/member/Subscriptions/member_renewal_subscription.dart';
import '../features/member/profile/member_subscription_details_screen.dart';
import '../features/auth/member_set_password_screen.dart';
import '../features/member/profile/member_profile_setup_screen.dart';
import '../features/workout/presentation/screens/exercise_library_screen.dart';
import '../features/workout/presentation/screens/workout_create_screen.dart';
import '../features/workout/presentation/screens/workout_home_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';
  static const String approvalWaiting = '/approval-waiting';
  static const String subscriptionPlans = '/subscription-plans';
  static const String superAdminDashboard = '/super-admin-dashboard';
  static const String gymOwnerDashboard = '/gym-owner-dashboard';
  static const String memberSetPassword = '/memberSetPassword';
  static const subscribe = '/subscribe';
  static const String memberDashboard = '/memberDashboard';
  static const String memberSubscription = '/memberSubscription';
  static const String memberProfileSetup = '/memberProfileSetup';
  static const String memberNotifications = '/memberNotifications';
  static const subscriptionInactive = '/subscription-inactive';
  static const awaitingApproval = '/awaitingApproval';
  static const String workoutPlan = '/workoutPlan';
  static const String dietPlanner = '/dietPlanner';
  static const String memberProfile = '/memberProfile';
  static const String memberSubscriptionDetails = '/memberSubscriptionDetails';
  static const String termsConditions = '/termsConditions';
  static const String myTeam = '/MyTeamScreen';
  static const exerciseLibrary = "/exerciseLibrary";
  static const exerciseDetail = "/exerciseDetail";
  static const createWorkout = "/createWorkout";
  static const workoutHome = "/workoutHome";
  static const exerciseVideoPlayer = "/exerciseVideoPlayer";

  /// Centralized route generator used by MaterialApp.onGenerateRoute
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case onboarding:
        return MaterialPageRoute(builder: (_) => const GymOnboardingScreen());

      case approvalWaiting:
        return MaterialPageRoute(builder: (_) => const ApprovalWaitingScreen());

      case subscriptionPlans:
        return MaterialPageRoute(builder: (_) => const GymOwnerSubscriptionScreen());

      case superAdminDashboard:
        return MaterialPageRoute(builder: (_) => const SuperAdminDashboard());

      case gymOwnerDashboard:
        return MaterialPageRoute(builder: (_) => const GymOwnerDashboard());

      case memberDashboard:
        return MaterialPageRoute(builder: (_) => const MemberDashboardScreen());

      case memberSubscription:
        return MaterialPageRoute(builder: (_) => const MemberSubscriptionScreen());

      case memberNotifications:
        return MaterialPageRoute(builder: (_) => const MemberNotificationsScreen());

      case termsConditions:
        return MaterialPageRoute(builder: (_) => const TermsConditionsScreen());

      case myTeam:
        return MaterialPageRoute(builder: (_) => const MyTeamScreen());

    // -------------------------------------------------------
    // WORKOUT MODULE ROUTES
    // -------------------------------------------------------

      case exerciseLibrary:
        return MaterialPageRoute(
          builder: (_) => const ExerciseLibraryScreen(),
        );

      case workoutHome:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => WorkoutHomeScreen(
              gymId: args?['gymId'] ?? '',
              memberId: args?['memberId'] ?? '',
            ),
          );
        }

      case exerciseDetail:
        {
          final args = settings.arguments as Map<String, dynamic>?;

          return MaterialPageRoute(
            builder: (_) => ExerciseDetailScreen(
              exercise: args?['exercise'],
              gymId: args?['gymId'] ?? '',
              memberId: args?['memberId'] ?? '',
              isPremade: args?['isPremade'] ?? false,
            ),
          );
        }
      case memberSubscriptionDetails: // Add this case
        {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (_) => MemberSubscriptionDetailsScreen(
                gymId: args['gymId'],
                memberId: args['memberId'],
              ),
            );
          } else {
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
        }
      case createWorkout:
        return MaterialPageRoute(
          builder: (_) => const CreateWorkoutScreen(),
        );

      // case exerciseVideoPlayer:
      //   {
      //     final url = settings.arguments as String?;
      //     return MaterialPageRoute(
      //       builder: (_) => ExerciseVideoPlayerScreen(
      //         videoUrl: url ?? '',
      //       ),
      //     );
      //   }

      case dietPlanner:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (_) => DailyDietPlanScreen(
                gymId: args['gymId'],
                memberId: args['memberId'],
              ),
            );
          } else {
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
        }

      case memberProfile: // ✅ Added this case
        {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (_) => MemberProfileScreen(
                gymId: args['gymId'],
                memberId: args['memberId'],
              ),
            );
          } else {
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
        }

      case memberSetPassword:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (_) => MemberSetPasswordScreen(memberRecord: args),
            );
          } else {
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
        }

      case memberProfileSetup:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (_) => MemberProfileSetupScreen(args: args),
            );
          } else {
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
        }

      case awaitingApproval:
        return MaterialPageRoute(builder: (_) => const ApprovalWaitingScreen());

      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}