import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/device_cameras.dart';
import '../services/photo_source.dart';
import '../theme.dart';

/// Live viewfinder. Pops the captured JPEG bytes back to the caller rather
/// than navigating onward itself, so the same result screen serves the camera
/// and the photo library.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _torchOn = false;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android reclaims the camera when the app goes to the background, so the
    // controller has to be rebuilt on the way back.
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _start();
    }
  }

  Future<void> _start() async {
    if (deviceCameras.isEmpty) {
      setState(() => _error = 'No camera on this device.');
      return;
    }

    final rear = deviceCameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => deviceCameras.first,
    );

    final controller = CameraController(
      rear,
      // 720p is ample for identification and keeps the upload small.
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
        _torchOn = false;
      });
    } on CameraException catch (exception) {
      setState(
        () => _error = switch (exception.code) {
          'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
            'Camera access is off for this app. Turn it on in Settings, or '
                'choose a photo from your library instead.',
          _ => 'The camera could not start. Choose a photo instead.',
        },
      );
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final next = !_torchOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _torchOn = next);
    } on CameraException {
      // Plenty of front cameras and emulators have no torch. Not worth a message.
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;

    setState(() => _capturing = true);
    try {
      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();
      if (mounted) Navigator.of(context).pop<Uint8List>(bytes);
    } on CameraException {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That shot did not save. Try again.')),
      );
    }
  }

  Future<void> _useLibrary() async {
    final bytes = await pickPhotoFromLibrary();
    if (bytes != null && mounted) Navigator.of(context).pop<Uint8List>(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Botanic.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFF2F5EE),
        title: const Text('Frame the plant'),
        actions: [
          if (controller != null)
            IconButton(
              onPressed: _toggleTorch,
              tooltip: _torchOn ? 'Turn off the light' : 'Turn on the light',
              icon: Icon(_torchOn ? Icons.flashlight_on : Icons.flashlight_off),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: switch ((controller, _error)) {
                (_, final String message) => _CameraProblem(
                  message: message,
                  onChoosePhoto: _useLibrary,
                ),
                (final CameraController ready, _) => AspectRatio(
                  aspectRatio: 1 / ready.value.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(ready),
                      const IgnorePointer(child: _Reticle()),
                    ],
                  ),
                ),
                _ => const CircularProgressIndicator(
                  color: Botanic.chlorophyll,
                ),
              },
            ),
          ),
          if (_error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _useLibrary,
                    tooltip: 'Choose a photo',
                    iconSize: 26,
                    color: const Color(0xFFF2F5EE),
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  Expanded(
                    child: Center(
                      child: _ShutterButton(
                        busy: _capturing,
                        onPressed: controller == null ? null : _capture,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take the photo',
      child: GestureDetector(
        onTap: busy ? null : onPressed,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: busy ? Botanic.inkSoft : Botanic.chlorophyll,
            border: Border.all(color: const Color(0xFFF2F5EE), width: 4),
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFF2F5EE),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Corner brackets over the preview, matching the frame on the home screen so
/// the two read as the same gesture.
class _Reticle extends StatelessWidget {
  const _Reticle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Stack(
        children: [
          for (final (corner, turns) in const [
            (Alignment.topLeft, 0),
            (Alignment.topRight, 1),
            (Alignment.bottomRight, 2),
            (Alignment.bottomLeft, 3),
          ])
            Align(
              alignment: corner,
              child: RotatedBox(
                quarterTurns: turns,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFF2F5EE).withValues(alpha: 0.9),
                        width: 3,
                      ),
                      left: BorderSide(
                        color: const Color(0xFFF2F5EE).withValues(alpha: 0.9),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.message, required this.onChoosePhoto});

  final String message;
  final VoidCallback onChoosePhoto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined, size: 40, color: Botanic.hairline),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFE6EBE1),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onChoosePhoto,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose a photo'),
          ),
        ],
      ),
    );
  }
}
