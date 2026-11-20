import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/location/location_gateway.dart';
import '../../../core/media/local_photo_reader.dart';
import '../../../core/media/photo_storage.dart';
import '../../../core/media/photo_selection.dart';
import '../../../core/validation/input_limits.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../categories/domain/category_repository.dart';
import '../../map/presentation/location_picker_page.dart';
import '../../map/presentation/map_canvas.dart';
import '../../map/presentation/map_tiles.dart';
import '../data/report_draft_store.dart';
import '../domain/report_policy.dart';
import '../domain/report_repository.dart';
import 'report_composer_cubit.dart';
import 'report_photo.dart';

class NewReportPage extends StatefulWidget {
  const NewReportPage({
    super.key,
    required this.auth,
    required this.categories,
    required this.reports,
    required this.storage,
    required this.selection,
    required this.drafts,
    required this.reader,
    required this.location,
    required this.onSaved,
    this.tiles = MapTiles.create,
  });
  final AuthCubit auth;
  final CategoryRepository categories;
  final ReportRepository reports;
  final PhotoStorage storage;
  final PhotoSelection selection;
  final ReportDraftStore drafts;
  final LocalPhotoReader reader;
  final LocationGateway location;
  final ValueChanged<String> onSaved;
  final TileProviderFactory tiles;
  @override
  State<NewReportPage> createState() => _NewReportPageState();
}

class _NewReportPageState extends State<NewReportPage> {
  late final composer = ReportComposerCubit(
    uid: widget.auth.state.user!.uid,
    currentUid: () => widget.auth.repository.currentUser?.uid,
    reports: widget.reports,
    storage: widget.storage,
    selection: widget.selection,
    drafts: widget.drafts,
  );
  late final categories = widget.categories.watchCategories();
  final title = TextEditingController();
  final description = TextEditingController();
  bool preview = false;
  @override
  void initState() {
    super.initState();
    unawaited(composer.initialize());
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    unawaited(composer.close());
    super.dispose();
  }

  Future<void> chooseLocation() async {
    FocusScope.of(context).unfocus();
    final point = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          location: widget.location,
          initial: composer.state.draft.point,
          tiles: widget.tiles,
        ),
      ),
    );
    if (point != null && mounted) composer.setPoint(point);
  }

  Future<void> discard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar el borrador?'),
        content: const Text(
          'Se eliminarán el texto y las fotos que todavía no publicaste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conservar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) await composer.discard();
  }

  void syncText(ComposerState state) {
    if (title.text != state.draft.title) title.text = state.draft.title;
    if (description.text != state.draft.description) {
      description.text = state.draft.description;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ReportComposerCubit, ComposerState>(
    bloc: composer,
    listener: (_, state) {
      syncText(state);
      if (state.message != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
      }
      if (state.savedId != null) widget.onSaved(state.savedId!);
    },
    builder: (context, state) {
      if (state.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      final draft = state.draft;
      return StreamBuilder<List<ReportCategory>>(
        stream: categories,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'No se pudieron cargar las categorías. Vuelve a entrar para reintentar.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final active = snapshot.data!
              .where((category) => category.isActive)
              .toList();
          final name =
              snapshot.data!
                  .where((category) => category.id == draft.categoryId)
                  .firstOrNull
                  ?.name ??
              '';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                preview ? 'Vista previa del reporte' : 'Crear reporte',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (state.message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (preview) ...[
                Text(
                  draft.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(name),
                Text(draft.description),
                Text(
                  'Autor: ${draft.identity == PublicIdentityMode.anonymous ? 'Ciudadano anónimo' : widget.auth.state.user!.publicName}',
                ),
                Text('Ubicación: ${draft.point!.label}'),
                SizedBox(
                  height: 200,
                  child: MapCanvas(
                    focus: draft.point,
                    selected: draft.point,
                    tiles: widget.tiles,
                  ),
                ),
                const Text(
                  'Estado inicial: Reportado. Fecha y hora se registran al publicar.',
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('${draft.requestId}:${draft.categoryId}'),
                  initialValue:
                      active.any((category) => category.id == draft.categoryId)
                      ? draft.categoryId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  hint: const Text('Elige una categoría'),
                  items: [
                    for (final category in active)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: state.busy
                      ? null
                      : (value) =>
                            composer.update(draft.copy(categoryId: value)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  enabled: !state.busy,
                  maxLength: InputLimits.titleMax,
                  decoration: const InputDecoration(labelText: 'Título'),
                  onChanged: (value) =>
                      composer.update(composer.state.draft.copy(title: value)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  enabled: !state.busy,
                  maxLength: InputLimits.descriptionMax,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  onChanged: (value) => composer.update(
                    composer.state.draft.copy(description: value),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: state.busy ? null : chooseLocation,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(
                    draft.point == null
                        ? 'Elegir ubicación'
                        : 'Corregir ubicación',
                  ),
                ),
                if (draft.point != null) Text(draft.point!.label),
                if (draft.point?.isFarFromElAlto ?? false)
                  const Text(
                    'El punto está a más de 30 km del centro aproximado de El Alto. Revisa la ubicación.',
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publicar anónimamente'),
                  subtitle: Text(
                    draft.identity == PublicIdentityMode.anonymous
                        ? 'Se mostrará Ciudadano anónimo.'
                        : 'Se mostrará ${widget.auth.state.user!.publicName}.',
                  ),
                  value: draft.identity == PublicIdentityMode.anonymous,
                  onChanged: state.busy
                      ? null
                      : (value) => composer.update(
                          draft.copy(
                            identity: value
                                ? PublicIdentityMode.anonymous
                                : PublicIdentityMode.publicName,
                          ),
                        ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Fotografías: ${draft.photos.length}/${InputLimits.maxPhotos}',
              ),
              if (!preview)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          state.busy ||
                              draft.photos.length >= InputLimits.maxPhotos
                          ? null
                          : () => composer.pick(camera: true),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Cámara'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          state.busy ||
                              draft.photos.length >= InputLimits.maxPhotos
                          ? null
                          : () => composer.pick(camera: false),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ],
                ),
              for (final (index, photo) in draft.photos.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: ReportPhoto(
                          path: photo.relativePath,
                          reader: widget.reader,
                        ),
                      ),
                      if (!preview)
                        TextButton.icon(
                          onPressed: state.busy
                              ? null
                              : () => composer.removePhoto(index),
                          icon: const Icon(Icons.delete_outline),
                          label: Text('Quitar foto ${index + 1}'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (state.busy) const LinearProgressIndicator(),
              if (preview) ...[
                FilledButton(
                  onPressed: state.busy ? null : composer.submit,
                  child: const Text('Publicar reporte'),
                ),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => setState(() => preview = false),
                  child: const Text('Volver a editar'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          if (await composer.preview() && mounted) {
                            setState(() => preview = true);
                          }
                        },
                  child: const Text('Revisar reporte'),
                ),
                TextButton(
                  onPressed: state.busy ? null : discard,
                  child: const Text('Descartar borrador'),
                ),
                const Text(
                  'El borrador se conserva en este teléfono para tu cuenta. Puedes volver a Crear para retomarlo.',
                ),
              ],
            ],
          );
        },
      );
    },
  );
}
