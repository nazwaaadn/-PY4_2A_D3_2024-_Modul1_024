import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logbook_app_024/features/logbook/models/log_model.dart';
import 'package:logbook_app_024/features/onboarding/onboarding_view.dart';
import 'package:logbook_app_024/helpers/log_helper.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await dotenv.load(fileName: '.env');

  // Verifikasi kamera lebih awal agar error bisa tercatat ke log startup.
  try {
    cameras = await availableCameras();
    await LogHelper.writeLog(
      'Available cameras: ${cameras.length}',
      source: 'main.dart',
      level: 2,
    );
  } on CameraException catch (e) {
    await LogHelper.writeLog(
      'Camera Error: ${e.code}\nError Message: ${e.description}',
      source: 'main.dart',
      level: 1,
    );
  }

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(LogModelAdapter());
  }
  await Hive.openBox<LogModel>('offline_logs');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogBook App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const OnboardingView(),
    );
  }
}
