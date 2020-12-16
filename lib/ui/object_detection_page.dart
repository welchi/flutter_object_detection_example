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
    final recognitions = useProvider(recognitionsProvider);
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
      ),
      body: Stack(
        children: [
          AspectRatio(
            aspectRatio:
                odController.mlCamera.cameraController.value.aspectRatio,
            child: CameraPreview(
              odController.mlCamera.cameraController,
            ),
          ),
          buildBoxes(
            recognitions.state,
          ),
        ],
      ),
    );
  }

  Widget buildBoxes(
    List<Recognition> recognitions,
  ) {
    if (recognitions == null || recognitions.isEmpty) {
      return const SizedBox();
    }
    return Stack(
      children: recognitions.map((result) {
        return BoundingBox(result);
      }).toList(),
    );
  }
}

// class _CameraView extends HookWidget {
//   const _CameraView({
//     Key key,
//   }) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     final odController = useProvider(
//       objectDetectionControllerProvider,
//     );
//     final size = MediaQuery.of(context).size;
//     odController.mlCamera.initScreenInfo(size);
//     logger.info('mediaSize: ${size.toString()}');
//     return AspectRatio(
//       aspectRatio: odController.mlCamera.cameraController.value.aspectRatio,
//       child: CameraPreview(
//         odController.mlCamera.cameraController,
//       ),
//     );
//   }
// }

class BoundingBox extends HookWidget {
  const BoundingBox(
    this.result,
  );
  final Recognition result;

  @override
  Widget build(BuildContext context) {
    final odController = useProvider(
      objectDetectionControllerProvider,
    );
    final renderLocation = result.getRenderLocation(
      odController.mlCamera.actualPreviewSize,
      odController.mlCamera.ratio,
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
            color: Colors.red,
            width: 3,
          ),
          borderRadius: const BorderRadius.all(
            Radius.circular(2),
          ),
        ),
        child: buildBoxLabel(result),
      ),
    );
  }

  Align buildBoxLabel(Recognition result) {
    return Align(
      alignment: Alignment.topLeft,
      child: FittedBox(
        child: ColoredBox(
          color: Colors.blue,
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
