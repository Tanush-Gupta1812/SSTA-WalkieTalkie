import 'package:flutter/material.dart';
import 'screens/groups_list_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WalkieApp());
}

class WalkieApp extends StatelessWidget {
  const WalkieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSTA Walkie-Talkie',
      debugShowCheckedModeBanner: false,
      theme: WalkieTheme.darkTheme,
      home: const GroupsListScreen(),
    );
  }
}
