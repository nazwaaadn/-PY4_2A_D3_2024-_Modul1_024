import 'dart:async';
import 'dart:convert'; // Wajib ditambahkan untuk jsonEncode & jsonDecode
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:logbook_app_024/features/logbook/models/log_model.dart';
import 'package:logbook_app_024/services/mongo_service.dart';
import 'package:logbook_app_024/helpers/log_helper.dart';

abstract class CloudLogService {
  Future<List<LogModel>> getLogs(String teamId);
  Future<void> insertLog(LogModel log);
  Future<void> updateLog(LogModel log);
  Future<void> deleteLog(String id);
  Future<void> upsertLog(LogModel log);
}

class MongoCloudLogService implements CloudLogService {
  final MongoService _mongo;

  MongoCloudLogService([MongoService? mongo])
    : _mongo = mongo ?? MongoService();

  @override
  Future<List<LogModel>> getLogs(String teamId) => _mongo.getLogs(teamId);

  @override
  Future<void> insertLog(LogModel log) => _mongo.insertLog(log);

  @override
  Future<void> updateLog(LogModel log) => _mongo.updateLog(log);

  @override
  Future<void> deleteLog(String id) => _mongo.deleteLog(id);

  @override
  Future<void> upsertLog(LogModel log) => _mongo.upsertLog(log);
}

class LogController {
  final CloudLogService _cloudService;
  final ValueNotifier<List<LogModel>> logsNotifier =
      ValueNotifier<List<LogModel>>([]);

  /// Notifier status koneksi: true = online, false = offline
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier(true);

  StreamSubscription? _connectivitySub;

  // Kunci antrian pending sync di SharedPreferences
  static const String _pendingKey = 'pending_sync_ids';

  // Kunci unik untuk penyimpanan lokal di Shared Preferences
  static const String _storageKey = 'user_logs_data';

  // Getter untuk mempermudah akses list data saat ini
  List<LogModel> get logs => logsNotifier.value;

  // --- KONSTRUKTOR ---
  LogController({CloudLogService? cloudService})
    : _cloudService = cloudService ?? MongoCloudLogService();

  /// 1. LOAD DATA (Offline-First Strategy)
  Future<void> loadLogs(String teamId) async {
    final box = Hive.box<LogModel>('offline_logs');

    // Langkah 1: Ambil data dari Hive (Sangat Cepat/Instan)
    logsNotifier.value = box.values.where((l) => l.teamId == teamId).toList();

    // Langkah 2: Sync dari Cloud (Background)
    try {
      final cloudData = await _cloudService.getLogs(teamId);

      final prefs = await SharedPreferences.getInstance();
      final pendingIds = prefs.getStringList(_pendingKey) ?? [];
      final pendingLogs = box.values
          .where((l) => l.id != null && pendingIds.contains(l.id))
          .toList();

      await box.clear();
      await box.addAll(cloudData);
      for (final pending in pendingLogs) {
        final alreadySynced = cloudData.any((c) => c.id == pending.id);
        if (!alreadySynced) await box.add(pending);
      }

      final allLocal = box.values.where((l) => l.teamId == teamId).toList();
      logsNotifier.value = allLocal;

      isOnlineNotifier.value = pendingIds.isEmpty;

      await LogHelper.writeLog(
        "SYNC: Data berhasil diperbarui dari Atlas",
        level: 2,
      );

      await _syncPending(teamId);
    } catch (e) {
      isOnlineNotifier.value = false;
      await LogHelper.writeLog(
        "OFFLINE: Menggunakan data cache lokal",
        level: 2,
      );
    }
  }

