import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// VisionController manages the camera lifecycle and detection logic
/// for the Smart Patrol System.
///
/// This controller follows SOLID principles:
/// - Single Responsibility: Manages only camera and detection state
/// - Open/Closed: Can be extended without modifying core logic
/// - Dependency Inversion: Depends on abstractions (ChangeNotifier)
class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  // Camera controller instance
  CameraController? controller;

  // State tracking
  bool isInitialized = false;
  String? errorMessage;

  // Detection results (for Phase 5)
  List<DetectionResult> currentDetections = [];
  Timer? _mockDetectionTimer;

  // UX Enhancement: Flashlight and Overlay toggles (Phase 6)
  bool isFlashlightOn = false;
  bool isFlashSupported = true;
  bool isOverlayVisible = true;

  VisionController() {
    // Register observer to monitor app lifecycle status
    WidgetsBinding.instance.addObserver(this);
  }

  /// Initialize the rear camera with medium resolution
  /// ResolutionPreset.medium balances AI accuracy with performance
  Future<void> initCamera() async {
    if (isInitialized) {
      return;
    }

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        errorMessage = "No camera detected on device.";
        notifyListeners();
        return;
      }

      // Select Rear Camera (Index 0)
      controller = CameraController(
        cameras[0],
        // Task requirement: medium preset balances quality and performance.
        ResolutionPreset.medium,
        enableAudio: false, // We only need visual for road damage detection
        imageFormatGroup:
            ImageFormatGroup.jpeg, // Use JPEG format for better compatibility
      );

      await controller!.initialize();

      // Keep flash disabled by default when camera starts.
      try {
        await controller!.setFlashMode(FlashMode.off);
        isFlashSupported = true;
        isFlashlightOn = false;
      } catch (_) {
        isFlashSupported = false;
        isFlashlightOn = false;
      }

      isInitialized = true;
      errorMessage = null;
    } catch (e) {
      errorMessage = "Failed to initialize camera: $e";
      isInitialized = false;
    }

    notifyListeners();
  }

  /// Update the visible error message and notify listeners.
  void setErrorMessage(String message) {
    errorMessage = message;
    notifyListeners();
  }

  /// Capture photo from camera stream
  /// This ensures full frame capture with proper resolution
  Future<XFile?> takePhoto() async {
    final cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return null;
    }
    if (cameraController.value.isTakingPicture) {
      return null;
    }

    try {
      return await cameraController.takePicture();
    } on CameraException catch (e) {
      setErrorMessage("Gagal mengambil foto: ${e.description ?? e.code}");
      return null;
    } catch (e) {
      setErrorMessage("Gagal mengambil foto: $e");
      return null;
    }
  }

  /// Handle app lifecycle state changes
  ///
  /// This is CRITICAL for preventing memory leaks and battery drain
  /// - AppLifecycleState.inactive: Release camera when app goes to background
  /// - AppLifecycleState.resumed: Re-initialize camera when app returns to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // If controller doesn't exist or isn't ready, ignore
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // Release camera resource when app is not visible
      cameraController.dispose();
      controller = null;
      isInitialized = false;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize when user returns to app
      initCamera();
    }
  }

  /// Toggle flashlight (torch) on/off
  /// UX Enhancement from Phase 6
  Future<bool> toggleFlashlight() async {
    final cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return false;
    }
    if (!isFlashSupported) {
      setErrorMessage("Flash tidak tersedia pada kamera ini.");
      return false;
    }

    final targetState = !isFlashlightOn;

    try {
      await cameraController.setFlashMode(
        targetState ? FlashMode.torch : FlashMode.off,
      );
      isFlashlightOn = targetState;
    } catch (e) {
      isFlashSupported = false;
      setErrorMessage("Gagal mengaktifkan flash: $e");
      return false;
    }

    notifyListeners();
    return true;
  }

  /// Toggle overlay visibility
  /// UX Enhancement from Phase 6
  void toggleOverlay() {
    isOverlayVisible = !isOverlayVisible;
    notifyListeners();
  }

  /// Start mock detection simulation
  /// Phase 5: Simulates AI detection by moving bounding box every 3 seconds
  void startMockDetection() {
    _mockDetectionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => _generateMockDetection(),
    );
  }

  /// Generate a mock detection result at random position
  /// This simulates YOLO output before actual AI integration in Module 7
  void _generateMockDetection() {
    final random = Random();

    // Generate random normalized coordinates (0.0 - 1.0)
    // Keep within 10%-90% range to avoid edge clipping
    final x = random.nextDouble() * 0.8 + 0.1;
    final y = random.nextDouble() * 0.8 + 0.1;
    final width = 0.2 + random.nextDouble() * 0.2; // 20%-40% of screen width
    final height = 0.1 + random.nextDouble() * 0.1; // 10%-20% of screen height

    // Create detection result
    currentDetections = [
      DetectionResult(
        box: Rect.fromLTWH(x, y, width, height),
        label: _getRandomDamageType(),
        score: 0.85 + random.nextDouble() * 0.14, // 85%-99% confidence
      ),
    ];

    notifyListeners();
  }

  /// Get a random damage type from RDD-2022 dataset
  String _getRandomDamageType() {
    final types = ['D00', 'D10', 'D20', 'D40'];
    final labels = {
      'D00': 'Longitudinal Crack',
      'D10': 'Transverse Crack',
      'D20': 'Alligator Crack',
      'D40': 'Pothole',
    };
    final type = types[Random().nextInt(types.length)];
    return ' [$type] ${labels[type]!}';
  }

  /// Clean up resources
  ///
  /// This is MANDATORY to prevent memory leaks
  /// - Remove observer to stop listening to lifecycle events
  /// - Dispose camera controller to release hardware
  /// - Cancel mock detection timer
  @override
  void dispose() {
    // Remove observer to prevent memory leak
    WidgetsBinding.instance.removeObserver(this);

    // Cancel mock detection timer
    _mockDetectionTimer?.cancel();

    // Release camera hardware
    controller?.dispose();
    controller = null;

    super.dispose();
  }
}

/// Data Transfer Object (DTO) for detection results
///
/// This follows the Single Responsibility Principle:
/// - VisionController generates these objects
/// - DamagePainter only draws them
///
/// If you replace YOLO with another model, only change data population
/// in VisionController without touching UI or Painter code.
class DetectionResult {
  final Rect box; // Box coordinates (normalized 0.0-1.0)
  final String label; // Damage type (D40, D20, etc)
  final double score; // AI confidence percentage (0.0-1.0)

  DetectionResult({
    required this.box,
    required this.label,
    required this.score,
  });
}
