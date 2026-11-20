import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano_mvp/features/auth/domain/app_user.dart';
import 'package:reporte_ciudadano_mvp/features/reports/domain/report_policy.dart';
import 'package:reporte_ciudadano_mvp/core/validation/input_limits.dart';

void main() {
  const citizen = AppUser(uid: 'owner', publicName: 'Vecina');
  const admin = AppUser(
    uid: 'admin',
    publicName: 'Administración',
    role: UserRole.admin,
  );

  test('visitor and incomplete profile cannot create', () {
    expect(ReportPolicy.canCreate(null), isFalse);
    expect(
      ReportPolicy.canCreate(const AppUser(uid: 'u', publicName: ' ')),
      isFalse,
    );
  });
  test('ownership and state restrict editing', () {
    expect(
      ReportPolicy.canEdit(citizen, 'other', ReportStatus.reported),
      isFalse,
    );
    expect(
      ReportPolicy.canEdit(citizen, 'owner', ReportStatus.reported),
      isTrue,
    );
    expect(
      ReportPolicy.canEdit(citizen, 'owner', ReportStatus.inFollowUp),
      isFalse,
    );
  });
  test('only admin reviews pending evidence and cannot resolve by direct transition', () {
    expect(
      ReportPolicy.canApprove(
        citizen,
        ReportStatus.reported,
        ProposalStatus.pending,
      ),
      isFalse,
    );
    expect(
      ReportPolicy.canApprove(
        admin,
        ReportStatus.reported,
        ProposalStatus.pending,
      ),
      isTrue,
    );
    expect(
      ReportPolicy.canApprove(
        admin,
        ReportStatus.reported,
        ProposalStatus.approved,
      ),
      isFalse,
    );
    expect(
      ReportPolicy.canApprove(
        admin,
        ReportStatus.resolved,
        ProposalStatus.pending,
      ),
      isFalse,
    );
    expect(
      ReportPolicy.canTransition(
        admin,
        ReportStatus.reported,
        ReportStatus.resolved,
      ),
      isFalse,
    );
    expect(
      ReportPolicy.canTransition(
        admin,
        ReportStatus.resolved,
        ReportStatus.inFollowUp,
      ),
      isTrue,
    );
  });
  test('coordinates reject nonfinite values and text trims whitespace', () {
    expect(InputLimits.validCoordinates(double.nan, -68), isFalse);
    expect(InputLimits.validCoordinates(-16.5, double.infinity), isFalse);
    expect(InputLimits.validCoordinates(91, -68), isFalse);
    expect(InputLimits.validCoordinates(-16.5, -68.15), isTrue);
    expect(InputLimits.text('   ', min: 2, max: 50), isNotNull);
    expect(InputLimits.text(' Ana ', min: 2, max: 50), isNull);
  });
}
