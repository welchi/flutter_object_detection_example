import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_object_detection_example/data/entity/recognition.dart';
import 'package:flutter_object_detection_example/data/model/ml_camera.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ObjectDetectionPage extends HookConsumerWidget {
  const ObjectDetectionPage({super.key});

  static const String routeName = '/object_detection';
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final AsyncValue<MLCamera> mlCamera = ref.watch(mlCameraProvider(size));
    final List<Recognition> recognitions = ref.watch(recognitionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
      ),
      body: mlCamera.when(
        // MLCameraセットアップ後の表示
        data: (mlCamera) => Stack(
          children: [
            // カメラプレビューを表示
            CameraView(
              mlCamera.cameraController,
            ),
            // バウンディングボックスを表示
            buildBoxes(
              recognitions,
              mlCamera.actualPreviewSize,
              mlCamera.ratio,
            ),
          ],
        ),
        // MLCamera読み込み中の表示
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        // エラー時の表示
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
    if (recognitions.isEmpty) {
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
    this.cameraController, {
    super.key,
  });
  final CameraController cameraController;
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: cameraController.value.aspectRatio,
      child: CameraPreview(cameraController),
    );
  }
}

class BoundingBox extends StatelessWidget {
  const BoundingBox(
    this.result,
    this.actualPreviewSize,
    this.ratio, {
    super.key,
  });
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
            color: Theme.of(context).colorScheme.secondary,
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

  /// 認識結果のラベルを表示
  Align buildBoxLabel(Recognition result, BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: FittedBox(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.secondary,
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
