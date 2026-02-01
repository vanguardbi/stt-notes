import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stt/screens/add_session.dart';
import 'package:stt/screens/children.dart';
import 'package:stt/screens/home_stats.dart';
import 'package:stt/screens/settings.dart';
import 'package:flutter/services.dart';
import 'package:stt/theme/color_scheme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:stt/widget/auth_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

Future<void> main() async {
  final WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: 'https://hcgmmdlbvocaviigphtd.supabase.co',
    anonKey: 'sb_publishable_2NF2Adn6zyLAlf-T8BLQlQ_oeF3bocq',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STT Notes',
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const MainPage(),
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        buttonTheme: const ButtonThemeData(
          colorScheme: ColorScheme.light(
            primary: Color(0xff006a53),
            secondary: Color(0xffd1ffeb),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF512DA8)),
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        listTileTheme: ListTileThemeData(
          dense: true,
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(width: 1.0, color: Color(0xFFF4F6F9)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFaea3c5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide.none,
            ),
          ),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.getFont(
            'Inter',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: GoogleFonts.getFont(
            'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          titleMedium: GoogleFonts.getFont(
            'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
          titleSmall: GoogleFonts.getFont(
            'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: GoogleFonts.getFont(
            'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: GoogleFonts.getFont(
            'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        buttonTheme: const ButtonThemeData(
          colorScheme: ColorScheme.light(
            primary: Color(0xff006a53),
            secondary: Color(0xffd1ffeb),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF512DA8)),
        popupMenuTheme: PopupMenuThemeData(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.getFont(
            'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSecondary,
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        listTileTheme: ListTileThemeData(
          dense: true,
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(width: 1.0, color: Color(0xFFF4F6F9)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff006a53),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide.none,
            ),
          ),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.getFont(
            'Inter',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: GoogleFonts.getFont(
            'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          titleMedium: GoogleFonts.getFont(
            'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
          titleSmall: GoogleFonts.getFont(
            'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: GoogleFonts.getFont(
            'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: GoogleFonts.getFont(
            'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;
  final List<Widget> screens = [
    const HomeStats(),
    const AddSessionScreen(),
    const ChildrenListScreen(),
    const SettingsScreen(),
  ];
  List<IconData> data = [
    Icons.home_outlined,
    Icons.mic_none_outlined,
    Icons.people_alt_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final style = SystemUiOverlayStyle(
      systemNavigationBarColor: Theme.of(context).colorScheme.onSecondary,
      systemNavigationBarDividerColor:
      Theme.of(context).colorScheme.onSecondary,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
    SystemChrome.setSystemUIOverlayStyle(style);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: Material(
          // elevation: 16,
          shadowColor: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFFFF5959),
          child: SizedBox(
            height: 70,
            width: double.infinity,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: data.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedIndex = i;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 35,
                    decoration: BoxDecoration(
                      border: i == selectedIndex
                          ? const Border(
                          top: BorderSide(
                              width: 3.0,
                              color: Color(
                                  0xffffff))) //for animation in bottom navigation bar
                          : null,
                    ),
                    child: Icon(
                      data[i],
                      size: 35,
                      color: i == selectedIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              scrollDirection: Axis.horizontal,
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
    );
  }
}
