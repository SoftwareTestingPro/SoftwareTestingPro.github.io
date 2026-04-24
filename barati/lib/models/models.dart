import 'package:flutter/material.dart';

enum UserRole {
  host,
  baratiMember, // Someone willing to play a relative role
}

enum FamilyRole {
  father,
  mother,
  elderBrother,
  youngerBrother,
  elderSister,
  youngerSister,
  uncle,
  aunt,
  paternalCousin,
  maternalCousin,
  grandparent,
  fatherInLaw,
  motherInLaw,
  brotherInLaw,
  sisterInLaw,
  friend,
  colleague,
  neighbor,
  bestMan,
  maidOfHonor,
  other,
}

extension FamilyRoleExtension on FamilyRole {
  String toLabel() {
    String name = this.name;
    String label = name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').toLowerCase();
    return label[0].toUpperCase() + label.substring(1);
  }
}

class FamilyRoleHelper {
  static FamilyRole fromLabel(String label) {
    return FamilyRole.values.firstWhere(
      (e) => e.toLabel().toLowerCase() == label.toLowerCase(),
      orElse: () => FamilyRole.other,
    );
  }
}

enum EventType {
  marriage,
  haldi,
  mehndi,
  sangeet,
  reception,
  engagement,
  birthday,
  babyShower,
  houseWarming,
  anniversary,
  death,
  other,
}

class BaratiUser {
  final String id;
  final String name;
  final int age;
  final String gender;
  final UserRole userRole;
  final List<FamilyRole> possibleRoles;
  final String bio;
  final String? profileImageUrl;
  final String city;
  final String state;
  final String profession;
  final String education;
  final List<String> languages;

  BaratiUser({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.userRole,
    this.possibleRoles = const [],
    required this.bio,
    this.profileImageUrl,
    this.city = '',
    this.state = '',
    this.profession = '',
    this.education = '',
    this.languages = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'gender': gender,
    'userRole': userRole.index,
    'possibleRoles': possibleRoles.map((r) => r.index).toList(),
    'bio': bio,
    'profileImageUrl': profileImageUrl,
    'city': city,
    'state': state,
    'profession': profession,
    'education': education,
    'languages': languages,
  };

  factory BaratiUser.fromJson(Map<String, dynamic> json) => BaratiUser(
    id: json['id'],
    name: json['name'],
    age: json['age'],
    gender: json['gender'],
    userRole: UserRole.values[json['userRole'] ?? 1],
    possibleRoles: (json['possibleRoles'] as List? ?? []).map((r) => FamilyRole.values[r as int]).toList(),
    bio: json['bio'] ?? '',
    profileImageUrl: json['profileImageUrl'],
    city: json['city'] ?? '',
    state: json['state'] ?? '',
    profession: json['profession'] ?? '',
    education: json['education'] ?? '',
    languages: List<String>.from(json['languages'] ?? []),
  );
}

class EventRole {
  final FamilyRole role;
  final String description;
  final String gender; // 'Male', 'Female', 'Any'
  final String forWhom; // 'Bride', 'Groom', 'Other'

  EventRole({
    required this.role,
    required this.description,
    required this.gender,
    this.forWhom = 'Other',
  });

  Map<String, dynamic> toJson() => {
    'role': role.index,
    'description': description,
    'gender': gender,
    'forWhom': forWhom,
  };

  factory EventRole.fromJson(Map<String, dynamic> json) => EventRole(
    role: FamilyRole.values[json['role']],
    description: json['description'] ?? '',
    gender: json['gender'] ?? 'Any',
    forWhom: json['forWhom'] ?? 'Other',
  );

  static String? getFixedGender(FamilyRole role) {
    switch (role) {
      case FamilyRole.father:
      case FamilyRole.elderBrother:
      case FamilyRole.youngerBrother:
      case FamilyRole.uncle:
      case FamilyRole.fatherInLaw:
      case FamilyRole.brotherInLaw:
      case FamilyRole.bestMan:
        return 'Male';
      case FamilyRole.mother:
      case FamilyRole.elderSister:
      case FamilyRole.youngerSister:
      case FamilyRole.aunt:
      case FamilyRole.motherInLaw:
      case FamilyRole.sisterInLaw:
      case FamilyRole.maidOfHonor:
        return 'Female';
      default:
        return null;
    }
  }
}

class BaratiEvent {
  final String id;
  final String hostId; // User ID of Bride/Groom
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final EventType eventType;
  final List<EventRole> neededRoles;
  final List<String> approvedMemberIds;

  BaratiEvent({
    required this.id,
    required this.hostId,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.eventType,
    required this.neededRoles,
    this.approvedMemberIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'hostId': hostId,
    'title': title,
    'description': description,
    'date': date.toIso8601String(),
    'location': location,
    'eventType': eventType.index,
    'neededRoles': neededRoles.map((r) => r.toJson()).toList(),
    'approvedMemberIds': approvedMemberIds,
  };

  factory BaratiEvent.fromJson(Map<String, dynamic> json) => BaratiEvent(
    id: json['id'],
    hostId: json['hostId'],
    title: json['title'],
    description: json['description'],
    date: DateTime.parse(json['date']),
    location: json['location'],
    eventType: EventType.values[json['eventType']],
    neededRoles: (json['needed_roles'] ?? json['neededRoles'] as List)
        .map((r) => r is int ? EventRole(role: FamilyRole.values[r], description: '', gender: 'Any') : EventRole.fromJson(r))
        .toList(),
    approvedMemberIds: List<String>.from(json['approved_member_ids'] ?? json['approvedMemberIds'] ?? []),
  );
}

class RoleApplication {
  final String id;
  final String eventId;
  final String applicantId;
  final FamilyRole appliedRole;
  final String message;
  final bool isApproved;

  RoleApplication({
    required this.id,
    required this.eventId,
    required this.applicantId,
    required this.appliedRole,
    required this.message,
    this.isApproved = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'applicantId': applicantId,
    'appliedRole': appliedRole.index,
    'message': message,
    'isApproved': isApproved,
  };

  factory RoleApplication.fromJson(Map<String, dynamic> json) => RoleApplication(
    id: json['id'],
    eventId: json['eventId'],
    applicantId: json['applicantId'],
    appliedRole: FamilyRole.values[json['appliedRole']],
    message: json['message'],
    isApproved: json['isApproved'],
  );
}
