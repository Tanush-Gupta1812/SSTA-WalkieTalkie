import 'package:flutter/material.dart';
import 'screens/groups_list_screen.dart';
import 'theme.dart';

import 'services/foreground_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ForegroundManager.init();
  runApp(const WalkieApp());
}

class WalkieApp extends StatelessWidget {
  const WalkieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSTA walkie',
      debugShowCheckedModeBanner: false,
      theme: WalkieTheme.darkTheme,
      home: const GroupsListScreen(),
    );
  }
}
