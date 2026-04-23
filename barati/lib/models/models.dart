import 'package:flutter/material.dart';

enum UserRole {
  host,
  baratiMember, // Someone willing to play a relative role
}

enum FamilyRole {
  father,
  mother,
  brother,
  sister,
  friend,
  uncle,
  aunt,
  cousin,
  grandparent,
  fatherInLaw,
  motherInLaw,
  brotherInLaw,
  sisterInLaw,
  bestMan,
  maidOfHonor,
  other,
}

enum EventType {
  marriage,
  haldi,
  mehndi,
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

  BaratiUser({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.userRole,
    this.possibleRoles = const [],
    required this.bio,
    this.profileImageUrl,
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
  };

  factory BaratiUser.fromJson(Map<String, dynamic> json) => BaratiUser(
    id: json['id'],
    name: json['name'],
    age: json['age'],
    gender: json['gender'],
    userRole: UserRole.values[json['userRole']],
    possibleRoles: (json['possibleRoles'] as List).map((r) => FamilyRole.values[r as int]).toList(),
    bio: json['bio'],
    profileImageUrl: json['profileImageUrl'],
  );
}

class BaratiEvent {
  final String id;
  final String hostId; // User ID of Bride/Groom
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final EventType eventType;
  final List<FamilyRole> neededRoles;
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
    'neededRoles': neededRoles.map((r) => r.index).toList(),
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
    neededRoles: (json['neededRoles'] as List).map((r) => FamilyRole.values[r as int]).toList(),
    approvedMemberIds: List<String>.from(json['approvedMemberIds']),
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
