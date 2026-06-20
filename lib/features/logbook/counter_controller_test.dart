import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HistoryItem {
  final String action;
  final int value;
  final DateTime time;

  HistoryItem({required this.action, required this.value, required this.time});
}

class CounterController {
  int _counter = 0;
  int _step = 1;
  final List<HistoryItem> _history = [];
  final String username;

  CounterController(this.username);

  int get value => _counter;
  int get step => _step;
  List<HistoryItem> get history => List.unmodifiable(_history);

  Future<void> saveLastValue(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_counter_$username', value);
    // 'last_counter_${username}' adalah Kunci (Key) untuk memanggil data nanti
  }

  Future<void> loadLastValue() async {
    final prefs = await SharedPreferences.getInstance();
    _counter = prefs.getInt('last_counter_$username') ?? 0;
  }

  void setStep(int step) {
    if (step > 0) _step = step;
  }

  void increment() {
    _counter += _step;
    _addHistory("User menambah nilai sebesar", _step);
  }

  void decrement() {
    if (_counter - _step >= 0) {
      _counter -= _step;
      _addHistory("User mengurangi nilai sebesar", _step);
    }
  }

  void reset() {
    _counter = 0;
    _addHistory("User Reset nilai menjadi", _counter);
  }

  void _addHistory(String action, int value) {
    _history.insert(
      0,
      HistoryItem(action: action, value: value, time: DateTime.now()),
    );

    if (_history.length > 5) {
      _history.removeLast();
    }
    saveHistory();
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // Ubah List<HistoryItem> jadi List<Map>
    List<Map<String, dynamic>> historyMap = _history.map((item) {
      return {
        "action": item.action,
        "value": item.value,
        "time": item.time.toIso8601String(),
      };
    }).toList();

    // Encode ke JSON
    String historyJson = jsonEncode(historyMap);

    await prefs.setString('history_data_$username', historyJson);
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();

    String? historyJson = prefs.getString('history_data_$username');

    if (historyJson != null) {
      List<dynamic> decoded = jsonDecode(historyJson);

      _history.clear();

      for (var item in decoded) {
        _history.add(
          HistoryItem(
            action: item['action'],
            value: item['value'],
            time: DateTime.parse(item['time']),
          ),
        );
      }
    }
  }
}