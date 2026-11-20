import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/location/geo_point.dart';
import '../../../core/location/location_gateway.dart';
import '../../../core/media/local_photo_reader.dart';
import '../../../core/media/photo_storage.dart';
import '../../../core/media/photo_selection.dart';
import '../../../core/validation/input_limits.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../categories/domain/category_repository.dart';
import '../../map/presentation/location_picker_page.dart';
import '../../map/presentation/map_tiles.dart';
import '../data/report_draft_store.dart';
import '../domain/report_policy.dart';
import '../domain/report_repository.dart';
import '../domain/resolution_repository.dart';
import '../../../core/errors/action_error_message.dart';
import 'report_photo.dart';

class EditReportPage extends StatefulWidget {
  const EditReportPage({
    super.key,
    required this.initial,
    required this.uid,
    required this.auth,
    required this.reports,
    required this.storage,
    required this.selection,
    required this.drafts,
    required this.reader,
    required this.categories,
    required this.location,
    required this.tiles,
  });
  final ReportManagement initial;
  final String uid;
  final AuthCubit auth;
  final ReportRepository reports;
  final PhotoStorage storage;
  final PhotoSelection selection;
  final ReportDraftStore drafts;
  final LocalPhotoReader reader;
  final CategoryRepository categories;
  final LocationGateway location;
  final TileProviderFactory tiles;
  @override
  State<EditReportPage> createState() => _EditReportPageState();
}

class _EditReportPageState extends State<EditReportPage> {
  late final title = TextEditingController(text: widget.initial.draft.title);
  late final description = TextEditingController(
    text: widget.initial.draft.description,
  );
  final reason = TextEditingController();
  late String category = widget.initial.draft.categoryId;
  late GeoPoint point = GeoPoint(
    widget.initial.draft.latitude,
    widget.initial.draft.longitude,
  );
  late PublicIdentityMode identity = widget.initial.draft.identityMode;
  late final photos = [...widget.initial.draft.photos];
  final imported = <StoredPhoto>[];
  late final categories = widget.categories.watchCategories();
  bool busy = false;
  String? message;
  bool get current =>
      mounted && widget.auth.repository.currentUser?.uid == widget.uid;

  Future<void> cleanup() async {
    for (final photo in imported) {
      await widget.storage.remove(photo.relativePath).catchError((_) {});
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    reason.dispose();
    if (!busy) unawaited(cleanup());
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (!current || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (current && mounted) {
        setState(() => message = actionErrorMessage(e));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message!)));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      } else {
        await cleanup();
      }
    }
  }

  Future<void> pick(bool camera) => run(() async {
    final marker = 'management:${widget.uid}';
    await widget.drafts.markPicker(marker);
    try {
      final paths = await widget.selection.pick(
        camera: camera,
        remaining: InputLimits.maxPhotos - photos.length,
      );
      for (final path in paths.take(InputLimits.maxPhotos - photos.length)) {
        if (!current) break;
        final photo = await widget.storage.import(path);
        if (!current) {
          await widget.storage.remove(photo.relativePath);
          break;
        }
        imported.add(photo);
        photos.add(photo);
      }
    } finally {
      await widget.drafts.clearPicker(marker);
    }
  });

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    bloc: widget.auth,
    builder: (context, auth) {
      if (auth.user?.uid != widget.uid ||
          !ReportPolicy.canCreate(auth.user) ||
          (widget.initial.isAdmin && !ReportPolicy.canManage(auth.user))) {
        return Scaffold(
          appBar: AppBar(title: const Text('Editar reporte')),
          body: const Center(
            child: Text('La sesión cambió. Vuelve a abrir el reporte.'),
          ),
        );
      }
      return PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Editar reporte')),
          body: StreamBuilder<List<ReportCategory>>(
            stream: categories,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'No se pudieron cargar las categorías. Vuelve a abrir el reporte.',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final options = snapshot.data!.where(
                (c) => c.isActive || c.id == widget.initial.draft.categoryId,
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Se conserva el historial de cambios y fotografías anteriores. Los cambios sin guardar se pierden al salir.',
                  ),
                  if (busy) const LinearProgressIndicator(),
                  if (message != null)
                    Text(message!, key: const ValueKey('edit-message')),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      for (final c in options)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => category = value!),
                  ),
                  TextField(
                    controller: title,
                    enabled: !busy,
                    maxLength: InputLimits.titleMax,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  TextField(
                    controller: description,
                    enabled: !busy,
                    maxLength: InputLimits.descriptionMax,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final selected = await Navigator.of(context)
                                .push<GeoPoint>(
                                  MaterialPageRoute(
                                    builder: (_) => LocationPickerPage(
                                      location: widget.location,
                                      initial: point,
                                      tiles: widget.tiles,
                                    ),
                                  ),
                                );
                            if (selected != null && current) {
                              setState(() => point = selected);
                            }
                          },
                    child: const Text('Corregir ubicación'),
                  ),
                  Text(point.label),
                  if (point.isFarFromElAlto)
                    const Text(
                      'Revisa el punto: está a más de 30 km del centro aproximado de El Alto.',
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publicar anónimamente'),
                    subtitle: const Text(
                      'Al mostrar un nombre se conserva la atribución del autor original.',
                    ),
                    value: identity == PublicIdentityMode.anonymous,
                    onChanged: busy
                        ? null
                        : (value) => setState(
                            () => identity = value
                                ? PublicIdentityMode.anonymous
                                : PublicIdentityMode.publicName,
                          ),
                  ),
                  Text(
                    'Fotografías: ${photos.length}/${InputLimits.maxPhotos}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed:
                            busy || photos.length >= InputLimits.maxPhotos
                            ? null
                            : () => pick(true),
                        child: const Text('Cámara'),
                      ),
                      OutlinedButton(
                        onPressed:
                            busy || photos.length >= InputLimits.maxPhotos
                            ? null
                            : () => pick(false),
                        child: const Text('Galería'),
                      ),
                    ],
                  ),
                  for (final (index, photo) in photos.indexed)
                    Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: ReportPhoto(
                            path: photo.relativePath,
                            reader: widget.reader,
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => photos.removeAt(index)),
                          child: Text('Quitar foto ${index + 1}'),
                        ),
                      ],
                    ),
                  TextField(
                    controller: reason,
                    enabled: !busy,
                    maxLength: InputLimits.noteMax,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del cambio',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            await widget.reports.update(
                              reportId: widget.initial.report.id,
                              expectedRevision: widget.initial.report.revision,
                              reason: reason.text,
                              draft: ReportDraft(
                                categoryId: category,
                                title: title.text,
                                description: description.text,
                                latitude: point.latitude,
                                longitude: point.longitude,
                                addressLabel: widget.initial.draft.addressLabel,
                                identityMode: identity,
                                photos: photos,
                              ),
                            );
                            if (current && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }),
                    child: const Text('Guardar cambios'),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
