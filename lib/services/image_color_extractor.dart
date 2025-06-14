import 'dart:async';
import 'dart:ui' as ui;
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

/// 画像から支配的な色を抽出するサービス
class ImageColorExtractor {
  // キャッシュ管理
  static final Map<String, Future<Color?>> _colorCache = {};
  
  /// 画像URLから支配的な色を抽出
  static Future<Color?> extractDominantColor(String imageUrl) async {
    if (_colorCache.containsKey(imageUrl)) {
      return await _colorCache[imageUrl];
    }

    final completer = Completer<Color?>();
    _colorCache[imageUrl] = completer.future;

    try {
      final imageProvider = NetworkImage(imageUrl);
      final imageStream = imageProvider.resolve(const ImageConfiguration());

      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo imageInfo, bool synchronousCall) async {
          try {
            final color = await _processImage(imageInfo.image, imageUrl);
            completer.complete(color);
          } catch (e) {
            developer.log('Error processing image for $imageUrl: $e', name: 'ImageColorExtractor');
            completer.complete(null);
          } finally {
            imageStream.removeListener(listener);
          }
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          developer.log('Error loading image for $imageUrl: $exception', name: 'ImageColorExtractor');
          completer.complete(null);
          imageStream.removeListener(listener);
        },
      );
      
      imageStream.addListener(listener);
    } catch (e) {
      developer.log('Error setting up image processing for $imageUrl: $e', name: 'ImageColorExtractor');
      completer.complete(null);
    }

    return completer.future;
  }

  /// UI画像から支配的な色を抽出
  static Future<Color?> _processImage(ui.Image uiImage, String imageUrl) async {
    const int pixelSampleStep = 40; // 10ピクセルごとにサンプリング
    const int minAlpha = 200;
    const int minColorValue = 30;
    const int maxColorValue = 225;
    const int fallbackMinColorValue = 20;
    const int fallbackMaxColorValue = 235;

    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    
    if (byteData == null || byteData.lengthInBytes == 0) {
      developer.log('No pixel data available for $imageUrl', name: 'ImageColorExtractor');
      return null;
    }

    final pixels = byteData.buffer.asUint8List();
    
    // 最頻色を見つける
    Color? mostFrequentColor = _findMostFrequentColor(
      pixels, 
      pixelSampleStep, 
      minAlpha, 
      minColorValue, 
      maxColorValue
    );

    // フォールバック: より緩い条件で再試行
    if (mostFrequentColor == null && pixels.isNotEmpty) {
      mostFrequentColor = _findFirstValidColor(
        pixels, 
        minAlpha, 
        fallbackMinColorValue, 
        fallbackMaxColorValue
      );
    }

    if (mostFrequentColor != null) {
      developer.log('Dominant color found for $imageUrl: #${mostFrequentColor.value.toRadixString(16)}', name: 'ImageColorExtractor');
    } else {
      developer.log('Could not determine dominant color for $imageUrl', name: 'ImageColorExtractor');
    }

    return mostFrequentColor;
  }

  /// ピクセル配列から最頻色を見つける
  static Color? _findMostFrequentColor(
    List<int> pixels, 
    int sampleStep, 
    int minAlpha, 
    int minColorValue, 
    int maxColorValue
  ) {
    final Map<int, int> colorCounts = {};
    int maxCount = 0;
    Color? mostFrequentColor;

    for (int i = 0; i < pixels.length; i += 4 * sampleStep) {
      if (i + 3 < pixels.length) {
        final color = _createColorFromPixels(pixels, i);
        
        if (_isValidColor(color, minAlpha, minColorValue, maxColorValue)) {
          final colorValue = color.value;
          colorCounts[colorValue] = (colorCounts[colorValue] ?? 0) + 1;
          
          if (colorCounts[colorValue]! > maxCount) {
            maxCount = colorCounts[colorValue]!;
            mostFrequentColor = color;
          }
        }
      }
    }

    return mostFrequentColor;
  }

  /// 最初の有効な色を見つける（フォールバック用）
  static Color? _findFirstValidColor(
    List<int> pixels, 
    int minAlpha, 
    int minColorValue, 
    int maxColorValue
  ) {
    for (int i = 0; i < pixels.length; i += 4) {
      if (i + 3 < pixels.length) {
        final color = _createColorFromPixels(pixels, i);
        
        if (_isValidColor(color, minAlpha, minColorValue, maxColorValue)) {
          return color;
        }
      }
    }
    return null;
  }

  /// ピクセル配列から色を作成
  static Color _createColorFromPixels(List<int> pixels, int index) {
    return Color.fromARGB(
      pixels[index + 3], // A
      pixels[index],     // R
      pixels[index + 1], // G
      pixels[index + 2], // B
    );
  }

  /// 色が有効かどうかを判定
  static bool _isValidColor(Color color, int minAlpha, int minColorValue, int maxColorValue) {
    return color.alpha > minAlpha &&
           (color.red > minColorValue || color.green > minColorValue || color.blue > minColorValue) &&
           (color.red < maxColorValue || color.green < maxColorValue || color.blue < maxColorValue);
  }

  /// キャッシュをクリア
  static void clearCache() {
    _colorCache.clear();
  }

  /// 特定のURLのキャッシュを削除
  static void removeCacheEntry(String imageUrl) {
    _colorCache.remove(imageUrl);
  }
}
