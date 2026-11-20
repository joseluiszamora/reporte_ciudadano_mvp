import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/action_error_message.dart';
import '../../../core/media/local_photo_reader.dart';
import '../../../core/media/photo_storage.dart';
import '../../../core/media/photo_selection.dart';
import '../../../core/location/location_gateway.dart';
import '../../../core/validation/input_limits.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../categories/domain/category_repository.dart';
import '../../map/presentation/map_tiles.dart';
import '../data/report_draft_store.dart';
import '../domain/report_policy.dart';
import '../domain/report_repository.dart';
import '../domain/resolution_repository.dart';
import 'edit_report_page.dart';
import 'report_labels.dart';
import 'report_photo.dart';

class ReportManagementPage extends StatelessWidget {
  const ReportManagementPage({
    super.key,
    required this.id,
    required this.auth,
    required this.resolutions,
    required this.reports,
    required this.storage,
    required this.selection,
    required this.drafts,
    required this.reader,
    required this.categories,
    required this.location,
    required this.tiles,
  });
  final String id;
  final AuthCubit auth;
  final ResolutionRepository resolutions;
  final ReportRepository reports;
  final PhotoStorage storage;
  final PhotoSelection selection;
  final ReportDraftStore drafts;
  final LocalPhotoReader reader;
  final CategoryRepository categories;
  final LocationGateway location;
  final TileProviderFactory tiles;

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    bloc: auth,
    builder: (context, state) {
      if (!ReportPolicy.canCreate(state.user)) {
        return const Scaffold(
          body: Center(child: Text('Inicia sesión y completa tu perfil.')),
        );
      }
      return _Management(
        key: ValueKey('${state.user!.uid}:${state.user!.role}'),
        page: this,
        uid: state.user!.uid,
      );
    },
  );
}

class _Management extends StatefulWidget {
  const _Management({super.key, required this.page, required this.uid});
  final ReportManagementPage page;
  final String uid;
  @override
  State<_Management> createState() => _ManagementState();
}

class _ManagementState extends State<_Management> {
  ReportManagementPage get p => widget.page;
  late Future<ReportManagement> loading = loadManagement();
  Future<ReportManagement> loadManagement() {
    final future = p.resolutions.load(p.id);
    // Observe errors immediately; FutureBuilder attaches on the following frame.
    future.ignore();
    return future;
  }

  final note = TextEditingController();
  String requestId = const Uuid().v4();
  StoredPhoto? photo;
  bool busy = false;
  String? message;
  bool get current =>
      mounted && p.auth.repository.currentUser?.uid == widget.uid;

  @override
  void dispose() {
    note.dispose();
    // Reference-aware storage preserves committed evidence, even after deletion.
    if (!busy && photo != null) {
      unawaited(p.storage.remove(photo!.relativePath).catchError((_) {}));
    }
    super.dispose();
  }

