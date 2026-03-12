import 'package:flutter/material.dart';
import 'package:mobo_event/features/splash/splash_screen.dart';
import 'package:mobo_event/core/theme/app_theme.dart';
import 'package:mobo_event/core/theme/theme_provider.dart';
import 'package:mobo_event/features/event/services/event_detailed_services.dart';
import 'package:mobo_event/features/home/services/home_services.dart';
import 'package:mobo_event/features/questions/providers/questions_provider.dart';
import 'package:mobo_event/features/questions/services/question_service.dart';
import 'package:mobo_event/features/registration/services/registration_services.dart';
import 'package:mobo_event/features/schedule_activity/provider/event_activity_provider.dart';
import 'package:mobo_event/features/schedule_activity/services/event_activity_services.dart';
import 'package:mobo_event/features/scheduler/provider/mail_scheduler_provider.dart';
import 'package:mobo_event/features/scheduler/services/mail_scheduler_services.dart';
import 'package:provider/provider.dart';
import 'core/const/keys/global_keys.dart';
import 'core/providers/logout_view_model.dart';
import 'core/services/session_service.dart';
import 'features/company/providers/company_provider.dart';
import 'features/event/provider/event_detailed_provider.dart';
import 'features/home/providers/home_provider.dart';
import 'features/login/providers/login_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/registration/provider/registration_provider.dart';
import 'features/review/services/review_service.dart';
import 'features/settings/providers/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => LogoutViewModel()),
        ChangeNotifierProvider(
          create: (_) => HomeProvider(services: HomeServices()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              EventActivityProvider(services: EventActivityServices()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              EventDetailedProvider(services: EventDetailedServices()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              MailSchedulerProvider(services: MailSchedulerServices()),
        ),
        ChangeNotifierProvider(
          create: (_) => QuestionsProvider(services: QuestionService()),
        ),
        ChangeNotifierProvider(
          create: (_) => RegistrationProvider(services: RegistrationServices()),
        ),

        ChangeNotifierProvider<LoginProvider>(create: (_) => LoginProvider()),
        ChangeNotifierProvider<SessionService>.value(
          value: SessionService.instance,
        ),

        /// Provide CompanyProvider globally and initialize companies on app start
        ChangeNotifierProvider(
          create: (_) {
            final p = CompanyProvider();

            /// Kick off initial load from server; will show loading in selector
            p.initialize();
            return p;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// This widget is the root of your application.

  @override
  void initState() {
    super.initState();

    /// Track app open for review system after a delay to ensure activity is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        ReviewService().trackAppOpen();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'mobo events',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: provider.themeMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        );
      },
    );
  }
}
