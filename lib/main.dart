import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_preview/device_preview.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme.dart';
import 'core/localization/app_language.dart';
import 'features/splash/splash_screen.dart'; 
import 'core/network_service.dart';
import 'core/whatsapp/whatsapp_service.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguageService.initialize();
  
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Start WhatsApp background service
    WhatsAppService.instance.initialize();
  }

  await Supabase.initialize(
    url: 'https://etlxrdxldtobffzficxu.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );
  
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const TeaCollectionApp(),
    ),
  );
}

class TeaCollectionApp extends StatefulWidget {
  const TeaCollectionApp({super.key});

  @override
  State<TeaCollectionApp> createState() => _TeaCollectionAppState();
}

class _TeaCollectionAppState extends State<TeaCollectionApp> with WindowListener {
  
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isWindows) {
      windowManager.addListener(this);
    }
    
    // Initialize NetworkService on app start (uses IP checks to bypass DNS freeze on Windows)
    NetworkService().initialize(globalNavigatorKey);
  }

  @override
  void dispose() {
    if (!kIsWeb && Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // When the user clicks the close button (X), kill the Node server before closing
    if (!kIsWeb && Platform.isWindows) {
      WhatsAppService.instance.killServer();
    }
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLanguageService.currentLanguage,
      builder: (context, currentLang, _) {
        return MaterialApp(
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          navigatorKey: globalNavigatorKey,
          
          title: 'Smart Entry',
          theme: appTheme.copyWith(
            textTheme: GoogleFonts.notoSansSinhalaTextTheme(appTheme.textTheme),
            primaryTextTheme: GoogleFonts.notoSansSinhalaTextTheme(appTheme.primaryTextTheme),
          ),
          debugShowCheckedModeBanner: false,
          
          home: const SplashScreen(), 
        );
      },
    );
  }
}