  Future<void> addLog(
    String title,
    String desc,
    String authorId,
    String teamId, {
    bool isPublic = false,
    String category = 'Mechanical',
  }) async {
    final newLog = LogModel(
      id: ObjectId().oid,
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      authorId: authorId,
      teamId: teamId,
      isPublic: isPublic,
      category: category,
    );

    final box = Hive.box<LogModel>('offline_logs');
    await box.add(newLog);
    logsNotifier.value = [...logsNotifier.value, newLog];

    try {
      await _cloudService.insertLog(newLog);
      await LogHelper.writeLog(
        "SUCCESS: Data tersinkron ke Cloud",
        source: "log_controller.dart",
      );
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingKey) ?? [];
      if (!pending.contains(newLog.id)) pending.add(newLog.id!);
      await prefs.setStringList(_pendingKey, pending);
      isOnlineNotifier.value = false;
      await LogHelper.writeLog(
        "WARNING: Data tersimpan lokal, akan sinkron saat online",
        level: 1,
      );
    }
  }

  Future<void> updateLog(
    int index,
    String newTitle,
    String newDesc, {
    String? category,
    bool? isPublic,
  }) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final oldLog = currentLogs[index];

    final updatedLog = LogModel(
      id: oldLog.id,
      title: newTitle,
      description: newDesc,
      date: DateTime.now().toString(),
      authorId: oldLog.authorId,
      teamId: oldLog.teamId,
      category: category ?? oldLog.category,
      isPublic: isPublic ?? oldLog.isPublic,
    );

    try {
      await _cloudService.updateLog(updatedLog);

      currentLogs[index] = updatedLog;
      logsNotifier.value = currentLogs;
      await _syncHive();

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Update '${oldLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Update - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  Future<void> removeLog(int index) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final targetLog = currentLogs[index];

    try {
      if (targetLog.id == null) {
        throw Exception(
          "ID Log tidak ditemukan, tidak bisa menghapus di Cloud.",
        );
      }

      await _cloudService.deleteLog(targetLog.id!);

      currentLogs.removeAt(index);
      logsNotifier.value = currentLogs;
      await _syncHive();

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Hapus '${targetLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Hapus - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      logsNotifier.value.map((log) => log.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  Future<void> loadFromDisk([String teamId = '']) async {
    // Mengambil dari Cloud, bukan lokal
    final cloudData = await _cloudService.getLogs(teamId);
    logsNotifier.value = cloudData;
  }

  void searchLog(String text) {}

  void startConnectivityWatch(String teamId) {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      isOnlineNotifier.value = isOnline;
      if (isOnline) {
        try {
          await _syncPending(teamId);
        } catch (e) {
          isOnlineNotifier.value = false;
          await LogHelper.writeLog(
            "SYNC WATCH: Gagal sinkronisasi saat online - $e",
            source: "log_controller.dart",
            level: 1,
          );
        }
      }
    });
  }

  void cancelWatch() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> _syncPending(String teamId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingIds = prefs.getStringList(_pendingKey) ?? [];
    if (pendingIds.isEmpty) {
      isOnlineNotifier.value = true;
      return;
    }

    final box = Hive.box<LogModel>('offline_logs');
    final synced = <String>[];

    for (final id in pendingIds) {
      final log = box.values.cast<LogModel?>().firstWhere(
        (l) => l?.id == id,
        orElse: () => null,
      );
      if (log == null) {
        synced.add(id); // Log sudah tidak ada, hapus dari antrian
        continue;
      }
      try {
        // upsertLog mencegah duplikasi: insert jika baru, replace jika sudah ada
        await _cloudService.upsertLog(log);
        synced.add(id);
      } catch (e) {
        await LogHelper.writeLog(
          "SYNC PENDING: Gagal kirim ID $id - $e",
          source: "log_controller.dart",
          level: 1,
        );
      }
    }

    if (synced.isNotEmpty) {
      final remaining = pendingIds.where((id) => !synced.contains(id)).toList();
      await prefs.setStringList(_pendingKey, remaining);
      isOnlineNotifier.value = remaining.isEmpty;
      // Reload dari cloud agar UI sinkron
      await loadLogs(teamId);
      await LogHelper.writeLog(
        "SYNC: ${synced.length} log offline berhasil dikirim ke Atlas",
        source: "log_controller.dart",
        level: 2,
      );
      return;
    }

    // Tidak ada yang berhasil disinkronkan.
    isOnlineNotifier.value = false;
  }

  /// Trigger manual sinkronisasi pending log.
  Future<void> syncPendingNow(String teamId) async {
    await _syncPending(teamId);
  }

  // ─── Hive & Cloud Sync ──────────────────────────────────────────────────────

  /// Simpan state notifier saat ini ke Hive (offline cache).
  Future<void> _syncHive() async {
    final box = Hive.box<LogModel>('offline_logs');
    await box.clear();
    await box.addAll(logsNotifier.value);
  }
}
