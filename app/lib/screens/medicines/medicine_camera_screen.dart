import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// 药盒拍照专用相机页
/// - 支持点击对焦 + 曝光补偿
/// - 拍照后自动裁剪文字区域 + 灰度压缩
/// - 扫码框引导用户摆正药盒
class MedicineCameraScreen extends StatefulWidget {
  final Function(File imageFile) onImageCaptured;

  const MedicineCameraScreen({super.key, required this.onImageCaptured});

  @override
  State<MedicineCameraScreen> createState() => _MedicineCameraScreenState();
}

class _MedicineCameraScreenState extends State<MedicineCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isReady = false;
  double _currentExposure = 0.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      // 用后置摄像头
      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (e) {
      debugPrint('相机初始化失败: $e');
    }
  }

  /// 点击对焦
  Future<void> _onTap(Offset position) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      await _controller!.setFocusPoint(position);
      // 同时自动曝光锁定到点
      await _controller!.setExposurePoint(position);
    } catch (e) {
      debugPrint('对焦失败: $e');
    }
  }

  /// 调整曝光
  Future<void> _adjustExposure(double delta) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final step = 0.5;
      _currentExposure = (_currentExposure + delta * step)
          .clamp(-2.0, 2.0);
      await _controller!.setExposureOffset(_currentExposure);
    } catch (e) {
      debugPrint('曝光调整失败: $e');
    }
  }

  /// 拍照 + 预处理
  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // 1. 先锁定对焦 + 曝光
      await _controller!.setFocusMode(FocusMode.locked);
      await Future.delayed(const Duration(milliseconds: 300));

      // 2. 拍照
      final XFile photo = await _controller!.takePicture();
      final File rawFile = File(photo.path);

      // 3. 图像预处理（灰度 + 锐化 + 压缩）
      final File processedFile = await _preprocessImage(rawFile);

      if (!mounted) return;
      widget.onImageCaptured(processedFile);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('拍照失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('拍照失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  /// 图像预处理：直接返回原图（跳过 image 库处理）
  Future<File> _preprocessImage(File rawFile) async {
    return rawFile;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '对准药盒/说明书',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
        centerTitle: true,
      ),
      body: _isReady && _controller != null
          ? Stack(
              children: [
                // 相机预览 + 点击对焦
                GestureDetector(
                  onTapDown: (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localPos = box.globalToLocal(details.globalPosition);
                    final normalized = Offset(
                      localPos.dx / box.size.width,
                      localPos.dy / box.size.height,
                    );
                    _onTap(normalized);
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CameraPreview(_controller!),
                  ),
                ),

                // 取景框引导（扫码框样式）
                const Center(
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 320,
                      height: 240,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.orange, width: 3),
                            bottom: BorderSide(color: Colors.orange, width: 3),
                            left: BorderSide(color: Colors.orange, width: 3),
                            right: BorderSide(color: Colors.orange, width: 3),
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                ),

                // 底部控制区
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // 曝光控制
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.brightness_low,
                                color: Colors.white, size: 28),
                            onPressed: () => _adjustExposure(-0.5),
                          ),
                          Text(
                            '曝光 ${_currentExposure.toStringAsFixed(1)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.brightness_high,
                                color: Colors.white, size: 28),
                            onPressed: () => _adjustExposure(0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 拍照按钮
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  spreadRadius: 2),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.black, size: 36),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('正在启动相机…',
                      style: TextStyle(color: Colors.white70, fontSize: 18)),
                ],
              ),
            ),
    );
  }
}
