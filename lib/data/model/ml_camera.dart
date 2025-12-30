import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_object_detection_example/data/entity/recognition.dart';
import 'package:flutter_object_detection_example/data/model/classifier.dart';
import 'package:flutter_object_detection_example/util/image_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

final recognitionsProvider = StateProvider<List<Recognition>>(
  (ref) => <Recognition>[],
);

final mlCameraProvider =
    FutureProvider.autoDispose.family<MLCamera, Size>((ref, size) async {
  final cameras = await availableCameras();
  final cameraController = CameraController(
    cameras[0],
    ResolutionPreset.low,
    enableAudio: false,
  );
  await cameraController.initialize();
  ref.onDispose(cameraController.dispose);
  return MLCamera.create(ref, cameraController, size);
});

class MLCamera {
  MLCamera._(
    this._ref,
    this.cameraController,
    this.cameraViewSize,
    this.classifier,
    this.ratio,
    this.actualPreviewSize,
  );

  static Future<MLCamera> create(
    Ref ref,
    CameraController cameraController,
    Size cameraViewSize,
  ) async {
    final classifier = Classifier();
    await classifier.initialize();

    final previewSize = cameraController.value.previewSize;
    if (previewSize == null) {
      throw StateError('Camera preview size is unavailable.');
    }

    final ratio = Platform.isAndroid
        ? cameraViewSize.width / previewSize.height
        : cameraViewSize.width / previewSize.width;
    final actualPreviewSize = Size(
      cameraViewSize.width,
      cameraViewSize.width * ratio,
    );

    final mlCamera = MLCamera._(
      ref,
      cameraController,
      cameraViewSize,
      classifier,
      ratio,
      actualPreviewSize,
    );
    await cameraController.startImageStream(mlCamera.onLatestImageAvailable);
    return mlCamera;
  }

  final Ref _ref;
  final CameraController cameraController;

  /// スクリーンのサイズ
  final Size cameraViewSize;

  /// アスペクト比
  final double ratio;

  /// 識別器
  final Classifier classifier;

  /// 現在推論中か否か
  bool isPredicting = false;

  /// カメラプレビューの表示サイズ
  final Size actualPreviewSize;

  /// 画像ストリーミングに対する処理
  Future<void> onLatestImageAvailable(CameraImage cameraImage) async {
    if (isPredicting) {
      return;
    }
    isPredicting = true;
    final isolateCamImgData = IsolateData(
      cameraImage: cameraImage,
      interpreterAddress: classifier.interpreter.address,
      labels: classifier.labels,
    );

    // 推論処理は重く、Isolateを使わないと画面が固まる
    _ref.read(recognitionsProvider.notifier).state =
        await compute(inference, isolateCamImgData);
    isPredicting = false;
  }

  /// Isolateへ渡す推論関数
  /// Isolateには、static関数か、クラスに属さないトップレベル関数しか渡せないため、staticに
  static Future<List<Recognition>> inference(
    IsolateData isolateCamImgData,
  ) async {
    var image = ImageUtils.convertYUV420ToImage(
      isolateCamImgData.cameraImage,
    );
    if (Platform.isAndroid) {
      image = image_lib.copyRotate(image, 90);
    }

    final classifier = Classifier(
      interpreter: Interpreter.fromAddress(
        isolateCamImgData.interpreterAddress,
      ),
      labels: isolateCamImgData.labels,
    );
    await classifier.initialize();

    return classifier.predict(image);
  }
}

class IsolateData {
  IsolateData({
    required this.cameraImage,
    required this.interpreterAddress,
    required this.labels,
  });
  final CameraImage cameraImage;
  final int interpreterAddress;
  final List<String> labels;
}
