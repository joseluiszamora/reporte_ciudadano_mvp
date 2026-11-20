import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/location/geo_point.dart';
import '../../../core/location/location_gateway.dart';

class LocationState {
  const LocationState({
    this.point,
    this.busy = false,
    this.failure,
    this.focusRevision = 0,
  });
  final GeoPoint? point;
  final bool busy;
  final LocationFailure? failure;
  final int focusRevision;
  String? get error =>
      failure == null ? null : LocationException(failure!).message;
}

class LocationCubit extends Cubit<LocationState> {
  LocationCubit(this.gateway, {GeoPoint? initial})
    : super(LocationState(point: initial));
  final LocationGateway gateway;
  int _request = 0;

  void selectManual(GeoPoint point) {
    _request++;
    emit(LocationState(point: point, focusRevision: state.focusRevision + 1));
  }

  Future<void> locate() async {
    if (state.busy) return;
    final request = ++_request;
    emit(
      LocationState(
        point: state.point,
        busy: true,
        focusRevision: state.focusRevision,
      ),
    );
    try {
      final point = await gateway.locate();
      if (!isClosed && request == _request) {
        emit(
          LocationState(point: point, focusRevision: state.focusRevision + 1),
        );
      }
    } on LocationException catch (error) {
      if (!isClosed && request == _request) {
        emit(
          LocationState(
            point: state.point,
            failure: error.failure,
            focusRevision: state.focusRevision,
          ),
        );
      }
    } catch (_) {
      if (!isClosed && request == _request) {
        emit(
          LocationState(
            point: state.point,
            failure: LocationFailure.unavailable,
            focusRevision: state.focusRevision,
          ),
        );
      }
    }
  }
}
