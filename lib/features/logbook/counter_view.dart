import 'package:flutter/material.dart';
import 'counter_controller.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:logbook_app_024/features/auth/login_view.dart';
import 'package:logbook_app_024/features/vision/vision_view.dart';

class CounterView extends StatefulWidget {
  final String username;
  const CounterView({super.key, required this.username});

  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {
  late CounterController _controller;

  // Custom Colors
  final Color primaryNavy = const Color(0xFF00264D);
  final Color accentOrange = const Color(0xFFFA9D1C);
  final Color bgColor = const Color(0xFFF8F9FE);

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Selamat Pagi";
    if (hour < 15) return "Selamat Siang";
    if (hour < 19) return "Selamat Sore";
    return "Selamat Malam";
  }

  @override
  void initState() {
    super.initState();
    _controller = CounterController(widget.username);
    _loadData();
  }

  Future<void> _loadData() async {
    await _controller.loadLastValue();
    await _controller.loadHistory();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Tampilkan dialog konfirmasi sebelum keluar
        return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text("Kembali ke Login?"),
                content: const Text(
                  "Apakah Anda yakin ingin kembali ke halaman login?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Batal"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context, true); // Izinkan back
                    },
                    child: const Text("Ya, Kembali"),
                  ),
                ],
              ),
            ) ??
            false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            "Logbook",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          centerTitle: true,
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.camera_alt_rounded),
              tooltip: 'Buka Kamera',
              onPressed: _openCameraView,
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _showLogoutDialog,
            ),
          ],
        ),
        body: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: primaryNavy,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: accentOrange,
                    child: Text(
                      widget.username[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        widget.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Main Counter Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Total Hitungan Saat Ini",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${_controller.value}',
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                              color: primaryNavy,
                            ),
                          ),
                          const Divider(height: 40),

                          // Slider Section
                          Row(
                            children: [
                              Icon(Icons.tune, color: accentOrange, size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                "Step",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Text(
                                "${_controller.step}",
                                style: TextStyle(
                                  color: accentOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _controller.step.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 100,
                            activeColor: accentOrange,
                            inactiveColor: accentOrange.withOpacity(0.2),
                            onChanged: (double value) {
                              setState(
                                () => _controller.setStep(value.toInt()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // History Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Riwayat Aktivitas",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // History List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _controller.history.length,
                      itemBuilder: (context, index) {
                        final item = _controller.history[index];
                        bool isAdd = item.action.contains("menambah");

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isAdd
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAdd
                                    ? Icons.add_rounded
                                    : Icons.remove_rounded,
                                color: isAdd ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              "${item.action} ${item.value}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              _formatTime(item.time),
                              style: const TextStyle(fontSize: 11),
                            ),
                            // trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 100), // Space for FAB
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: SpeedDial(
          icon: Icons.add,
          activeIcon: Icons.close,
          backgroundColor: accentOrange,
          foregroundColor: Colors.white,
          overlayColor: Colors.black,
          overlayOpacity: 0.4,
          spacing: 12,
          spaceBetweenChildren: 12,
          children: [
            SpeedDialChild(
              child: const Icon(Icons.refresh_rounded),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              onTap: _resetPopUp,
            ),
            SpeedDialChild(
              child: const Icon(Icons.remove_rounded),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              onTap: () async {
                setState(() => _controller.decrement());
                await _controller.saveLastValue(_controller.value);
              },
            ),
            SpeedDialChild(
              child: const Icon(Icons.add_rounded),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              onTap: () async {
                setState(() => _controller.increment());
                await _controller.saveLastValue(_controller.value);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCameraView() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VisionView()),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Konfirmasi Logout"),
        content: const Text("Apakah Anda yakin ingin keluar dari akun ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginView(fromLogout: true),
                ),
                (route) => false,
              );
            },
            child: const Text("Ya, Keluar"),
          ),
        ],
      ),
    );
  }

  void _resetPopUp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reset Hitungan"),
        content: const Text(
          "Semua data hitungan akan kembali ke nol. Lanjutkan?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accentOrange),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _controller.reset());
              await _controller.saveLastValue(_controller.value);
            },
            child: const Text("Reset Sekarang"),
          ),
        ],
      ),
    );
  }
}
