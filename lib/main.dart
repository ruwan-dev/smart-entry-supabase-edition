import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_preview/device_preview.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme.dart';

// අලුතින් හදපු Splash Screen එක Import කරගන්න
import 'features/splash/splash_screen.dart'; 

// ඔයා අලුතින් හදපු Network Service එක import කරගන්න
import 'core/network_service.dart';

// මුළු App එකම පාලනය කරන Global Navigator Key එක මෙතන හදන්න
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

Process? _nodeProcess;

void _startNodeServer() async {
  try {
     // In release mode (production), it looks for node.exe in the same folder as the app.
     // In debug mode, it uses the installed node on your computer.
     String executable = kReleaseMode ? 'node.exe' : 'node';
     
     _nodeProcess = await Process.start(
        executable, 
        ['whatsapp_server/server.js'],
        runInShell: true, 
     );
     debugPrint("WhatsApp Node server started in background. PID: ${_nodeProcess?.pid}");
  } catch (e) {
     debugPrint("Failed to start WhatsApp node server: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

    // Start the WhatsApp Node.js server automatically
    _startNodeServer();
  }

  await Supabase.initialize(
    url: 'https://etlxrdxldtobffzficxu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );
  
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const TeaCollectionApp(),
    ),
  );
}

// Network Service එක Initialize කරන්න ඕන නිසා මේක StatefulWidget එකක් බවට පත් කළා
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
    
    // App එක Start වෙද්දිම Network Service එකට Navigator Key එක යවලා On කරනවා
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
    if (_nodeProcess != null) {
      debugPrint("Killing WhatsApp Node server...");
      _nodeProcess?.kill();
    }
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      // මේක අනිවාර්යයෙන්ම දාන්න (එතකොට තමයි ඕනම Screen එකක ඉඳන් Popup එක එන්නෙ)
      navigatorKey: globalNavigatorKey,
      
      title: 'Smart Entry',
      theme: appTheme.copyWith(
        textTheme: GoogleFonts.notoSansSinhalaTextTheme(appTheme.textTheme),
        primaryTextTheme: GoogleFonts.notoSansSinhalaTextTheme(appTheme.primaryTextTheme),
      ),
      debugShowCheckedModeBanner: false,
      
      // මුලින්ම LoginScreen එකට යන එක වෙනුවට SplashScreen එකට යවනවා
      home: const SplashScreen(), 
    );
  }
}