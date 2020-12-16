import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_object_detection_example/data/entity/recognition.dart';
import 'package:flutter_object_detection_example/data/model/ml_camera.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ObjectDetectionPage extends HookWidget {
  static String routeName = '/object_detection';
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mlCamera = useProvider(mlCameraProvider(size));
    final recognitions = useProvider(recognitionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
      ),
      body: mlCamera.when(
        data: (mlCamera) => Stack(
          children: [
            // カメラプレビューを表示
            CameraView(
              mlCamera.cameraController,
            ),
            // バウンディングボックスを表示
            buildBoxes(
              recognitions.state,
              mlCamera.actualPreviewSize,
              mlCamera.ratio,
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Text(
            err.toString(),
          ),
        ),
      ),
    );
  }

  /// バウンディングボックスを構築
  Widget buildBoxes(
    List<Recognition> recognitions,
    Size actualPreviewSize,
    double ratio,
  ) {
    if (recognitions == null || recognitions.isEmpty) {
      return const SizedBox();
    }
    return Stack(
      children: recognitions.map((result) {
        return BoundingBox(
          result,
          actualPreviewSize,
          ratio,
        );
      }).toList(),
    );
  }
}

class CameraView extends StatelessWidget {
  const CameraView(
    this.cameraController,
  );
  final CameraController cameraController;
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: cameraController.value.aspectRatio,
      child: CameraPreview(cameraController),
    );
  }
}

class BoundingBox extends HookWidget {
  const BoundingBox(
    this.result,
    this.actualPreviewSize,
    this.ratio,
  );
  final Recognition result;
  final Size actualPreviewSize;
  final double ratio;
  @override
  Widget build(BuildContext context) {
    final renderLocation = result.getRenderLocation(
      actualPreviewSize,
      ratio,
    );
    return Positioned(
      left: renderLocation.left,
      top: renderLocation.top,
      width: renderLocation.width,
      height: renderLocation.height,
      child: Container(
        width: renderLocation.width,
        height: renderLocation.height,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).accentColor,
            width: 3,
          ),
          borderRadius: const BorderRadius.all(
            Radius.circular(2),
          ),
        ),
        child: buildBoxLabel(result, context),
      ),
    );
  }

  Align buildBoxLabel(Recognition result, BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: FittedBox(
        child: ColoredBox(
          color: Theme.of(context).accentColor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.label,
              ),
              Text(
                ' ${result.score.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