  Future<void> run(
    Future<void> Function() action, {
    bool reload = true,
    String? successMessage = 'Acción guardada.',
  }) async {
    if (!current || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      if (current) {
        setState(() {
          message = successMessage;
          if (reload) loading = loadManagement();
        });
      }
    } catch (e) {
      if (current && mounted) {
        setState(() => message = actionErrorMessage(e));
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(message!)));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      } else if (photo != null) {
        await p.storage.remove(photo!.relativePath).catchError((_) {});
      }
    }
  }

  Future<void> pick(bool camera) => run(
    () async {
      // Creation recovery must never attach evidence intended for management.
      final marker = 'management:${widget.uid}';
      await p.drafts.markPicker(marker);
      try {
        final paths = await p.selection.pick(camera: camera, remaining: 1);
        if (paths.isEmpty || !current) return;
        final imported = await p.storage.import(paths.first);
        if (!current) {
          await p.storage.remove(imported.relativePath);
          return;
        }
        final old = photo;
        photo = imported;
        if (old != null) await p.storage.remove(old.relativePath);
      } finally {
        await p.drafts.clearPicker(marker);
      }
    },
    reload: false,
    successMessage: null,
  );

  Future<String?> askReason(String title, {String? explanation}) async {
    var reasonText = '';
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (explanation != null) Text(explanation),
                TextFormField(
                  onChanged: (value) => reasonText = value,
                  autofocus: true,
                  maxLength: InputLimits.noteMax,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivo obligatorio',
                  ),
                  validator: (value) => InputLimits.text(
                    value ?? '',
                    min: InputLimits.noteMin,
                    max: InputLimits.noteMax,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, reasonText.trim());
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return current ? result : null;
  }

  Future<void> withReason(
    String title,
    Future<void> Function(String) action, {
    String? explanation,
  }) async {
    if (busy) return;
    final reason = await askReason(title, explanation: explanation);
    if (reason != null && current) await run(() => action(reason));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Gestionar reporte')),
      body: FutureBuilder<ReportManagement>(
        future: loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionErrorMessage(snapshot.error!)),
                    TextButton(
                      onPressed: () => setState(() {
                        loading = loadManagement();
                      }),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final view = snapshot.data!;
          final report = view.report;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(report.title, style: Theme.of(context).textTheme.titleLarge),
              Text('Estado: ${ReportLabels.status(report.status)}'),
              if (report.isDemo)
                const Text(
                  'Demostración: las acciones y revisiones se identificarán como demo.',
                ),
              if (busy) const LinearProgressIndicator(),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    message!,
                    key: const ValueKey('management-message'),
                  ),
                ),
              if (view.canEdit)
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditReportPage(
                                initial: view,
                                uid: widget.uid,
                                auth: p.auth,
                                reports: p.reports,
                                storage: p.storage,
                                selection: p.selection,
                                drafts: p.drafts,
                                reader: p.reader,
                                categories: p.categories,
                                location: p.location,
                                tiles: p.tiles,
                              ),
                            ),
                          );
                          if (current) {
                            setState(() {
                              loading = loadManagement();
                            });
                          }
                        },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar reporte'),
                ),
              if (view.isAdmin) ...[
                const Divider(),
                const Text('Administración'),
                if (report.status == ReportStatus.reported)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => withReason(
                            'Iniciar seguimiento',
                            (reason) => p.resolutions.transition(
                              reportId: p.id,
                              to: ReportStatus.inFollowUp,
                              expectedRevision: report.revision,
                              reason: reason,
                            ),
                          ),
                    child: const Text('Iniciar seguimiento'),
                  ),
                if (report.status == ReportStatus.inFollowUp)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => withReason(
                            'Devolver a reportado',
                            (reason) => p.resolutions.transition(
                              reportId: p.id,
                              to: ReportStatus.reported,
                              expectedRevision: report.revision,
                              reason: reason,
                            ),
                          ),
                    child: const Text('Devolver a reportado'),
                  ),
                if (report.status == ReportStatus.resolved)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => withReason(
                            'Reabrir reporte',
                            (reason) => p.resolutions.transition(
                              reportId: p.id,
                              to: ReportStatus.inFollowUp,
                              expectedRevision: report.revision,
                              reason: reason,
                            ),
                          ),
                    child: const Text('Reabrir reporte'),
                  ),
              ],
              const SizedBox(height: 16),
              Text(
                view.isAdmin
                    ? 'Propuestas de solución'
                    : 'Mis propuestas de solución',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (view.proposals.isEmpty)
                const Text('No hay propuestas para mostrar.'),
              for (final proposal in view.proposals)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(switch (proposal.status) {
                          ProposalStatus.pending => 'Pendiente de revisión',
                          ProposalStatus.approved => 'Aprobada',
                          ProposalStatus.rejected => 'Rechazada',
                        }),
                        Text(ReportLabels.date(proposal.createdAt)),
                        Text(proposal.note),
                        SizedBox(
                          height: 180,
                          child: ReportPhoto(
                            path: proposal.photoPath,
                            reader: p.reader,
                          ),
                        ),
                        if (proposal.reviewNote != null)
                          Text('Motivo de revisión: ${proposal.reviewNote}'),
                        if (view.isAdmin &&
                            proposal.status == ProposalStatus.pending)
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => withReason(
                                        'Aprobar solución',
                                        (reason) => p.resolutions.approve(
                                          proposalId: proposal.id,
                                          reason: reason,
                                        ),
                                        explanation: 'El reporte quedará solucionado y las demás propuestas pendientes se rechazarán como sustituidas.',
                                      ),
                                child: const Text('Aprobar'),
                              ),
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => withReason(
                                        'Rechazar propuesta',
                                        (reason) => p.resolutions.reject(
                                          proposalId: proposal.id,
                                          reason: reason,
                                        ),
                                      ),
                                child: const Text('Rechazar'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              if (view.canPropose) ...[
                const Divider(),
                Text(
                  'Proponer solución',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Adjunta una fotografía y describe la solución. El reporte mantendrá su estado hasta que un administrador apruebe la evidencia.',
                ),
                TextField(
                  controller: note,
                  enabled: !busy,
                  maxLength: InputLimits.noteMax,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Nota de solución',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy ? null : () => pick(true),
                      child: const Text('Cámara'),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : () => pick(false),
                      child: Text(
                        photo == null ? 'Galería' : 'Reemplazar evidencia',
                      ),
                    ),
                  ],
                ),
                if (photo != null)
                  SizedBox(
                    height: 180,
                    child: ReportPhoto(
                      path: photo!.relativePath,
                      reader: p.reader,
                    ),
                  ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          if (photo == null) {
                            throw const PhotoStorageException();
                          }
                          await p.resolutions.propose(
                            reportId: p.id,
                            note: note.text,
                            photo: photo!,
                            requestId: requestId,
                          );
                          // Successful submission owns the evidence. A later proposal uses a new receipt.
                          photo = null;
                          requestId = const Uuid().v4();
                          if (mounted) note.clear();
                        }),
                  child: const Text('Enviar propuesta'),
                ),
                const Text(
                  'La nota y evidencia sin enviar se pierden al salir de esta pantalla.',
                ),
              ],
              if (view.canDelete) ...[
                const Divider(),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => withReason(
                          '¿Eliminar reporte?',
                          (reason) => p.reports.softDelete(
                            reportId: p.id,
                            reason: reason,
                          ),
                          explanation: 'Dejará de mostrarse en listas y mapas. Se conservarán sus datos, fotos e historial para los informes de acciones.',
                        ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar reporte'),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}
