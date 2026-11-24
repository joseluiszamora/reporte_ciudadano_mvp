import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/civic_feedback.dart';
import '../../../core/location/geo_point.dart';
import '../../../core/location/location_gateway.dart';
import '../../../core/media/local_photo_reader.dart';
import '../../../core/media/photo_storage.dart';
import '../../../core/media/photo_selection.dart';
import '../../../core/validation/input_limits.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_pages.dart';
import '../../categories/domain/category_repository.dart';
import '../../categories/presentation/category_icon.dart';
import '../../map/presentation/location_picker_page.dart';
import '../../map/presentation/map_canvas.dart';
import '../../map/presentation/map_tiles.dart';
import '../data/report_draft_store.dart';
import '../domain/report_policy.dart';
import '../domain/report_repository.dart';
import 'report_composer_cubit.dart';
import 'report_photo.dart';
import 'report_status_badge.dart';

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
  late ReportComposerCubit composer;
  late final StreamSubscription<AuthState> sessionChanges;
  String? boundUid;
  late Stream<List<ReportCategory>> categories;
  final title = TextEditingController();
  final description = TextEditingController();
  final scroll = ScrollController();
  static const steps = [
    'Tipo de problema',
    'Evidencia',
    'Ubicación',
    'Revisión',
  ];
  int step = 0;
  String? validation;
  bool advancing = false;

  @override
  void initState() {
    super.initState();
    categories = widget.categories.watchCategories();
    boundUid = widget.auth.state.user?.uid;
    composer = createComposer(boundUid);
    sessionChanges = widget.auth.stream.listen(onSessionChanged);
  }

  ReportComposerCubit createComposer(String? uid) {
    final next = ReportComposerCubit(
      uid: uid,
      currentUid: () => widget.auth.repository.currentUser?.uid,
      reports: widget.reports,
      storage: widget.storage,
      selection: widget.selection,
      drafts: widget.drafts,
    );
    unawaited(next.initialize());
    return next;
  }

  void onSessionChanged(AuthState state) {
    final uid = state.user?.uid;
    if (boundUid == uid) return;
    if (boundUid == null) {
      // A visitor can finish signing in without switching away from the draft.
      boundUid = uid;
      return;
    }
    final previous = composer;
    title.clear();
    description.clear();
    setState(() {
      boundUid = uid;
      categories = widget.categories.watchCategories();
      composer = createComposer(uid);
      step = 0;
      advancing = false;
      validation = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    unawaited(previous.close());
  }

  @override
  void dispose() {
    unawaited(sessionChanges.cancel());
    title.dispose();
    description.dispose();
    scroll.dispose();
    unawaited(composer.close());
    super.dispose();
  }

  Future<void> chooseLocation() async {
    FocusScope.of(context).unfocus();
    final editing = composer;
    final point = await Navigator.of(context, rootNavigator: true)
        .push<GeoPoint>(
          MaterialPageRoute(
            builder: (_) => LocationPickerPage(
              location: widget.location,
              initial: composer.state.draft.point,
              tiles: widget.tiles,
            ),
          ),
        );
    if (point != null && mounted && editing == composer) {
      composer.setPoint(point);
      clearValidation();
    }
  }

  Future<void> discard() async {
    final editing = composer;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar el borrador?'),
        content: const Text('Se eliminarán el texto y las fotos del borrador.'),
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
    if (confirm == true && mounted && editing == composer) {
      await composer.discard();
      if (mounted && editing == composer && !composer.state.draft.hasContent) {
        goToStep(0);
      }
    }
  }

  void goToStep(int value) {
    FocusScope.of(context).unfocus();
    setState(() {
      step = value;
      validation = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void clearValidation() {
    if (validation != null) setState(() => validation = null);
  }

  Future<void> advance(List<ReportCategory> active) async {
    if (advancing) return;
    final current = step;
    final editing = composer;
    final draft = editing.state.draft;
    final issue = switch (current) {
      0 =>
        active.any((category) => category.id == draft.categoryId)
            ? composer.validateProblem()
            : 'Elige una categoría.',
      1 => draft.photos.isEmpty ? 'Adjunta al menos una fotografía.' : null,
      2 => draft.point == null ? 'Elige la ubicación del problema.' : null,
      _ => null,
    };
    if (issue != null) {
      setState(() => validation = issue);
      return;
    }
    if (current != 2) {
      goToStep(current + 1);
      return;
    }
    setState(() => advancing = true);
    try {
      if (await editing.preview() &&
          mounted &&
          editing == composer &&
          current == step) {
        goToStep(current + 1);
      }
    } finally {
      if (mounted && editing == composer) setState(() => advancing = false);
    }
  }

  void syncText(ComposerState state) {
    if (title.text != state.draft.title) title.text = state.draft.title;
    if (description.text != state.draft.description) {
      description.text = state.draft.description;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ReportComposerCubit, ComposerState>(
        key: ValueKey(composer),
        bloc: composer,
        listener: (_, state) {
          syncText(state);
          if (state.savedId != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reporte guardado en este dispositivo.'),
              ),
            );
            widget.onSaved(state.savedId!);
          }
        },
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<ReportCategory>>(
            stream: categories,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: CivicState(
                    icon: Icons.error_outline_rounded,
                    title: 'No se pudieron cargar las categorías.',
                    action: OutlinedButton(
                      onPressed: () => setState(
                        () => categories = widget.categories.watchCategories(),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final active = snapshot.data!
                  .where((category) => category.isActive)
                  .toList();
              final draft = state.draft;
              final category = snapshot.data!
                  .where((item) => item.id == draft.categoryId)
                  .firstOrNull;
              return ListView(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Paso ${step + 1} de ${steps.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (step + 1) / steps.length,
                    semanticsLabel: 'Progreso del reporte',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    step == 3 ? 'Vista previa del reporte' : steps[step],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ...switch (step) {
                    0 => problem(state, active),
                    1 => evidence(state),
                    2 => location(state),
                    _ => review(state, category?.name ?? ''),
                  },
                  if (validation != null || state.message != null) ...[
                    const SizedBox(height: 12),
                    CivicNotice(
                      icon: Icons.error_outline_rounded,
                      text: validation ?? state.message!,
                      isError: true,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (state.busy) const LinearProgressIndicator(),
                  if (step < 3)
                    FilledButton(
                      onPressed: state.busy || advancing
                          ? null
                          : () => advance(active),
                      child: Text(step == 2 ? 'Revisar reporte' : 'Continuar'),
                    ),
                  if (step > 0)
                    TextButton(
                      onPressed: state.busy ? null : () => goToStep(step - 1),
                      child: const Text('Volver'),
                    ),
                  if (draft.hasContent)
                    TextButton(
                      onPressed: state.busy ? null : discard,
                      child: const Text('Descartar borrador'),
                    ),
                ],
              );
            },
          );
        },
      );

  List<Widget> problem(ComposerState state, List<ReportCategory> active) => [
    DropdownButtonFormField<String>(
      key: ValueKey((state.draft.requestId, state.draft.categoryId)),
      initialValue:
          active.any((category) => category.id == state.draft.categoryId)
          ? state.draft.categoryId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Categoría'),
      items: [
        for (final category in active)
          DropdownMenuItem(
            value: category.id,
            child: Row(
              children: [
                Icon(categoryIcon(category.iconKey), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(category.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: state.busy
          ? null
          : (value) {
              composer.update(composer.state.draft.copy(categoryId: value));
              clearValidation();
            },
    ),
    const SizedBox(height: 16),
    TextField(
      controller: title,
      enabled: !state.busy,
      maxLength: InputLimits.titleMax,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Título',
        hintText: 'Bache en la avenida',
      ),
      onChanged: (value) {
        composer.update(composer.state.draft.copy(title: value));
        clearValidation();
      },
    ),
    const SizedBox(height: 8),
    TextField(
      controller: description,
      enabled: !state.busy,
      maxLength: InputLimits.descriptionMax,
      minLines: 3,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Descripción',
        hintText: 'Describe qué ocurre y desde cuándo.',
      ),
      onChanged: (value) {
        composer.update(composer.state.draft.copy(description: value));
        clearValidation();
      },
    ),
  ];

  List<Widget> evidence(ComposerState state) {
    final full = state.draft.photos.length >= InputLimits.maxPhotos;
    return [
      Text(
        'Adjunta al menos una fotografía. ${state.draft.photos.length}/${InputLimits.maxPhotos}',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: state.busy || full
                ? null
                : () async {
                    clearValidation();
                    await composer.pick(camera: true);
                  },
            icon: const Icon(Icons.add_a_photo_rounded),
            label: const Text('Cámara'),
          ),
          OutlinedButton.icon(
            onPressed: state.busy || full
                ? null
                : () async {
                    clearValidation();
                    await composer.pick(camera: false);
                  },
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Galería'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      photoTiles(state, editable: true),
    ];
  }

  List<Widget> location(ComposerState state) => [
    if (state.draft.point case final point?) ...[
      Text(point.label),
      if (point.isFarFromElAlto)
        const CivicNotice(
          icon: Icons.info_outline_rounded,
          text: 'El punto está a más de 30 km del centro aproximado de El Alto. Revisa la ubicación.',
        ),
      const SizedBox(height: 12),
      locationMap(point),
      const SizedBox(height: 12),
    ] else
      const Text('Marca el problema en el mapa o usa tu ubicación.'),
    OutlinedButton.icon(
      onPressed: state.busy ? null : chooseLocation,
      icon: const Icon(Icons.add_location_alt_rounded),
      label: Text(
        state.draft.point == null ? 'Elegir ubicación' : 'Corregir ubicación',
      ),
    ),
  ];

  List<Widget> review(ComposerState state, String category) {
    final draft = state.draft;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category),
              Text(draft.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const ReportStatusBadge(ReportStatus.reported),
              const SizedBox(height: 8),
              Text(draft.description),
              const SizedBox(height: 8),
              Text('Ubicación: ${draft.point!.label}'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      photoTiles(state),
      const SizedBox(height: 12),
      BlocBuilder<AuthCubit, AuthState>(
        bloc: widget.auth,
        builder: (context, session) {
          final user = session.user;
          final anonymous = draft.identity == PublicIdentityMode.anonymous;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.visibility_off_rounded),
                title: const Text('Publicar anónimamente'),
                subtitle: Text(
                  anonymous
                      ? 'Autor: Ciudadano anónimo'
                      : user == null || user.publicName.isEmpty
                      ? 'Se mostrará el nombre público de tu cuenta.'
                      : 'Autor: ${user.publicName}',
                ),
                value: anonymous,
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
              const SizedBox(height: 8),
              const CivicNotice(
                icon: Icons.smartphone_rounded,
                text: 'El reporte se guardará en este dispositivo.',
              ),
              const SizedBox(height: 12),
              if (session.initializing || session.busy)
                const LinearProgressIndicator()
              else if (user == null) ...[
                const Text(
                  'Inicia sesión para guardar el reporte. Tu borrador se conservará.',
                ),
                if (session.issue != null || session.message != null)
                  CivicNotice(
                    icon: Icons.error_outline_rounded,
                    text: session.message ?? session.issue!,
                    isError: true,
                  ),
                FilledButton.icon(
                  onPressed: session.issue == null ? widget.auth.signIn : null,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Continuar con Google'),
                ),
              ] else if (!ReportPolicy.canCreate(user))
                PublicNameForm(key: ValueKey(user.uid), auth: widget.auth)
              else
                FilledButton(
                  onPressed: state.busy ? null : composer.submit,
                  child: const Text('Guardar reporte'),
                ),
            ],
          );
        },
      ),
    ];
  }

  Widget locationMap(GeoPoint point) => SizedBox(
    height: 240,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: MapCanvas(focus: point, selected: point, tiles: widget.tiles),
    ),
  );

  Widget photoTiles(ComposerState state, {bool editable = false}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 280 ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (index, photo) in state.draft.photos.indexed)
                SizedBox(
                  width: width,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: ReportPhoto(
                            path: photo.relativePath,
                            reader: widget.reader,
                          ),
                        ),
                        if (editable)
                          TextButton.icon(
                            onPressed: state.busy
                                ? null
                                : () => composer.removePhoto(index),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: Text('Quitar foto ${index + 1}'),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
