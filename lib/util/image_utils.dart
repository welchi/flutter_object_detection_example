import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;

/// ImageUtils
/// https://gist.github.com/am15h/e7c9da2e123642aa6452a2baa96c3ff3#file-image_utils-dart

/// Converts a [CameraImage] in YUV420 format to
/// [image_lib.Image] in RGB format.
image_lib.Image convertYUV420ToImage(CameraImage cameraImage) {
  final width = cameraImage.width;
  final height = cameraImage.height;

  final uvRowStride = cameraImage.planes[1].bytesPerRow;
  final uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

  final image = image_lib.Image(width, height);

  for (var w = 0; w < width; w++) {
    for (var h = 0; h < height; h++) {
      final uvIndex =
          uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
      final index = h * width + w;

      final y = cameraImage.planes[0].bytes[index];
      final u = cameraImage.planes[1].bytes[uvIndex];
      final v = cameraImage.planes[2].bytes[uvIndex];

      image.data[index] = yuv2rgb(y, u, v);
    }
  }
  return image;
}

/// Convert a single YUV pixel to RGB.
int yuv2rgb(int y, int u, int v) {
  // Convert yuv pixel to rgb
  var r = (y + v * 1436 / 1024 - 179).round();
  var g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
  var b = (y + u * 1814 / 1024 - 227).round();

  // Clipping RGB values to be inside boundaries [ 0 , 255 ]
  r = r < 0 ? 0 : (r > 255 ? 255 : r);
  g = g < 0 ? 0 : (g > 255 ? 255 : g);
  b = b < 0 ? 0 : (b > 255 ? 255 : b);

  return 0xff000000 |
      ((b << 16) & 0xff0000) |
      ((g << 8) & 0xff00) |
      (r & 0xff);
}
