import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/repository_exception.dart';
import '../../../core/location/geo_point.dart';
import '../../../core/media/photo_selection.dart';
import '../../../core/media/photo_storage.dart';
import '../../../core/validation/input_limits.dart';
import '../data/report_draft_store.dart';
import '../domain/report_composition.dart';
import '../domain/report_repository.dart';

class ComposerState {
  ComposerState({
    required this.draft,
    this.loading = false,
    this.busy = false,
    this.message,
    this.savedId,
  });
  final ReportComposition draft;
  final bool loading;
  final bool busy;
  final String? message;
  final String? savedId;
}

class ReportComposerCubit extends Cubit<ComposerState> {
  ReportComposerCubit({
    required this.uid,
    required this.currentUid,
    required this.reports,
    required this.storage,
    required this.selection,
    required this.drafts,
  }) : super(ComposerState(draft: ReportComposition(), loading: true));
  final String uid;
  final String? Function() currentUid;
  final ReportRepository reports;
  final PhotoStorage storage;
  final PhotoSelection selection;
  final ReportDraftStore drafts;
  Future<void> writes = Future.value();
  bool committed = false;
  bool closing = false;
  void checkSession() {
    if (currentUid() != uid) {
      throw const RepositoryException(
        RepositoryError.unauthenticated,
        'La sesión cambió. Vuelve a iniciar sesión.',
      );
    }
  }

  String error(Object error) => error is RepositoryException
      ? error.message
      : error is PhotoStorageException
      ? error.message
      : 'No se pudo conservar el borrador. Vuelve a intentarlo.';
  void publish(
    ReportComposition draft, {
    bool busy = false,
    String? message,
    String? savedId,
  }) {
    if (!isClosed && !closing) {
      emit(
        ComposerState(
          draft: draft,
          busy: busy,
          message: message,
          savedId: savedId,
        ),
      );
    }
  }

  Future<void> flush() {
    if (committed) return writes;
    final draft = state.draft;
    final work = drafts.save(uid, draft);
    writes = work.catchError((Object _) {});
    return work;
  }

  void update(ReportComposition draft) {
    if (state.loading || state.busy || committed) return;
    publish(draft);
    unawaited(
      flush().catchError(
        (Object failure) =>
            publish(state.draft, busy: state.busy, message: error(failure)),
      ),
    );
  }

  Future<void> initialize() async {
    try {
      checkSession();
      final draft = await drafts.load(uid) ?? state.draft;
      final existing = await reports.getReport(draft.requestId);
      if (existing != null) {
        committed = true;
        try {
          await drafts.delete(uid);
        } catch (_) {
          /* Still open the already committed report. */
        }
        publish(draft, savedId: existing.id);
        return;
      }
      publish(draft, busy: true);
      if (await drafts.pendingOwner() == uid) {
        try {
          await addPaths(await selection.recover());
        } finally {
          await drafts.clearPicker(uid);
        }
      } else {
        publish(draft);
      }
    } catch (failure) {
      publish(state.draft, message: error(failure));
    }
  }

  Future<void> pick({required bool camera}) async {
    if (state.busy || state.loading || committed) return;
    publish(state.draft, busy: true);
    try {
      checkSession();
      await flush();
      await drafts.markPicker(uid);
      await addPaths(
        await selection.pick(
          camera: camera,
          remaining: InputLimits.maxPhotos - state.draft.photos.length,
        ),
      );
    } catch (failure) {
      publish(state.draft, message: error(failure));
    } finally {
      try {
        await drafts.clearPicker(uid);
      } catch (_) {
        /* Existing draft remains recoverable. */
      }
      if (state.busy) publish(state.draft);
    }
  }

  Future<void> addPaths(List<String> paths) async {
    var draft = state.draft;
    for (final source in paths.take(
      InputLimits.maxPhotos - draft.photos.length,
    )) {
      checkSession();
      if (closing || isClosed) return;
      final photo = await storage.import(source);
      if (closing || isClosed || currentUid() != uid) {
        await storage.remove(photo.relativePath);
        checkSession();
        return;
      }
      draft = draft.copy(photos: [...draft.photos, photo]);
      publish(draft, busy: true);
      await flush();
    }
    publish(draft);
  }

  Future<void> removePhoto(int index) async {
    if (state.busy || state.loading || committed) return;
    final removed = state.draft.photos[index];
    final photos = [...state.draft.photos]..removeAt(index);
    publish(state.draft.copy(photos: photos), busy: true);
    try {
      await flush();
      await storage.remove(removed.relativePath);
      publish(state.draft);
    } catch (failure) {
      publish(state.draft, message: error(failure));
    }
  }

  String? validate() {
    final draft = state.draft;
    if (draft.categoryId == null) return 'Elige una categoría.';
    if (InputLimits.text(
          draft.title,
          min: InputLimits.titleMin,
          max: InputLimits.titleMax,
        ) !=
        null) {
      return 'El título debe tener entre 10 y 100 caracteres.';
    }
    if (InputLimits.text(
          draft.description,
          min: InputLimits.descriptionMin,
          max: InputLimits.descriptionMax,
        ) !=
        null) {
      return 'La descripción debe tener entre 20 y 2.000 caracteres.';
    }
    if (draft.photos.isEmpty) return 'Adjunta al menos una fotografía.';
    if (draft.point == null) return 'Elige la ubicación del problema.';
    return null;
  }

  Future<bool> preview() async {
    final invalid = validate();
    if (invalid != null) {
      publish(state.draft, message: invalid);
      return false;
    }
    try {
      checkSession();
      await flush();
      return true;
    } catch (failure) {
      publish(state.draft, message: error(failure));
      return false;
    }
  }

  Future<void> submit() async {
    if (state.busy || committed || state.loading) return;
    final invalid = validate();
    if (invalid != null) {
      publish(state.draft, message: invalid);
      return;
    }
    publish(state.draft, busy: true);
    try {
      checkSession();
      await flush();
      final id = await reports.create(state.draft.toReport());
      committed = true;
      try {
        await drafts.delete(uid);
      } catch (_) {
        /* requestId makes retry/recovery idempotent. */
      }
      publish(state.draft, savedId: id);
    } catch (failure) {
      publish(
        state.draft,
        message:
            failure is RepositoryException || failure is PhotoStorageException
            ? error(failure)
            : 'No se pudo guardar el reporte. Mantén este formulario abierto y vuelve a intentarlo.',
      );
    }
  }

  Future<void> discard() async {
    if (state.busy || committed) return;
    publish(state.draft, busy: true);
    try {
      await writes;
      final photos = state.draft.photos;
      await drafts.delete(uid);
      for (final photo in photos) {
        await storage.remove(photo.relativePath);
      }
      publish(ReportComposition());
    } catch (failure) {
      publish(state.draft, message: error(failure));
    }
  }

  void setPoint(GeoPoint point) => update(state.draft.copy(point: point));
  @override
  Future<void> close() async {
    closing = true;
    try {
      if (!committed) await flush();
    } catch (_) {
      /* Screen already closed; persisted photos stay private. */
    }
    return super.close();
  }
}
