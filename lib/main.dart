import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme.dart';

// අලුතින් හදපු Splash Screen එක Import කරගන්න
import 'features/splash/splash_screen.dart'; 

// ඔයා අලුතින් හදපු Network Service එක import කරගන්න
// (ඔයා network_service.dart file එක save කරපු path එකට අනුව මේක වෙනස් වෙන්න පුළුවන්. උදා: import 'core/services/network_service.dart';)
import 'core/network_service.dart';

// මුළු App එකම පාලනය කරන Global Navigator Key එක මෙතන හදන්න
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://etlxrdxldtobffzficxu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );
  
  runApp(const TeaCollectionApp());
}

// Network Service එක Initialize කරන්න ඕන නිසා මේක StatefulWidget එකක් බවට පත් කළා
class TeaCollectionApp extends StatefulWidget {
  const TeaCollectionApp({super.key});

  @override
  State<TeaCollectionApp> createState() => _TeaCollectionAppState();
}

class _TeaCollectionAppState extends State<TeaCollectionApp> {
  
  @override
  void initState() {
    super.initState();
    // App එක Start වෙද්දිම Network Service එකට Navigator Key එක යවලා On කරනවා
    NetworkService().initialize(globalNavigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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