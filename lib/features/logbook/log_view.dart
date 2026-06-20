import 'package:flutter/material.dart';
import 'package:logbook_app_024/features/auth/login_view.dart';
import 'log_controller.dart';
import 'package:logbook_app_024/features/logbook/models/log_model.dart';
import 'package:logbook_app_024/helpers/date_helper.dart';
import 'package:logbook_app_024/services/access_control_service.dart';
import 'package:logbook_app_024/features/logbook/log_editor_page.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logbook_app_024/features/vision/vision_view.dart';

class LogView extends StatefulWidget {
  final dynamic currentUser;
  const LogView({super.key, required this.currentUser});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late LogController _controller;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  // ─── Palette ───────────────────────────────────────────────────────────────
  final Color primaryNavy = const Color(0xFF00264D);
  final Color accentOrange = const Color(0xFFFA9D1C);
  final Color bgColor = const Color(0xFFF0F4FF);

  Future<void> _refreshLogs() async {
    await _loadData();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Color _categoryColor(String category) {
    switch (category) {
      case "Electronic":
        return const Color(0xFF1E88E5);
      case "Mechanical":
        return const Color(0xFF43A047);
      case "Software":
        return const Color(0xFF8E24AA);
      default:
        return const Color(0xFF00264D);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case "Mechanical":
        return Icons.person_rounded;
      case "Electronic":
        return Icons.school_rounded;
      case "Software":
        return Icons.work_rounded;
      default:
        return Icons.label_rounded;
    }
  }

  List<LogModel> get _visibleLogs {
    final allLogs = _controller.logsNotifier.value;
    final currentUserId = widget.currentUser['uid'] as String;
    final teamId = widget.currentUser['teamId'] as String;

    // Private by default: hanya pemilik yang bisa lihat
    // Jika isPublic == true: semua anggota tim yang sama bisa lihat
    final displayLogs = allLogs.where((log) {
      return log.authorId == currentUserId ||
          (log.isPublic == true && log.teamId == teamId);
    }).toList();

    final query = _searchController.text.toLowerCase();
    return displayLogs.where((log) {
      return query.isEmpty ||
          log.title.toLowerCase().contains(query) ||
          log.description.toLowerCase().contains(query);
    }).toList();
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _controller = LogController();
    _controller.startConnectivityWatch(widget.currentUser['teamId'] as String);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      await _controller.loadLogs(widget.currentUser['teamId'] as String);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToEditor({LogModel? log, int? index}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.cancelWatch();
    _searchController.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBackBlocked();
        return false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // ── Gradient header background ──────────────────────────────────
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryNavy, const Color(0xFF004080)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top bar ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _handleBackBlocked,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Logbook',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _refreshLogs,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── Indikator status sync cloud ──
                        ValueListenableBuilder<bool>(
                          valueListenable: _controller.isOnlineNotifier,
                          builder: (_, isOnline, __) => Tooltip(
                            message: isOnline
                                ? 'Tersinkron ke Cloud'
                                : 'Ada data belum tersinkron',
                            child: Icon(
                              isOnline
                                  ? Icons.cloud_done_rounded
                                  : Icons.cloud_upload_rounded,
                              color: isOnline
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openCameraView,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showLogoutDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Hero subtitle ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentOrange,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halo, ${widget.currentUser["username"]}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const Text(
                              'Kelola Log Aktivitas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── White card body ────────────────────────────────────────
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        child: Column(
                          children: [
                            // ── Search bar ───────────────────────────────────
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Cari catatan...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: primaryNavy.withOpacity(0.5),
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: primaryNavy.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // ── Log list ─────────────────────────────────────
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _refreshLogs,
                                child: _buildBody(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: accentOrange,
          foregroundColor: Colors.white,
          onPressed: () => _goToEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Tambah',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 6,
        ),
      ),
    );
  }

  // ─── Body content (loading / empty / list) ─────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: primaryNavy,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Menghubungkan ke Cloud...',
              style: TextStyle(
                color: primaryNavy.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mengambil data...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal Terhubung ke Cloud',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Tarik layar ke bawah untuk refresh',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder<List<LogModel>>(
      valueListenable: _controller.logsNotifier,
      builder: (context, _, __) {
        final logs = _visibleLogs;

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryNavy.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.logsNotifier.value.isEmpty
                        ? Icons.cloud_off_rounded
                        : Icons.search_off_rounded,
                    size: 48,
                    color: primaryNavy.withOpacity(0.35),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _controller.logsNotifier.value.isEmpty
                      ? 'Belum ada catatan di Cloud.'
                      : 'Tidak ada hasil yang cocok.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primaryNavy.withOpacity(0.7),
                  ),
                ),
                if (_controller.logsNotifier.value.isEmpty) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Buat Catatan Pertama'),
                    onPressed: () => _goToEditor(),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return _buildLogCard(log);
          },
        );
      },
    );
  }

  // ─── Single log card ───────────────────────────────────────────────────────
  Widget _buildLogCard(LogModel log) {
    final categoryColor = _categoryColor(log.category);
    final originalIndex = _controller.logsNotifier.value.indexWhere(
      (item) => item.date == log.date,
    );
    // Tombol edit muncul HANYA jika isOwner == true.
    // Role 'Ketua' tidak lagi memberikan hak edit otomatis.
    final bool isOwner = log.authorId == (widget.currentUser['uid'] as String);

    return Dismissible(
      key: Key(log.date),
      direction: isOwner ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        if (originalIndex != -1) _controller.removeLog(originalIndex);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Catatan dihapus'),
            backgroundColor: primaryNavy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: categoryColor.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row + action buttons
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _categoryIcon(log.category),
                              color: categoryColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              log.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: primaryNavy,
                              ),
                            ),
                          ),
                          // Edit button — hanya pemilik catatan
                          if (isOwner)
                            GestureDetector(
                              onTap: () =>
                                  _goToEditor(log: log, index: originalIndex),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryNavy.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 15,
                                  color: primaryNavy,
                                ),
                              ),
                            ),
                          if (isOwner) const SizedBox(width: 6),
                          // Delete button — hanya pemilik catatan
                          if (isOwner)
                            GestureDetector(
                              onTap: () {
                                if (originalIndex != -1) {
                                  _controller.removeLog(originalIndex);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE53935,
                                  ).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.delete_rounded,
                                  size: 15,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        height: 30,
                        child: Markdown(
                          data: log.description,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            pPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Text(
                        DateHelper.relativeTime(DateTime.parse(log.date)),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Actions ───────────────────────────────────────────────────────────────
  void _handleBackBlocked() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Anda harus logout terlebih dahulu untuk ke halaman login.',
        ),
        backgroundColor: primaryNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 22),
            const SizedBox(width: 8),
            const Text('Konfirmasi Logout'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
