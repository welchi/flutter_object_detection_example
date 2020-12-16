import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_playground/data/model/entities/entities.dart';
import 'package:flutter_playground/data/model/model.dart';
import 'package:flutter_playground/util/image_utils.dart';
import 'package:flutter_playground/util/logger.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

final recognitionsProvider = StateProvider<List<Recognition>>((ref) => []);

final mlCameraProvider = FutureProvider.autoDispose<MLCamera>((ref) async {
  final cameras = await availableCameras();
  final cameraController = CameraController(
    cameras[0],
    ResolutionPreset.low,
    enableAudio: false,
  );
  await cameraController.initialize();
  final mlCamera = MLCamera(
    ref.read,
    cameraController,
  );
  return mlCamera;
});

class MLCamera {
  MLCamera(
    this._read,
    this.cameraController,
  ) {
    Future(() async {
      classifier = Classifier();
      viewSize = ScreenUtil().uiSize;
      initScreenInfo(viewSize);
      await cameraController.startImageStream(onLatestImageAvailable);
    });
  }
  final Reader _read;
  final CameraController cameraController;
  // Size inputImageSize;
  // Size get inputImageSize => cameraController.value.previewSize;
  Size get actualPreviewSize => Size(
        viewSize.width,
        viewSize.width * ratio,
      );
  Size viewSize;
  double get ratio => Platform.isAndroid
      ? viewSize.width / cameraController.value.previewSize.height
      : viewSize.width / cameraController.value.previewSize.width;
  Classifier classifier;
  bool isPredicting = false;

  void initScreenInfo(Size cameraViewSize) {
    // コントローラがキャプチャした、各画像フレームのサイズ
    // final previewSize = cameraController.value.previewSize;
    // logger.info('previewSize: $previewSize');
    // inputImageSize = previewSize;
    viewSize = cameraViewSize;
    logger.info('screenSize: $viewSize');
    // if (Platform.isAndroid) {
    //   ratio = viewSize.width / previewSize.height;
    // } else {
    //   ratio = viewSize.width / previewSize.width;
    // }
  }

  Future<void> onLatestImageAvailable(CameraImage cameraImage) async {
    if (classifier.interpreter == null || classifier.labels == null) {
      return;
    }
    if (isPredicting) {
      return;
    }
    isPredicting = true;
    final isolateCamImgData = _IsolateCamImgData(
      cameraImage: cameraImage,
      interpreterAddress: classifier.interpreter.address,
      labels: classifier.labels,
    );
    _read(recognitionsProvider).state =
        await compute(inference, isolateCamImgData);
    isPredicting = false;
  }

  static Future<List<Recognition>> inference(
      _IsolateCamImgData isolateCamImgData) async {
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

    return classifier.predict(image);
  }
}

class _IsolateCamImgData {
  _IsolateCamImgData({
    this.cameraImage,
    this.interpreterAddress,
    this.labels,
  });
  final CameraImage cameraImage;
  final int interpreterAddress;
  final List<String> labels;
  SendPort responsePort;
}
