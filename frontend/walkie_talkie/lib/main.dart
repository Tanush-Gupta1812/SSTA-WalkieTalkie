import 'package:flutter/material.dart';
import 'screens/groups_list_screen.dart';
import 'theme.dart';

import 'config.dart';
import 'services/foreground_manager.dart';
import 'services/active_channel_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.loadCache();
  ForegroundManager.init();
  await ActiveChannelSession.instance.restoreLastSessionIfNeeded();
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
