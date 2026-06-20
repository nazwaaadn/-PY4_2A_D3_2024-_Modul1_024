import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'vision_controller.dart';
import 'damage_painter.dart';
import 'pcd_editor_view.dart';

class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  // Initialize controller locally for this page
  late VisionController _visionController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isControllerDisposed = false;

  void _disposeVisionControllerOnce() {
    if (_isControllerDisposed) return;
    _visionController.dispose();
    _isControllerDisposed = true;
  }

  Future<void> _toggleFlashWithFeedback() async {
    final ok = await _visionController.toggleFlashlight();
    if (!mounted) return;

    final message = ok
        ? (_visionController.isFlashlightOn
              ? "Flash menyala"
              : "Flash dimatikan")
        : (_visionController.errorMessage ?? "Flash tidak tersedia");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );

    // Keep setState for immediate icon refresh in this widget tree.
    setState(() {});
  }

  void _toggleOverlayWithFeedback() {
    _visionController.toggleOverlay();

    if (!mounted) return;

    final message = _visionController.isOverlayVisible
        ? "Overlay deteksi ditampilkan"
        : "Overlay deteksi disembunyikan";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );

    // Keep setState for immediate icon refresh in this widget tree.
    setState(() {});
  }

  Future<void> _uploadImageForManipulation() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (!mounted || picked == null) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PcdEditorView(imageFile: picked)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal upload gambar: $e')));
    }
  }

  Future<void> _captureAndOpenEditor() async {
    final image = await _visionController.takePhoto();
    if (!mounted) return;

    if (image != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto berhasil diambil.'),
          duration: Duration(seconds: 1),
        ),
      );

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PcdEditorView(imageFile: image)),
      );
    } else {
      final message = _visionController.errorMessage ?? 'Gagal mengambil foto.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  Widget _buildActionBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                  foregroundColor: const Color(0xFFBAE6FD),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _uploadImageForManipulation,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload Gambar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _captureAndOpenEditor,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Ambil Foto'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _visionController = VisionController();

    // TASK 2: Request camera permission BEFORE initializing camera
    _requestCameraPermission();

    // Start mock detection (Phase 5)
    _visionController.startMockDetection();
  }

  /// Request camera permission from user
  /// Mandatory for TASK 2: The Camera Eye
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();

    if (!mounted) return;

    if (status.isDenied) {
      // Permission denied by user
      _visionController.setErrorMessage(
        "Akses kamera ditolak. Izin diperlukan untuk mendeteksi kerusakan jalan.",
      );
    } else if (status.isPermanentlyDenied) {
      // User denied permission permanently - direct to settings
      _visionController.setErrorMessage(
        "Izin kamera ditolak secara permanen. Silakan buka Pengaturan untuk mengaktifkan.",
      );
    } else if (status.isGranted || status.isLimited) {
      await _visionController.initCamera();
    } else {
      _visionController.setErrorMessage(
        "Status izin kamera tidak valid untuk memulai preview.",
      );
    }
  }

  @override
  void dispose() {
    // MANDATORY: Disconnect camera when navigating away
    // This prevents memory leaks and battery drain
    _disposeVisionControllerOnce();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        // Ensure camera resource is released immediately when user exits page.
        _disposeVisionControllerOnce();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Smart-Patrol Vision"),
          actions: [
            // Flashlight toggle (Phase 6 UX Enhancement)
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: _visionController.isFlashlightOn
                    ? const Color(0xFFFFC107).withOpacity(0.24)
                    : const Color(0xFF1F2937).withOpacity(0.92),
              ),
              icon: Icon(
                // Ini SUDAH BENAR: Akan berubah antara flash_on dan flash_off
                _visionController.isFlashlightOn
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: _visionController.isFlashlightOn
                    ? const Color(0xFFFFA000)
                    : const Color(0xFFE5E7EB),
              ),
              onPressed: _toggleFlashWithFeedback,
              tooltip: 'Nyalakan/Matikan Flash',
            ),

            // Overlay visibility toggle (Phase 6 UX Enhancement)
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: _visionController.isOverlayVisible
                    ? const Color(0xFF22C55E).withOpacity(0.24)
                    : const Color(0xFF1F2937).withOpacity(0.92),
              ),
              icon: Icon(
                // INI YANG DIUBAH: Akan berubah antara mata terbuka dan mata dicoret
                _visionController.isOverlayVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: _visionController.isOverlayVisible
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFE5E7EB),
              ),
              onPressed: _toggleOverlayWithFeedback,
              tooltip: 'Ikon mata: tampilkan/sembunyikan overlay deteksi',
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _visionController,
          builder: (context, child) {
            // Show loading if camera is initializing
            if (!_visionController.isInitialized) {
              return _buildLoadingState();
            }

            // Continue to Stack structure
            return _buildVisionStack();
          },
        ),
        bottomNavigationBar: _buildActionBar(),
      ),
    );
  }

  /// Build loading state with informative message
  /// TASK 2: Handle permission denied scenario
  /// Phase 6 UX Enhancement
  Widget _buildLoadingState() {
    final hasPermissionError =
        _visionController.errorMessage?.contains("Izin kamera") ?? false;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!hasPermissionError) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              "Menghubungkan ke Sensor Visual...",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ] else ...[
            Icon(Icons.no_photography, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              "Akses Kamera Ditolak",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
          if (_visionController.errorMessage != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _visionController.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            if (hasPermissionError)
              ElevatedButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings),
                label: const Text("Buka Pengaturan"),
              )
            else
              ElevatedButton(
                onPressed: () {
                  _visionController.initCamera();
                },
                child: const Text("Coba Lagi"),
              ),
          ],
        ],
      ),
    );
  }

  /// Build the layered stack architecture
  ///
  /// This is the core of Vision architecture:
  /// - Stack with fit: StackFit.expand fills entire screen
  /// - Layer 1: CameraPreview with AspectRatio to prevent distortion
  /// - Layer 2: CustomPaint for digital overlay
  Widget _buildVisionStack() {
    final previewSize = _visionController.controller!.value.previewSize!;

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Portrait 4:3 frame -> width:height = 3:4.
          final frameWidth = (constraints.maxHeight * 3 / 4).clamp(
            0.0,
            constraints.maxWidth,
          );
          final frameHeight = frameWidth * 4 / 3;

          return SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black),

                  // LAYER 1: Hardware Preview
                  // Keep native ratio and crop to portrait frame without distortion.
                  Center(
                    child: AspectRatio(
                      // Rotated sensor preview in portrait mode.
                      aspectRatio: previewSize.height / previewSize.width,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: previewSize.height,
                          height: previewSize.width,
                          child: CameraPreview(_visionController.controller!),
                        ),
                      ),
                    ),
                  ),

                  // LAYER 2: Digital Overlay (Canvas)
                  // This layer shares the same frame as the camera preview.
                  if (_visionController.isOverlayVisible)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: DamagePainter(
                          _visionController.currentDetections,
                        ), // Phase 4: Will be updated with detections
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
