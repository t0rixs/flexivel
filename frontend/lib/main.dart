import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'state/trip_state.dart';
import 'screens/trip_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FlexivelApp());
}

class FlexivelApp extends StatefulWidget {
  const FlexivelApp({super.key});

  @override
  State<FlexivelApp> createState() => _FlexivelAppState();
}

class _FlexivelAppState extends State<FlexivelApp> {
  // MVP: 固定ユーザーID（認証実装後に差し替え）
  late final TripState _tripState;

  @override
  void initState() {
    super.initState();
    _tripState = TripState(userId: 'demo_user');
  }

  @override
  void dispose() {
    _tripState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flexivel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6), // ブルー
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: TripScreen(tripState: _tripState),
    );
  }
}
