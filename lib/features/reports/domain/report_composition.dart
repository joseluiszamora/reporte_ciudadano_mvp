import 'package:uuid/uuid.dart';

import '../../../core/location/geo_point.dart';
import '../../../core/media/photo_storage.dart';
import '../domain/report_repository.dart';
import 'report_policy.dart';

class ReportComposition {
  ReportComposition({
    String? requestId,
    this.categoryId,
    this.title = '',
    this.description = '',
    this.point,
    this.identity = PublicIdentityMode.anonymous,
    List<StoredPhoto> photos = const [],
  }) : requestId = requestId ?? const Uuid().v4(),
       photos = List.unmodifiable(photos);
  final String requestId;
  final String? categoryId;
  final String title;
  final String description;
  final GeoPoint? point;
  final PublicIdentityMode identity;
  final List<StoredPhoto> photos;
  bool get hasContent =>
      categoryId != null ||
      title.isNotEmpty ||
      description.isNotEmpty ||
      point != null ||
      photos.isNotEmpty;
  ReportComposition copy({
    String? categoryId,
    String? title,
    String? description,
    GeoPoint? point,
    PublicIdentityMode? identity,
    List<StoredPhoto>? photos,
  }) => ReportComposition(
    requestId: requestId,
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    description: description ?? this.description,
    point: point ?? this.point,
    identity: identity ?? this.identity,
    photos: photos ?? this.photos,
  );
  ReportDraft toReport() => ReportDraft(
    requestId: requestId,
    categoryId: categoryId!,
    title: title,
    description: description,
    latitude: point!.latitude,
    longitude: point!.longitude,
    identityMode: identity,
    photos: photos,
  );
  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'categoryId': categoryId,
    'title': title,
    'description': description,
    'latitude': point?.latitude,
    'longitude': point?.longitude,
    'identity': identity.name,
    'photos': photos
        .map(
          (photo) => {
            'path': photo.relativePath,
            'mime': photo.mimeType,
            'bytes': photo.bytes,
          },
        )
        .toList(),
  };
  factory ReportComposition.fromJson(Map<String, dynamic> data) =>
      ReportComposition(
        requestId: data['requestId'] as String,
        categoryId: data['categoryId'] as String?,
        title: data['title'] as String,
        description: data['description'] as String,
        point: data['latitude'] == null
            ? null
            : GeoPoint(
                (data['latitude'] as num).toDouble(),
                (data['longitude'] as num).toDouble(),
              ),
        identity: PublicIdentityMode.values.byName(data['identity'] as String),
        photos: (data['photos'] as List)
            .map(
              (photo) => StoredPhoto(
                relativePath: photo['path'] as String,
                mimeType: photo['mime'] as String,
                bytes: photo['bytes'] as int,
              ),
            )
            .toList(),
      );
}
