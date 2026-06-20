import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logbook_app_024/features/logbook/models/log_model.dart';
import 'package:logbook_app_024/features/logbook/log_controller.dart';

class LogEditorPage extends StatefulWidget {
  final LogModel? log;
  final int? index;
  final LogController controller;
  final dynamic currentUser;

  const LogEditorPage({
    super.key,
    this.log,
    this.index,
    required this.controller,
    required this.currentUser,
  });

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  bool _isPublic = false;
  String _category = 'Mechanical';

  static const List<String> _categories = [
    'Mechanical',
    'Electronic',
    'Software',
  ];
  // ─── Palette ───────────────────────────────────────────────────────────────
  final Color primaryNavy = const Color(0xFF00264D);
  final Color accentOrange = const Color(0xFFFA9D1C);
  final Color bgColor = const Color(0xFFF0F4FF);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log?.title ?? '');
    _descController = TextEditingController(
      text: widget.log?.description ?? '',
    );
    _isPublic = widget.log?.isPublic ?? false;
    _category = widget.log?.category ?? 'Mechanical';

    // TAMBAHKAN INI: Listener agar Pratinjau terupdate otomatis
    _descController.addListener(() {
      setState(() {});
    });
  }

  void _save() {
    if (widget.log == null) {
      // Tambah Baru
      widget.controller.addLog(
        _titleController.text,
        _descController.text,
        widget.currentUser['uid'],
        widget.currentUser['teamId'],
        isPublic: _isPublic,
        category: _category,
      );
    } else {
      // Update
      widget.controller.updateLog(
        widget.index!,
        _titleController.text,
        _descController.text,
        category: _category,
        isPublic: _isPublic,
      );
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    // JANGAN LUPA: Bersihkan controller agar tidak memory leak
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,

      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryNavy, const Color(0xFF004080)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          title: Text(
            widget.log == null ? "Catatan Baru" : "Edit Catatan",
            style: const TextStyle(color: Colors.white),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
          bottom: TabBar(
            labelColor: accentOrange,
            unselectedLabelColor: Colors.white70,
            indicatorColor: accentOrange,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "Editor", icon: Icon(Icons.edit)),
              Tab(text: "Pratinjau", icon: Icon(Icons.preview)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
              style: IconButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: "Judul"),
                  ),
                  const SizedBox(height: 10),
                  // Dropdown kategori
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 4),
                  // Toggle public/private
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bagikan ke Tim (Public)'),
                    subtitle: Text(
                      _isPublic
                          ? 'Semua anggota tim dapat melihat catatan ini'
                          : 'Hanya kamu yang dapat melihat catatan ini',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _descController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: "Tulis laporan dengan format Markdown...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Markdown(data: _descController.text),
          ],
        ),
      ),
    );
  }
}
