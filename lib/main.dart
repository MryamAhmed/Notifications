import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:notifecation/core/services/notification_service.dart';
import 'package:notifecation/features/downloads/presentation/cubit/downloads_cubit.dart';
import 'package:notifecation/features/downloads/presentation/pages/downloads_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the plugin before any Cubit/UI uses notifications.
  await NotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Spike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Cubit is created with the page → permission dialog runs on open.
      home: BlocProvider(
        create: (_) => DownloadsCubit(),
        child: const DownloadsPage(),
      ),
    );
  }
}
