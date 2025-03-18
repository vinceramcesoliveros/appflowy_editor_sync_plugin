import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';

// Converter for Uint32List
class Uint32ListConverter implements JsonConverter<Uint32List, List<dynamic>> {
  const Uint32ListConverter();

  @override
  Uint32List fromJson(List<dynamic> json) {
    return Uint32List.fromList(json.cast<int>());
  }

  @override
  List<int> toJson(Uint32List object) {
    return object.toList();
  }
}
