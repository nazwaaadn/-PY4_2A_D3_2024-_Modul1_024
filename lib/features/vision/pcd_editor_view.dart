import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum LogicGate { and, or, xor, not }

class PcdEditorView extends StatefulWidget {
  final XFile imageFile;

  const PcdEditorView({super.key, required this.imageFile});

  @override
  State<PcdEditorView> createState() => _PcdEditorViewState();
}

class _PcdEditorViewState extends State<PcdEditorView> {
  final ImagePicker _picker = ImagePicker();

  img.Image? _sourceImage;
  img.Image? _secondImage;
  Uint8List? _originalBytes;
  Uint8List? _secondBytes;
  Uint8List? _processedBytes;
  List<int> _histogram = List<int>.filled(256, 0);

  bool _isLoading = true;
  bool _showOriginal = false;

  double _brightness = 0; // -100..100
  double _offset = 0; // -100..100
  bool _binaryMode = false;
  double _threshold = 128; // 0..255
  bool _invertBinary = false;
  bool _histEqMode = false;
  bool _logicGateEnabled = false;
  double _logicThreshold = 128; // 0..255
  LogicGate _selectedLogicGate = LogicGate.and;

  bool get _logicNeedsSecondImage => _selectedLogicGate != LogicGate.not;

  Future<Directory> _getOutputDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${baseDir.path}/pcd_results');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir;
  }

  Future<void> _saveProcessedImage() async {
    final bytes = _processedBytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada gambar hasil untuk disimpan.')),
      );
      return;
    }

    try {
      final outDir = await _getOutputDirectory();
      final now = DateTime.now();
      final name =
          'pcd_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.jpg';
      final file = File('${outDir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gambar tersimpan: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan gambar: $e')),
      );
    }
  }

  Future<void> _openSavedImagesGallery() async {
    final outDir = await _getOutputDirectory();
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavedProcessedImagesView(directoryPath: outDir.path),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (!mounted) return;

    if (decoded == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _sourceImage = decoded;
      _originalBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
      _isLoading = false;
    });

    _recomputeProcessed();
  }

  void _resetControls() {
    setState(() {
      _brightness = 0;
      _offset = 0;
      _binaryMode = false;
      _threshold = 128;
      _invertBinary = false;
      _histEqMode = false;
      _logicGateEnabled = false;
      _logicThreshold = 128;
      _selectedLogicGate = LogicGate.and;
      _secondImage = null;
      _secondBytes = null;
    });
    _recomputeProcessed();
  }

  int _clampChannel(num value) {
    return value.round().clamp(0, 255).toInt();
  }

  String _logicGateLabel(LogicGate gate) {
    switch (gate) {
      case LogicGate.and:
        return 'AND';
      case LogicGate.or:
        return 'OR';
      case LogicGate.xor:
        return 'XOR';
      case LogicGate.not:
        return 'NOT';
    }
  }

  int _toBinaryBit(img.Pixel p, double threshold) {
    final gray = (p.r + p.g + p.b) / 3.0;
    return gray >= threshold ? 1 : 0;
  }

  Future<void> _pickSecondImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );

      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gambar kedua tidak valid.')),
        );
        return;
      }

      setState(() {
        _secondImage = decoded;
        _secondBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
      });
      _recomputeProcessed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat gambar kedua: $e')),
      );
    }
  }

  Future<void> _showSecondImagePicker() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Ambil dari Galeri'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickSecondImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Ambil dari Kamera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickSecondImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyLogicGate(img.Image image) {
    if (!_logicGateEnabled) return;
    if (_logicNeedsSecondImage && _secondImage == null) return;

    final imageB = _logicNeedsSecondImage
        ? img.copyResize(
            _secondImage!,
            width: image.width,
            height: image.height,
            interpolation: img.Interpolation.linear,
          )
        : null;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p1 = image.getPixel(x, y);
        final bit1 = _toBinaryBit(p1, _logicThreshold);

        int outBit;
        switch (_selectedLogicGate) {
          case LogicGate.and:
            final p2 = imageB!.getPixel(x, y);
            final bit2 = _toBinaryBit(p2, _logicThreshold);
            outBit = bit1 & bit2;
            break;
          case LogicGate.or:
            final p2 = imageB!.getPixel(x, y);
            final bit2 = _toBinaryBit(p2, _logicThreshold);
            outBit = bit1 | bit2;
            break;
          case LogicGate.xor:
            final p2 = imageB!.getPixel(x, y);
            final bit2 = _toBinaryBit(p2, _logicThreshold);
            outBit = bit1 ^ bit2;
            break;
          case LogicGate.not:
            outBit = bit1 == 1 ? 0 : 1;
            break;
        }

        final output = outBit == 1 ? 255 : 0;
        image.setPixelRgba(x, y, output, output, output, p1.a.toInt());
      }
    }
  }

  void _applyHistogramEqualization(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    final int totalPixels = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final gray = ((p.r + p.g + p.b) / 3.0).round().clamp(0, 255);
        histogram[gray]++;
      }
    }

    final cdf = List<int>.filled(256, 0);
    cdf[0] = histogram[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + histogram[i];
    }

    int cdfMin = 0;
    for (int i = 0; i < 256; i++) {
      if (cdf[i] != 0) {
        cdfMin = cdf[i];
        break;
      }
    }

    if (totalPixels == cdfMin) {
      return;
    }

    final lut = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      final normalized = (cdf[i] - cdfMin) / (totalPixels - cdfMin);
      lut[i] = _clampChannel(normalized * 255);
    }

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = lut[p.r.round().clamp(0, 255)];
        final g = lut[p.g.round().clamp(0, 255)];
        final b = lut[p.b.round().clamp(0, 255)];
        image.setPixelRgba(x, y, r, g, b, p.a.toInt());
      }
    }
  }

  void _recomputeProcessed() {
    final source = _sourceImage;
    if (source == null) return;

    final working = img.Image.from(source);
    final int brightnessDelta = (_brightness * 2.55).round();
    final int arithmeticOffset = _offset.round();

    for (int y = 0; y < working.height; y++) {
      for (int x = 0; x < working.width; x++) {
        final pixel = working.getPixel(x, y);

        int r = _clampChannel(pixel.r + brightnessDelta + arithmeticOffset);
        int g = _clampChannel(pixel.g + brightnessDelta + arithmeticOffset);
        int b = _clampChannel(pixel.b + brightnessDelta + arithmeticOffset);

        working.setPixelRgba(x, y, r, g, b, pixel.a.toInt());
      }
    }

    if (_histEqMode) {
      _applyHistogramEqualization(working);
    }

    if (_binaryMode) {
      for (int y = 0; y < working.height; y++) {
        for (int x = 0; x < working.width; x++) {
          final p = working.getPixel(x, y);
          final gray = ((p.r + p.g + p.b) / 3.0);
          int binary = gray >= _threshold ? 255 : 0;
          if (_invertBinary) {
            binary = 255 - binary;
          }
          working.setPixelRgba(x, y, binary, binary, binary, p.a.toInt());
        }
      }
    }

    _applyLogicGate(working);

    final histogram = List<int>.filled(256, 0);
    for (int y = 0; y < working.height; y++) {
      for (int x = 0; x < working.width; x++) {
        final p = working.getPixel(x, y);
        final gray = ((p.r + p.g + p.b) / 3.0).round().clamp(0, 255);
        histogram[gray]++;
      }
    }

    setState(() {
      _processedBytes = Uint8List.fromList(img.encodeJpg(working, quality: 95));
      _histogram = histogram;
    });
  }

  Widget _buildSliderCard({
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFF4F7FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  valueText,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manipulasi Gambar'),
        actions: [
          IconButton(
            onPressed: _openSavedImagesGallery,
            tooltip: 'Lihat Hasil Tersimpan',
            icon: const Icon(Icons.photo_library_rounded),
          ),
          IconButton(
            onPressed: _saveProcessedImage,
            tooltip: 'Simpan Gambar Hasil',
            icon: const Icon(Icons.save_alt_rounded),
          ),
          IconButton(
            onPressed: _resetControls,
            tooltip: 'Reset Parameter',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sourceImage == null
          ? const Center(child: Text('Gambar tidak bisa diproses.'))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Original'),
                            selected: _showOriginal,
                            onSelected: (_) {
                              setState(() {
                                _showOriginal = true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Processed'),
                            selected: !_showOriginal,
                            onSelected: (_) {
                              setState(() {
                                _showOriginal = false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: Colors.black,
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: _showOriginal
                              ? (_originalBytes == null
                                    ? const SizedBox.shrink()
                                    : Image.memory(
                                        _originalBytes!,
                                        fit: BoxFit.contain,
                                      ))
                              : (_processedBytes == null
                                    ? const SizedBox.shrink()
                                    : Image.memory(
                                        _processedBytes!,
                                        fit: BoxFit.contain,
                                      )),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DefaultTabController(
                      length: 2,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: const Color(0xFFF4F7FF),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(text: 'Enhancement'),
                                  Tab(text: 'Gerbang Logika'),
                                ],
                              ),
                              SizedBox(
                                height: 460,
                                child: TabBarView(
                                  children: [
                                    ListView(
                                      padding: const EdgeInsets.only(top: 8),
                                      children: [
                                        _buildSliderCard(
                                          title: 'Brightness',
                                          valueText: _brightness.toStringAsFixed(
                                            0,
                                          ),
                                          value: _brightness,
                                          min: -100,
                                          max: 100,
                                          divisions: 200,
                                          onChanged: (value) {
                                            setState(() {
                                              _brightness = value;
                                            });
                                            _recomputeProcessed();
                                          },
                                        ),
                                        _buildSliderCard(
                                          title:
                                              'Aritmatika Offset (Tambah/Kurang)',
                                          valueText: _offset.toStringAsFixed(0),
                                          value: _offset,
                                          min: -100,
                                          max: 100,
                                          divisions: 200,
                                          onChanged: (value) {
                                            setState(() {
                                              _offset = value;
                                            });
                                            _recomputeProcessed();
                                          },
                                        ),
                                        SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                            'Histogram Equalization',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: const Text(
                                            'ON: tingkatkan kontras distribusi intensitas',
                                          ),
                                          value: _histEqMode,
                                          onChanged: (value) {
                                            setState(() {
                                              _histEqMode = value;
                                            });
                                            _recomputeProcessed();
                                          },
                                        ),
                                        const Divider(height: 8),
                                        SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                            'Mode Boolean (Threshold Biner)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: const Text(
                                            'ON: pixel jadi hitam/putih berdasarkan threshold',
                                          ),
                                          value: _binaryMode,
                                          onChanged: (value) {
                                            setState(() {
                                              _binaryMode = value;
                                            });
                                            _recomputeProcessed();
                                          },
                                        ),
                                        if (_binaryMode)
                                          Column(
                                            children: [
                                              _buildSliderCard(
                                                title: 'Threshold',
                                                valueText: _threshold
                                                    .toStringAsFixed(0),
                                                value: _threshold,
                                                min: 0,
                                                max: 255,
                                                divisions: 255,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _threshold = value;
                                                  });
                                                  _recomputeProcessed();
                                                },
                                              ),
                                              SwitchListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: const Text(
                                                  'Invert Biner',
                                                ),
                                                value: _invertBinary,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _invertBinary = value;
                                                  });
                                                  _recomputeProcessed();
                                                },
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    ListView(
                                      padding: const EdgeInsets.only(top: 8),
                                      children: [
                                        SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                            'Aktifkan Gerbang Logika',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: const Text(
                                            'Operasi bitwise: AND, OR, XOR, NOT',
                                          ),
                                          value: _logicGateEnabled,
                                          onChanged: (value) {
                                            setState(() {
                                              _logicGateEnabled = value;
                                            });
                                            _recomputeProcessed();
                                          },
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: LogicGate.values
                                              .map(
                                                (gate) => ChoiceChip(
                                                  label: Text(
                                                    _logicGateLabel(gate),
                                                  ),
                                                  selected:
                                                      _selectedLogicGate == gate,
                                                  onSelected: (_) {
                                                    setState(() {
                                                      _selectedLogicGate = gate;
                                                    });
                                                    _recomputeProcessed();
                                                  },
                                                ),
                                              )
                                              .toList(),
                                        ),
                                        _buildSliderCard(
                                          title: 'Threshold Logic',
                                          valueText: _logicThreshold
                                              .toStringAsFixed(0),
                                          value: _logicThreshold,
                                          min: 0,
                                          max: 255,
                                          divisions: 255,
                                          onChanged: (value) {
                                            setState(() {
                                              _logicThreshold = value;
                                            });
                                            _recomputeProcessed();
                                          },
                                        ),
                                        if (_logicNeedsSecondImage)
                                          Card(
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            color: Colors.white,
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Gambar Kedua (Wajib untuk AND/OR/XOR)',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  if (_secondBytes != null)
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      child: Image.memory(
                                                        _secondBytes!,
                                                        height: 140,
                                                        width:
                                                            double.infinity,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      height: 100,
                                                      width: double.infinity,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        color: const Color(
                                                          0xFFE2E8F0,
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'Belum ada gambar kedua',
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: OutlinedButton.icon(
                                                          onPressed:
                                                              _showSecondImagePicker,
                                                          icon: const Icon(
                                                            Icons.upload_file_rounded,
                                                          ),
                                                          label: const Text(
                                                            'Upload Gambar 2',
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        tooltip:
                                                            'Hapus gambar kedua',
                                                        onPressed:
                                                            _secondImage == null
                                                            ? null
                                                            : () {
                                                                setState(() {
                                                                  _secondImage =
                                                                      null;
                                                                  _secondBytes =
                                                                      null;
                                                                });
                                                                _recomputeProcessed();
                                                              },
                                                        icon: const Icon(
                                                          Icons.delete_outline_rounded,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (_logicGateEnabled &&
                                                      _secondImage == null)
                                                    const Padding(
                                                      padding: EdgeInsets.only(
                                                        top: 6,
                                                      ),
                                                      child: Text(
                                                        'Pilih gambar kedua agar operasi bisa diterapkan.',
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xFFB91C1C),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          )
                                        else
                                          const ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(Icons.info_outline),
                                            title: Text('Mode NOT aktif'),
                                            subtitle: Text(
                                              'Mode ini hanya butuh 1 gambar.',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: const Color(0xFFF4F7FF),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Histogram Grayscale',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 140,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: HistogramPainter(_histogram),
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
}

class HistogramPainter extends CustomPainter {
  final List<int> bins;

  HistogramPainter(this.bins);

  @override
  void paint(Canvas canvas, Size size) {
    if (bins.isEmpty) return;

    final bg = Paint()..color = const Color(0xFFE2E8F0);
    final bars = Paint()..color = const Color(0xFF2563EB);
    final axis = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      bg,
    );

    final maxCount = bins.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxCount <= 0) return;

    final barWidth = size.width / bins.length;

    for (int i = 0; i < bins.length; i++) {
      final normalized = bins[i] / maxCount;
      final barHeight = normalized * (size.height - 8);
      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRect(rect, bars);
    }

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      axis,
    );
  }

  @override
  bool shouldRepaint(covariant HistogramPainter oldDelegate) {
    return oldDelegate.bins != bins;
  }
}

class SavedProcessedImagesView extends StatefulWidget {
  final String directoryPath;

  const SavedProcessedImagesView({
    super.key,
    required this.directoryPath,
  });

  @override
  State<SavedProcessedImagesView> createState() => _SavedProcessedImagesViewState();
}

class _SavedProcessedImagesViewState extends State<SavedProcessedImagesView> {
  List<FileSystemEntity> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final dir = Directory(widget.directoryPath);
    if (!await dir.exists()) {
      if (!mounted) return;
      setState(() {
        _files = [];
        _loading = false;
      });
      return;
    }

    final files = dir
        .listSync()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeri Hasil Manipulasi'),
        actions: [
          IconButton(
            onPressed: _loadFiles,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
          ? const Center(
              child: Text('Belum ada gambar tersimpan.'),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3 / 4,
              ),
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = File(_files[index].path);
                final fileName = file.uri.pathSegments.last;

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _SavedImageDetailView(
                          imagePath: file.path,
                          title: fileName,
                        ),
                      ),
                    );
                  },
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFF1F5F9),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _SavedImageDetailView extends StatelessWidget {
  final String imagePath;
  final String title;

  const _SavedImageDetailView({
    required this.imagePath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}
