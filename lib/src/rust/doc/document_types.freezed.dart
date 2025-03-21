// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document_types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BlockActionDoc _$BlockActionDocFromJson(Map<String, dynamic> json) {
  return _BlockActionDoc.fromJson(json);
}

/// @nodoc
mixin _$BlockActionDoc {
  BlockActionTypeDoc get action => throw _privateConstructorUsedError;
  BlockDoc get block => throw _privateConstructorUsedError;
  Uint32List get path => throw _privateConstructorUsedError;
  Uint32List? get oldPath => throw _privateConstructorUsedError;

  /// Serializes this BlockActionDoc to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BlockActionDoc
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BlockActionDocCopyWith<BlockActionDoc> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BlockActionDocCopyWith<$Res> {
  factory $BlockActionDocCopyWith(
    BlockActionDoc value,
    $Res Function(BlockActionDoc) then,
  ) = _$BlockActionDocCopyWithImpl<$Res, BlockActionDoc>;
  @useResult
  $Res call({
    BlockActionTypeDoc action,
    BlockDoc block,
    Uint32List path,
    Uint32List? oldPath,
  });

  $BlockDocCopyWith<$Res> get block;
}

/// @nodoc
class _$BlockActionDocCopyWithImpl<$Res, $Val extends BlockActionDoc>
    implements $BlockActionDocCopyWith<$Res> {
  _$BlockActionDocCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BlockActionDoc
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? action = null,
    Object? block = null,
    Object? path = null,
    Object? oldPath = freezed,
  }) {
    return _then(
      _value.copyWith(
            action:
                null == action
                    ? _value.action
                    : action // ignore: cast_nullable_to_non_nullable
                        as BlockActionTypeDoc,
            block:
                null == block
                    ? _value.block
                    : block // ignore: cast_nullable_to_non_nullable
                        as BlockDoc,
            path:
                null == path
                    ? _value.path
                    : path // ignore: cast_nullable_to_non_nullable
                        as Uint32List,
            oldPath:
                freezed == oldPath
                    ? _value.oldPath
                    : oldPath // ignore: cast_nullable_to_non_nullable
                        as Uint32List?,
          )
          as $Val,
    );
  }

  /// Create a copy of BlockActionDoc
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BlockDocCopyWith<$Res> get block {
    return $BlockDocCopyWith<$Res>(_value.block, (value) {
      return _then(_value.copyWith(block: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BlockActionDocImplCopyWith<$Res>
    implements $BlockActionDocCopyWith<$Res> {
  factory _$$BlockActionDocImplCopyWith(
    _$BlockActionDocImpl value,
    $Res Function(_$BlockActionDocImpl) then,
  ) = __$$BlockActionDocImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    BlockActionTypeDoc action,
    BlockDoc block,
    Uint32List path,
    Uint32List? oldPath,
  });

  @override
  $BlockDocCopyWith<$Res> get block;
}

/// @nodoc
class __$$BlockActionDocImplCopyWithImpl<$Res>
    extends _$BlockActionDocCopyWithImpl<$Res, _$BlockActionDocImpl>
    implements _$$BlockActionDocImplCopyWith<$Res> {
  __$$BlockActionDocImplCopyWithImpl(
    _$BlockActionDocImpl _value,
    $Res Function(_$BlockActionDocImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BlockActionDoc
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? action = null,
    Object? block = null,
    Object? path = null,
    Object? oldPath = freezed,
  }) {
    return _then(
      _$BlockActionDocImpl(
        action:
            null == action
                ? _value.action
                : action // ignore: cast_nullable_to_non_nullable
                    as BlockActionTypeDoc,
        block:
            null == block
                ? _value.block
                : block // ignore: cast_nullable_to_non_nullable
                    as BlockDoc,
        path:
            null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                    as Uint32List,
        oldPath:
            freezed == oldPath
                ? _value.oldPath
                : oldPath // ignore: cast_nullable_to_non_nullable
                    as Uint32List?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BlockActionDocImpl implements _BlockActionDoc {
  const _$BlockActionDocImpl({
    required this.action,
    required this.block,
    required this.path,
    this.oldPath,
  });

  factory _$BlockActionDocImpl.fromJson(Map<String, dynamic> json) =>
      _$$BlockActionDocImplFromJson(json);

  @override
  final BlockActionTypeDoc action;
  @override
  final BlockDoc block;
  @override
  final Uint32List path;
  @override
  final Uint32List? oldPath;

  @override
  String toString() {
    return 'BlockActionDoc(action: $action, block: $block, path: $path, oldPath: $oldPath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlockActionDocImpl &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.block, block) || other.block == block) &&
            const DeepCollectionEquality().equals(other.path, path) &&
            const DeepCollectionEquality().equals(other.oldPath, oldPath));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    action,
    block,
    const DeepCollectionEquality().hash(path),
    const DeepCollectionEquality().hash(oldPath),
  );

  /// Create a copy of BlockActionDoc
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BlockActionDocImplCopyWith<_$BlockActionDocImpl> get copyWith =>
      __$$BlockActionDocImplCopyWithImpl<_$BlockActionDocImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BlockActionDocImplToJson(this);
  }
}

abstract class _BlockActionDoc implements BlockActionDoc {
  const factory _BlockActionDoc({
    required final BlockActionTypeDoc action,
    required final BlockDoc block,
    required final Uint32List path,
    final Uint32List? oldPath,
  }) = _$BlockActionDocImpl;

  factory _BlockActionDoc.fromJson(Map<String, dynamic> json) =
      _$BlockActionDocImpl.fromJson;

  @override
  BlockActionTypeDoc get action;
  @override
  BlockDoc get block;
  @override
  Uint32List get path;
  @override
  Uint32List? get oldPath;

  /// Create a copy of BlockActionDoc
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BlockActionDocImplCopyWith<_$BlockActionDocImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BlockDoc _$BlockDocFromJson(Map<String, dynamic> json) {
  return _BlockDoc.fromJson(json);
}

/// @nodoc
mixin _$BlockDoc {
  String get id => throw _privateConstructorUsedError;
  String get ty => throw _privateConstructorUsedError;
  Map<String, String> get attributes => throw _privateConstructorUsedError;
  String? get delta => throw _privateConstructorUsedError;
  String? get parentId => throw _privateConstructorUsedError;
  String? get prevId => throw _privateConstructorUsedError;
  String? get oldParentId => throw _privateConstructorUsedError;

  /// Serializes this BlockDoc to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BlockDoc
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BlockDocCopyWith<BlockDoc> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BlockDocCopyWith<$Res> {
  factory $BlockDocCopyWith(BlockDoc value, $Res Function(BlockDoc) then) =
      _$BlockDocCopyWithImpl<$Res, BlockDoc>;
  @useResult
  $Res call({
    String id,
    String ty,
    Map<String, String> attributes,
    String? delta,
    String? parentId,
    String? prevId,
    String? oldParentId,
  });
}

/// @nodoc
class _$BlockDocCopyWithImpl<$Res, $Val extends BlockDoc>
    implements $BlockDocCopyWith<$Res> {
  _$BlockDocCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BlockDoc
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ty = null,
    Object? attributes = null,
    Object? delta = freezed,
    Object? parentId = freezed,
    Object? prevId = freezed,
    Object? oldParentId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            ty:
                null == ty
                    ? _value.ty
                    : ty // ignore: cast_nullable_to_non_nullable
                        as String,
            attributes:
                null == attributes
                    ? _value.attributes
                    : attributes // ignore: cast_nullable_to_non_nullable
                        as Map<String, String>,
            delta:
                freezed == delta
                    ? _value.delta
                    : delta // ignore: cast_nullable_to_non_nullable
                        as String?,
            parentId:
                freezed == parentId
                    ? _value.parentId
                    : parentId // ignore: cast_nullable_to_non_nullable
                        as String?,
            prevId:
                freezed == prevId
                    ? _value.prevId
                    : prevId // ignore: cast_nullable_to_non_nullable
                        as String?,
            oldParentId:
                freezed == oldParentId
                    ? _value.oldParentId
                    : oldParentId // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BlockDocImplCopyWith<$Res>
    implements $BlockDocCopyWith<$Res> {
  factory _$$BlockDocImplCopyWith(
    _$BlockDocImpl value,
    $Res Function(_$BlockDocImpl) then,
  ) = __$$BlockDocImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String ty,
    Map<String, String> attributes,
    String? delta,
    String? parentId,
    String? prevId,
    String? oldParentId,
  });
}

/// @nodoc
class __$$BlockDocImplCopyWithImpl<$Res>
    extends _$BlockDocCopyWithImpl<$Res, _$BlockDocImpl>
    implements _$$BlockDocImplCopyWith<$Res> {
  __$$BlockDocImplCopyWithImpl(
    _$BlockDocImpl _value,
    $Res Function(_$BlockDocImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BlockDoc
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ty = null,
    Object? attributes = null,
    Object? delta = freezed,
    Object? parentId = freezed,
    Object? prevId = freezed,
    Object? oldParentId = freezed,
  }) {
    return _then(
      _$BlockDocImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        ty:
            null == ty
                ? _value.ty
                : ty // ignore: cast_nullable_to_non_nullable
                    as String,
        attributes:
            null == attributes
                ? _value._attributes
                : attributes // ignore: cast_nullable_to_non_nullable
                    as Map<String, String>,
        delta:
            freezed == delta
                ? _value.delta
                : delta // ignore: cast_nullable_to_non_nullable
                    as String?,
        parentId:
            freezed == parentId
                ? _value.parentId
                : parentId // ignore: cast_nullable_to_non_nullable
                    as String?,
        prevId:
            freezed == prevId
                ? _value.prevId
                : prevId // ignore: cast_nullable_to_non_nullable
                    as String?,
        oldParentId:
            freezed == oldParentId
                ? _value.oldParentId
                : oldParentId // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BlockDocImpl implements _BlockDoc {
  const _$BlockDocImpl({
    required this.id,
    required this.ty,
    required final Map<String, String> attributes,
    this.delta,
    this.parentId,
    this.prevId,
    this.oldParentId,
  }) : _attributes = attributes;

  factory _$BlockDocImpl.fromJson(Map<String, dynamic> json) =>
      _$$BlockDocImplFromJson(json);

  @override
  final String id;
  @override
  final String ty;
  final Map<String, String> _attributes;
  @override
  Map<String, String> get attributes {
    if (_attributes is EqualUnmodifiableMapView) return _attributes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_attributes);
  }

  @override
  final String? delta;
  @override
  final String? parentId;
  @override
  final String? prevId;
  @override
  final String? oldParentId;

  @override
  String toString() {
    return 'BlockDoc(id: $id, ty: $ty, attributes: $attributes, delta: $delta, parentId: $parentId, prevId: $prevId, oldParentId: $oldParentId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlockDocImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.ty, ty) || other.ty == ty) &&
            const DeepCollectionEquality().equals(
              other._attributes,
              _attributes,
            ) &&
            (identical(other.delta, delta) || other.delta == delta) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            (identical(other.prevId, prevId) || other.prevId == prevId) &&
            (identical(other.oldParentId, oldParentId) ||
                other.oldParentId == oldParentId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    ty,
    const DeepCollectionEquality().hash(_attributes),
    delta,
    parentId,
    prevId,
    oldParentId,
  );

  /// Create a copy of BlockDoc
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BlockDocImplCopyWith<_$BlockDocImpl> get copyWith =>
      __$$BlockDocImplCopyWithImpl<_$BlockDocImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BlockDocImplToJson(this);
  }
}

abstract class _BlockDoc implements BlockDoc {
  const factory _BlockDoc({
    required final String id,
    required final String ty,
    required final Map<String, String> attributes,
    final String? delta,
    final String? parentId,
    final String? prevId,
    final String? oldParentId,
  }) = _$BlockDocImpl;

  factory _BlockDoc.fromJson(Map<String, dynamic> json) =
      _$BlockDocImpl.fromJson;

  @override
  String get id;
  @override
  String get ty;
  @override
  Map<String, String> get attributes;
  @override
  String? get delta;
  @override
  String? get parentId;
  @override
  String? get prevId;
  @override
  String? get oldParentId;

  /// Create a copy of BlockDoc
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BlockDocImplCopyWith<_$BlockDocImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DocumentState _$DocumentStateFromJson(Map<String, dynamic> json) {
  return _DocumentState.fromJson(json);
}

/// @nodoc
mixin _$DocumentState {
  String get docId => throw _privateConstructorUsedError;
  Map<String, BlockDoc> get blocks => throw _privateConstructorUsedError;
  Map<String, List<String>> get childrenMap =>
      throw _privateConstructorUsedError;

  /// Serializes this DocumentState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DocumentState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentStateCopyWith<DocumentState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentStateCopyWith<$Res> {
  factory $DocumentStateCopyWith(
    DocumentState value,
    $Res Function(DocumentState) then,
  ) = _$DocumentStateCopyWithImpl<$Res, DocumentState>;
  @useResult
  $Res call({
    String docId,
    Map<String, BlockDoc> blocks,
    Map<String, List<String>> childrenMap,
  });
}

/// @nodoc
class _$DocumentStateCopyWithImpl<$Res, $Val extends DocumentState>
    implements $DocumentStateCopyWith<$Res> {
  _$DocumentStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? docId = null,
    Object? blocks = null,
    Object? childrenMap = null,
  }) {
    return _then(
      _value.copyWith(
            docId:
                null == docId
                    ? _value.docId
                    : docId // ignore: cast_nullable_to_non_nullable
                        as String,
            blocks:
                null == blocks
                    ? _value.blocks
                    : blocks // ignore: cast_nullable_to_non_nullable
                        as Map<String, BlockDoc>,
            childrenMap:
                null == childrenMap
                    ? _value.childrenMap
                    : childrenMap // ignore: cast_nullable_to_non_nullable
                        as Map<String, List<String>>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DocumentStateImplCopyWith<$Res>
    implements $DocumentStateCopyWith<$Res> {
  factory _$$DocumentStateImplCopyWith(
    _$DocumentStateImpl value,
    $Res Function(_$DocumentStateImpl) then,
  ) = __$$DocumentStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String docId,
    Map<String, BlockDoc> blocks,
    Map<String, List<String>> childrenMap,
  });
}

/// @nodoc
class __$$DocumentStateImplCopyWithImpl<$Res>
    extends _$DocumentStateCopyWithImpl<$Res, _$DocumentStateImpl>
    implements _$$DocumentStateImplCopyWith<$Res> {
  __$$DocumentStateImplCopyWithImpl(
    _$DocumentStateImpl _value,
    $Res Function(_$DocumentStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DocumentState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? docId = null,
    Object? blocks = null,
    Object? childrenMap = null,
  }) {
    return _then(
      _$DocumentStateImpl(
        docId:
            null == docId
                ? _value.docId
                : docId // ignore: cast_nullable_to_non_nullable
                    as String,
        blocks:
            null == blocks
                ? _value._blocks
                : blocks // ignore: cast_nullable_to_non_nullable
                    as Map<String, BlockDoc>,
        childrenMap:
            null == childrenMap
                ? _value._childrenMap
                : childrenMap // ignore: cast_nullable_to_non_nullable
                    as Map<String, List<String>>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DocumentStateImpl implements _DocumentState {
  const _$DocumentStateImpl({
    required this.docId,
    required final Map<String, BlockDoc> blocks,
    required final Map<String, List<String>> childrenMap,
  }) : _blocks = blocks,
       _childrenMap = childrenMap;

  factory _$DocumentStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$DocumentStateImplFromJson(json);

  @override
  final String docId;
  final Map<String, BlockDoc> _blocks;
  @override
  Map<String, BlockDoc> get blocks {
    if (_blocks is EqualUnmodifiableMapView) return _blocks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_blocks);
  }

  final Map<String, List<String>> _childrenMap;
  @override
  Map<String, List<String>> get childrenMap {
    if (_childrenMap is EqualUnmodifiableMapView) return _childrenMap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_childrenMap);
  }

  @override
  String toString() {
    return 'DocumentState(docId: $docId, blocks: $blocks, childrenMap: $childrenMap)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentStateImpl &&
            (identical(other.docId, docId) || other.docId == docId) &&
            const DeepCollectionEquality().equals(other._blocks, _blocks) &&
            const DeepCollectionEquality().equals(
              other._childrenMap,
              _childrenMap,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    docId,
    const DeepCollectionEquality().hash(_blocks),
    const DeepCollectionEquality().hash(_childrenMap),
  );

  /// Create a copy of DocumentState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentStateImplCopyWith<_$DocumentStateImpl> get copyWith =>
      __$$DocumentStateImplCopyWithImpl<_$DocumentStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DocumentStateImplToJson(this);
  }
}

abstract class _DocumentState implements DocumentState {
  const factory _DocumentState({
    required final String docId,
    required final Map<String, BlockDoc> blocks,
    required final Map<String, List<String>> childrenMap,
  }) = _$DocumentStateImpl;

  factory _DocumentState.fromJson(Map<String, dynamic> json) =
      _$DocumentStateImpl.fromJson;

  @override
  String get docId;
  @override
  Map<String, BlockDoc> get blocks;
  @override
  Map<String, List<String>> get childrenMap;

  /// Create a copy of DocumentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentStateImplCopyWith<_$DocumentStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FailedToDecodeUpdates _$FailedToDecodeUpdatesFromJson(
  Map<String, dynamic> json,
) {
  return _FailedToDecodeUpdates.fromJson(json);
}

/// @nodoc
mixin _$FailedToDecodeUpdates {
  List<String> get failedUpdatesIds => throw _privateConstructorUsedError;

  /// Serializes this FailedToDecodeUpdates to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FailedToDecodeUpdates
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FailedToDecodeUpdatesCopyWith<FailedToDecodeUpdates> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FailedToDecodeUpdatesCopyWith<$Res> {
  factory $FailedToDecodeUpdatesCopyWith(
    FailedToDecodeUpdates value,
    $Res Function(FailedToDecodeUpdates) then,
  ) = _$FailedToDecodeUpdatesCopyWithImpl<$Res, FailedToDecodeUpdates>;
  @useResult
  $Res call({List<String> failedUpdatesIds});
}

/// @nodoc
class _$FailedToDecodeUpdatesCopyWithImpl<
  $Res,
  $Val extends FailedToDecodeUpdates
>
    implements $FailedToDecodeUpdatesCopyWith<$Res> {
  _$FailedToDecodeUpdatesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FailedToDecodeUpdates
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? failedUpdatesIds = null}) {
    return _then(
      _value.copyWith(
            failedUpdatesIds:
                null == failedUpdatesIds
                    ? _value.failedUpdatesIds
                    : failedUpdatesIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FailedToDecodeUpdatesImplCopyWith<$Res>
    implements $FailedToDecodeUpdatesCopyWith<$Res> {
  factory _$$FailedToDecodeUpdatesImplCopyWith(
    _$FailedToDecodeUpdatesImpl value,
    $Res Function(_$FailedToDecodeUpdatesImpl) then,
  ) = __$$FailedToDecodeUpdatesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String> failedUpdatesIds});
}

/// @nodoc
class __$$FailedToDecodeUpdatesImplCopyWithImpl<$Res>
    extends
        _$FailedToDecodeUpdatesCopyWithImpl<$Res, _$FailedToDecodeUpdatesImpl>
    implements _$$FailedToDecodeUpdatesImplCopyWith<$Res> {
  __$$FailedToDecodeUpdatesImplCopyWithImpl(
    _$FailedToDecodeUpdatesImpl _value,
    $Res Function(_$FailedToDecodeUpdatesImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FailedToDecodeUpdates
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? failedUpdatesIds = null}) {
    return _then(
      _$FailedToDecodeUpdatesImpl(
        failedUpdatesIds:
            null == failedUpdatesIds
                ? _value._failedUpdatesIds
                : failedUpdatesIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FailedToDecodeUpdatesImpl implements _FailedToDecodeUpdates {
  const _$FailedToDecodeUpdatesImpl({
    required final List<String> failedUpdatesIds,
  }) : _failedUpdatesIds = failedUpdatesIds;

  factory _$FailedToDecodeUpdatesImpl.fromJson(Map<String, dynamic> json) =>
      _$$FailedToDecodeUpdatesImplFromJson(json);

  final List<String> _failedUpdatesIds;
  @override
  List<String> get failedUpdatesIds {
    if (_failedUpdatesIds is EqualUnmodifiableListView)
      return _failedUpdatesIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_failedUpdatesIds);
  }

  @override
  String toString() {
    return 'FailedToDecodeUpdates(failedUpdatesIds: $failedUpdatesIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FailedToDecodeUpdatesImpl &&
            const DeepCollectionEquality().equals(
              other._failedUpdatesIds,
              _failedUpdatesIds,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_failedUpdatesIds),
  );

  /// Create a copy of FailedToDecodeUpdates
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FailedToDecodeUpdatesImplCopyWith<_$FailedToDecodeUpdatesImpl>
  get copyWith =>
      __$$FailedToDecodeUpdatesImplCopyWithImpl<_$FailedToDecodeUpdatesImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FailedToDecodeUpdatesImplToJson(this);
  }
}

abstract class _FailedToDecodeUpdates implements FailedToDecodeUpdates {
  const factory _FailedToDecodeUpdates({
    required final List<String> failedUpdatesIds,
  }) = _$FailedToDecodeUpdatesImpl;

  factory _FailedToDecodeUpdates.fromJson(Map<String, dynamic> json) =
      _$FailedToDecodeUpdatesImpl.fromJson;

  @override
  List<String> get failedUpdatesIds;

  /// Create a copy of FailedToDecodeUpdates
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FailedToDecodeUpdatesImplCopyWith<_$FailedToDecodeUpdatesImpl>
  get copyWith => throw _privateConstructorUsedError;
}
