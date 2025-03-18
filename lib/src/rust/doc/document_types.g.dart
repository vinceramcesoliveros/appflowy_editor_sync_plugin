// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BlockActionDoc _$BlockActionDocFromJson(Map<String, dynamic> json) =>
    _BlockActionDoc(
      action: $enumDecode(_$BlockActionTypeDocEnumMap, json['action']),
      block: BlockDoc.fromJson(json['block'] as Map<String, dynamic>),
      path: const Uint32ListConverter().fromJson(json['path'] as List),
      oldPath: _$JsonConverterFromJson<List<dynamic>, Uint32List>(
        json['oldPath'],
        const Uint32ListConverter().fromJson,
      ),
    );

Map<String, dynamic> _$BlockActionDocToJson(_BlockActionDoc instance) =>
    <String, dynamic>{
      'action': _$BlockActionTypeDocEnumMap[instance.action]!,
      'block': instance.block,
      'path': const Uint32ListConverter().toJson(instance.path),
      'oldPath': _$JsonConverterToJson<List<dynamic>, Uint32List>(
        instance.oldPath,
        const Uint32ListConverter().toJson,
      ),
    };

const _$BlockActionTypeDocEnumMap = {
  BlockActionTypeDoc.insert: 'insert',
  BlockActionTypeDoc.update: 'update',
  BlockActionTypeDoc.delete: 'delete',
  BlockActionTypeDoc.move: 'move',
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

_BlockDoc _$BlockDocFromJson(Map<String, dynamic> json) => _BlockDoc(
  id: json['id'] as String,
  ty: json['ty'] as String,
  attributes: Map<String, String>.from(json['attributes'] as Map),
  delta: json['delta'] as String?,
  parentId: json['parentId'] as String?,
  prevId: json['prevId'] as String?,
  oldParentId: json['oldParentId'] as String?,
);

Map<String, dynamic> _$BlockDocToJson(_BlockDoc instance) => <String, dynamic>{
  'id': instance.id,
  'ty': instance.ty,
  'attributes': instance.attributes,
  'delta': instance.delta,
  'parentId': instance.parentId,
  'prevId': instance.prevId,
  'oldParentId': instance.oldParentId,
};

_DocumentState _$DocumentStateFromJson(Map<String, dynamic> json) =>
    _DocumentState(
      docId: json['docId'] as String,
      blocks: (json['blocks'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, BlockDoc.fromJson(e as Map<String, dynamic>)),
      ),
      childrenMap: (json['childrenMap'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
    );

Map<String, dynamic> _$DocumentStateToJson(_DocumentState instance) =>
    <String, dynamic>{
      'docId': instance.docId,
      'blocks': instance.blocks,
      'childrenMap': instance.childrenMap,
    };

_FailedToDecodeUpdates _$FailedToDecodeUpdatesFromJson(
  Map<String, dynamic> json,
) => _FailedToDecodeUpdates(
  failedUpdatesIds:
      (json['failedUpdatesIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
);

Map<String, dynamic> _$FailedToDecodeUpdatesToJson(
  _FailedToDecodeUpdates instance,
) => <String, dynamic>{'failedUpdatesIds': instance.failedUpdatesIds};
