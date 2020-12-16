import 'dart:math';

import 'package:flutter_object_detection_example/data/entity/recognition.dart';
import 'package:flutter_object_detection_example/util/logger.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class Classifier {
  Classifier({
    Interpreter interpreter,
    List<String> labels,
  }) {
    loadModel(interpreter);
    loadLabels(labels);
  }
  Interpreter _interpreter;
  Interpreter get interpreter => _interpreter;
  List<String> _labels;
  List<String> get labels => _labels;
  static const String modelFileName = 'detect.tflite';
  static const String labelFileName = 'labelmap.txt';

  /// インタプリタへ入力する画像のサイズ
  static const int inputSize = 300;

  /// 推論結果として表示する閾値
  static const double threshold = 0.6;

  /// 画像の前処理用
  ImageProcessor imageProcessor;

  /// インタプリタから受け取るTensorの次元
  List<List<int>> _outputShapes;

  /// インタプリタから受け取るTensorのデータ型
  List<TfLiteType> _outputTypes;

  /// 推論結果をいくつ表示するか
  static const int numResults = 10;

  /// assetsからインタプリタを読み込み
  Future<void> loadModel(Interpreter interpreter) async {
    try {
      _interpreter = interpreter ??
          await Interpreter.fromAsset(
            '$modelFileName',
            options: InterpreterOptions()..threads = 4,
          );
      final outputTensors = _interpreter.getOutputTensors();
      _outputShapes = [];
      _outputTypes = [];
      for (final tensor in outputTensors) {
        _outputShapes.add(tensor.shape);
        _outputTypes.add(tensor.type);
      }
    } on Exception catch (e) {
      logger.warning(e.toString());
    }
  }

  /// assetsからラベルを読み込み
  Future<void> loadLabels(List<String> labels) async {
    try {
      _labels = labels ?? await FileUtil.loadLabels('$labelFileName');
    } on Exception catch (e) {
      logger.warning(e);
    }
  }

  /// 画像を前処理
  TensorImage getProcessedImage(TensorImage inputImage) {
    // 画像をパディングし正方形に変換
    final padSize = max(
      inputImage.height,
      inputImage.width,
    );

    imageProcessor ??= ImageProcessorBuilder()
        .add(
          // 画像を高さに合わせてクロップorパディング
          ResizeWithCropOrPadOp(
            padSize,
            padSize,
          ),
        )
        // バイリニア補間で、画像をリサイズ
        .add(
          ResizeOp(
            inputSize,
            inputSize,
            ResizeMethod.BILINEAR,
          ),
        )
        .build();
    return imageProcessor.process(inputImage);
  }

  /// 物体検出を行う
  List<Recognition> predict(image_lib.Image image) {
    if (_interpreter == null) {
      return null;
    }

    // ImageからTensorImageを作成
    var inputImage = TensorImage.fromImage(image);
    // TensorImageを前処理
    inputImage = getProcessedImage(inputImage);

    // これらのTensorBufferで、推論結果を受け取る
    final outputLocations = TensorBufferFloat(_outputShapes[0]);
    final outputClasses = TensorBufferFloat(_outputShapes[1]);
    final outputScores = TensorBufferFloat(_outputShapes[2]);
    final numLocations = TensorBufferFloat(_outputShapes[3]);

    // runForMultipleInputsへの入力オブジェクト
    final inputs = [inputImage.buffer];
    final outputs = {
      0: outputLocations.buffer,
      1: outputClasses.buffer,
      2: outputScores.buffer,
      3: numLocations.buffer,
    };

    // 推論！
    _interpreter.runForMultipleInputs(inputs, outputs);

    // 推論結果をいくつ返すか
    final resultCount = min(numResults, numLocations.getIntValue(0));

    const labelOffset = 1;

    // バウンディングボックスを表す値を矩形に変換
    final locations = BoundingBoxUtils.convert(
      tensor: outputLocations,
      valueIndex: [1, 0, 3, 2],
      boundingBoxAxis: 2,
      boundingBoxType: BoundingBoxType.BOUNDARIES,
      coordinateType: CoordinateType.RATIO,
      height: inputSize,
      width: inputSize,
    );

    // 推論結果からRecognitionを作成
    final recognitions = <Recognition>[];
    for (var i = 0; i < resultCount; i++) {
      final score = outputScores.getDoubleValue(i);
      final labelIndex = outputClasses.getIntValue(i) + labelOffset;
      final label = _labels.elementAt(labelIndex);
      if (score > threshold) {
        final transformRect = imageProcessor.inverseTransformRect(
          locations[i],
          image.height,
          image.width,
        );
        recognitions.add(
          Recognition(i, label, score, transformRect),
        );
      }
    }
    return recognitions;
  }
}
