import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/supabase_config.dart';
import 'providers/restaurant_provider.dart';
import 'screens/mobile/table_selection_screen.dart';
import 'screens/desktop/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (User needs to fill this)
  if (SupabaseConfig.url != 'YOUR_SUPABASE_URL') {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RestaurantProvider()),
      ],
      child: const RestoBarApp(),
    ),
  );
}

class RestoBarApp extends StatelessWidget {
  const RestoBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MudhuLoka RestoBar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      home: const ResponsiveWrapper(),
    );
  }
}

class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if Supabase is configured
    if (SupabaseConfig.url == 'YOUR_SUPABASE_URL') {
      return const SetupInstructions();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return const DesktopDashboard();
        } else {
          return const TableSelectionScreen();
        }
      },
    );
  }
}

class SetupInstructions extends StatelessWidget {
  const SetupInstructions({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.settings_input_component, size: 80, color: Colors.deepOrange),
              const SizedBox(height: 24),
              const Text(
                'Supabase Setup Required',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please update lib/config/supabase_config.dart with your Supabase URL and Anon Key.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              const Text(
                'Also, ensure you have run the SQL script provided in the implementation plan to create the necessary tables.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
