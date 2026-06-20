import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_024/features/auth/login_controller.dart';
import 'package:logbook_app_024/features/logbook/log_controller.dart';
import 'package:logbook_app_024/features/logbook/models/log_model.dart';

class FakeCloudLogService implements CloudLogService {
  bool failInsert = false;
  bool failUpdate = false;
  bool failDelete = false;

  int insertCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<LogModel>> getLogs(String teamId) async => [];

  @override
  Future<void> insertLog(LogModel log) async {
    insertCalls++;
    if (failInsert) throw Exception('Simulated insert failure');
  }

  @override
  Future<void> updateLog(LogModel log) async {
    updateCalls++;
    if (failUpdate) throw Exception('Simulated update failure');
  }

  @override
  Future<void> deleteLog(String id) async {
    deleteCalls++;
    if (failDelete) throw Exception('Simulated delete failure');
  }

  @override
  Future<void> upsertLog(LogModel log) async {}
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'LOG_LEVEL=0\nLOG_MUTE=\n');
    tempDir = await Directory.systemTemp.createTemp('hw_all_modules_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LogModelAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    if (Hive.isBoxOpen('offline_logs')) {
      await Hive.box<LogModel>('offline_logs').clear();
    } else {
      await Hive.openBox<LogModel>('offline_logs');
    }
  });

  group('Modul 2 - Authentication', () {
    late LoginController loginController;

    setUp(() {
      loginController = LoginController();
    });

    test('Flow 1 (Positive): login valid returns true', () {
      expect(loginController.login('admin', '123'), true);
    });

    test('Flow 2 (Negative): wrong password returns false', () {
      expect(loginController.login('admin', 'wrong-password'), false);
    });

    test('Flow 3 (Error/Edge): unknown username returns false', () {
      expect(loginController.login('unknown-user', '123'), false);
    });
  });

  group('Modul 3 - Save to Disk', () {
    test('Flow 1 (Positive): saveToDisk stores valid JSON payload', () async {
      final controller = LogController(cloudService: FakeCloudLogService());
      controller.logsNotifier.value = [
        LogModel(
          id: '507f1f77bcf86cd799439011',
          title: 'Disk OK',
          description: 'Valid payload',
          date: '2026-04-01',
          authorId: 'admin',
          teamId: 'team_001',
        ),
      ];

      await controller.saveToDisk();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_logs_data');
      final decoded = jsonDecode(raw!) as List<dynamic>;

      expect(decoded.length, 1);
      expect((decoded.first as Map<String, dynamic>)['title'], 'Disk OK');
    });

    test(
      'Flow 2 (Negative): saveToDisk throws on invalid ObjectId format',
      () async {
        final controller = LogController(cloudService: FakeCloudLogService());
        controller.logsNotifier.value = [
          LogModel(
            id: 'invalid-id',
            title: 'Broken',
            description: 'Invalid object id',
            date: '2026-04-01',
            authorId: 'admin',
            teamId: 'team_001',
          ),
        ];

        expect(controller.saveToDisk(), throwsA(isA<ArgumentError>()));
      },
    );

    test('Flow 3 (Error/Edge): saveToDisk with empty list stores []', () async {
      final controller = LogController(cloudService: FakeCloudLogService());
      controller.logsNotifier.value = [];

      await controller.saveToDisk();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_logs_data'), '[]');
    });
  });

  group('Modul 4 - Save to Cloud', () {
    test('Flow 1 (Positive): addLog online sends insert to cloud', () async {
      final fakeCloud = FakeCloudLogService();
      final controller = LogController(cloudService: fakeCloud);

      await controller.addLog('Cloud Add', 'Online add', 'admin', 'team_001');

      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_sync_ids') ?? [];

      expect(fakeCloud.insertCalls, 1);
      expect(controller.logsNotifier.value.length, 1);
      expect(pending.isEmpty, true);
    });

    test(
      'Flow 2 (Negative): updateLog failure keeps old local value',
      () async {
        final fakeCloud = FakeCloudLogService()..failUpdate = true;
        final controller = LogController(cloudService: fakeCloud);

        controller.logsNotifier.value = [
          LogModel(
            id: 'up_001',
            title: 'Old Title',
            description: 'Old Desc',
            date: '2026-04-01',
            authorId: 'admin',
            teamId: 'team_001',
          ),
        ];

        await controller.updateLog(0, 'New Title', 'New Desc');

        expect(fakeCloud.updateCalls, 1);
        expect(controller.logsNotifier.value.first.title, 'Old Title');
        expect(controller.logsNotifier.value.first.description, 'Old Desc');
      },
    );

    test(
      'Flow 3 (Error/Edge): removeLog with null id skips cloud delete',
      () async {
        final fakeCloud = FakeCloudLogService();
        final controller = LogController(cloudService: fakeCloud);

        controller.logsNotifier.value = [
          LogModel(
            title: 'No ID',
            description: 'Local only',
            date: '2026-04-01',
            authorId: 'admin',
            teamId: 'team_001',
          ),
        ];

        await controller.removeLog(0);

        expect(fakeCloud.deleteCalls, 0);
        expect(controller.logsNotifier.value.length, 1);
      },
    );
  });
}
