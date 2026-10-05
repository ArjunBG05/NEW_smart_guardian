enum UserRole { patient, guardian }

extension UserRoleX on UserRole {
  String get label => 
  this == UserRole.patient ? 'Patient' : 'Guardian';
}