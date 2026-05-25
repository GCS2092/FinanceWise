import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/wallets_screen.dart';
import '../screens/financial_goals_screen.dart';
import '../screens/wallet_form_screen.dart';
import '../screens/transaction_form_screen.dart';
import '../screens/financial_goal_form_screen.dart';
import '../screens/category_form_screen.dart';
import '../screens/budgets_screen.dart';
import '../screens/budget_form_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/payment_reminders_screen.dart';
import '../screens/payment_reminder_form_screen.dart';

// Configuration du router avec guards
final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // Désactivé temporairement pour permettre au bouton retour de fonctionner
    // La logique d'authentification est gérée dans le SplashScreen
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) => const TransactionsScreen(),
    ),
    GoRoute(
      path: '/budgets',
      builder: (context, state) => const BudgetsScreen(),
    ),
    GoRoute(
      path: '/wallets',
      builder: (context, state) => const WalletsScreen(),
    ),
    GoRoute(
      path: '/financial-goals',
      builder: (context, state) => const FinancialGoalsScreen(),
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoriesScreen(),
    ),
    GoRoute(
      path: '/payment-reminders',
      builder: (context, state) => const PaymentRemindersScreen(),
    ),
    GoRoute(
      path: '/wallet-form',
      builder: (context, state) {
        final wallet = state.extra as Map<String, dynamic>?;
        return WalletFormScreen(wallet: wallet);
      },
    ),
    GoRoute(
      path: '/transaction-form',
      builder: (context, state) {
        final transaction = state.extra as Map<String, dynamic>?;
        return TransactionFormScreen(transaction: transaction);
      },
    ),
    GoRoute(
      path: '/financial-goal-form',
      builder: (context, state) {
        final financialGoal = state.extra as Map<String, dynamic>?;
        return FinancialGoalFormScreen(financialGoal: financialGoal);
      },
    ),
    GoRoute(
      path: '/category-form',
      builder: (context, state) {
        final category = state.extra as Map<String, dynamic>?;
        return CategoryFormScreen(category: category);
      },
    ),
    GoRoute(
      path: '/budget-form',
      builder: (context, state) {
        final budget = state.extra as Map<String, dynamic>?;
        return BudgetFormScreen(budget: budget);
      },
    ),
    GoRoute(
      path: '/payment-reminder-form',
      builder: (context, state) {
        final paymentReminder = state.extra as Map<String, dynamic>?;
        return PaymentReminderFormScreen(paymentReminder: paymentReminder);
      },
    ),
  ],
);