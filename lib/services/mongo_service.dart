import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_024/features/logbook/models/log_model.dart';
import 'package:logbook_app_024/helpers/log_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();

  // Menggunakan nullable agar kita bisa mengecek status inisialisasi
  Db? _db;
  DbCollection? _collection;

  final String _source = "mongo_service.dart";

  factory MongoService() => _instance;
  MongoService._internal();

  /// Fungsi Internal untuk memastikan koleksi siap digunakan (Anti-LateInitializationError)
  Future<DbCollection> _getSafeCollection() async {
    if (_db == null || !_db!.isConnected || _collection == null) {
      await LogHelper.writeLog(
        "INFO: Koleksi belum siap, mencoba rekoneksi...",
        source: _source,
        level: 3,
      );
      await connect();
    }
    return _collection!;
  }

  Future<bool> _checkInternet() async {
    // connectivity_plus v7 returns List<ConnectivityResult>
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> connect() async {
    try {
      if (!await _checkInternet()) {
        await LogHelper.writeLog(
          "OFFLINE MODE: Tidak ada koneksi internet.",
          source: _source,
          level: 1,
        );
        throw Exception("Offline Mode - Internet tidak tersedia");
      }

      final dbUri = dotenv.env['MONGODB_URI'];
      if (dbUri == null) throw Exception("MONGODB_URI tidak ditemukan di .env");

      _db = await Db.create(dbUri);

      await _db!.open().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("Koneksi Timeout. Cek IP Whitelist atau jaringan.");
        },
      );

      _collection = _db!.collection('logs');

      await LogHelper.writeLog(
        "DATABASE: Terhubung & Koleksi Siap",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DATABASE: Gagal Koneksi - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// READ: Mengambil data dari Cloud
  Future<List<LogModel>> getLogs(String teamId) async {
    try {
      final collection = await _getSafeCollection(); // Gunakan jalur aman

      await LogHelper.writeLog(
        "INFO: Fetching data for Team: $teamId",
        source: _source,
        level: 3,
      );

      final List<Map<String, dynamic>> data = await collection
          .find(where.eq('teamId', teamId))
          .toList();
      return data.map((json) => LogModel.fromMap(json)).toList();
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Fetch Failed - $e",
        source: _source,
        level: 1,
      );
      return [];
    }
  }

  /// CREATE: Menambahkan data baru
  Future<void> insertLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      await LogHelper.writeLog(
        "CREATE: Mulai menyimpan '${log.title}' ke Cloud...",
        source: _source,
        level: 3,
      );
      await collection.insertOne(log.toMap());

      await LogHelper.writeLog(
        "CREATE: Data '${log.title}' berhasil disimpan ke Cloud.",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "CREATE: Gagal menyimpan data - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// UPDATE: Memperbarui data berdasarkan ID
  Future<void> updateLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      if (log.id == null)
        throw Exception("ID Log tidak ditemukan untuk update");

      await LogHelper.writeLog(
        "UPDATE: Mulai update ID ${log.id}...",
        source: _source,
        level: 3,
      );

      final result = await collection.updateOne(
        where.id(ObjectId.fromHexString(log.id!)),
        modify
            .set('title', log.title)
            .set('date', log.date)
            .set('description', log.description)
            .set('category', log.category),
      );

      if (!result.isSuccess || result.nMatched == 0) {
        throw Exception("Data tidak ditemukan saat update di Cloud.");
      }

      await LogHelper.writeLog(
        "UPDATE: '${log.title}' berhasil diperbarui di Cloud.",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "UPDATE: Gagal memperbarui data - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// DELETE: Menghapus dokumen
  Future<void> deleteLog(String id) async {
    try {
      final collection = await _getSafeCollection();
      await LogHelper.writeLog(
        "DELETE: Mulai menghapus ID $id...",
        source: _source,
        level: 3,
      );

      final result = await collection.remove(
        where.id(ObjectId.fromHexString(id)),
      );

      if (result.isSuccess != true || result.nRemoved == 0) {
        throw Exception("Data tidak ditemukan saat delete di Cloud.");
      }

      await LogHelper.writeLog(
        "DELETE: Hapus ID $id berhasil.",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DELETE: Gagal menghapus data - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// UPSERT: Insert jika belum ada, update jika sudah ada (anti-duplikasi)
  Future<void> upsertLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      if (log.id == null) throw Exception("ID Log tidak ada untuk upsert");
      // save() di mongo_dart: jika dokumen punya _id → replaceOne+upsert
      await collection.save(log.toMap());
      await LogHelper.writeLog(
        "UPSERT: '${log.title}' berhasil disinkronisasi ke Cloud.",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog("UPSERT: Gagal - $e", source: _source, level: 1);
      rethrow;
    }
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      await LogHelper.writeLog(
        "DATABASE: Koneksi ditutup",
        source: _source,
        level: 2,
      );
    }
  }
}

extension on Map<String, dynamic> {
  bool? get isSuccess => null;

  get nRemoved => null;
}
