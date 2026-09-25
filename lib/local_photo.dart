import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Photo prise par l'utilisateur : un fichier sur mobile, une URL blob sur le web
/// (Image.file n'est pas supporté sur le web)
Image localPhoto(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
  int? cacheWidth,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  if (kIsWeb) {
    return Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: errorBuilder,
    );
  }
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    cacheWidth: cacheWidth,
    errorBuilder: errorBuilder,
  );
}
