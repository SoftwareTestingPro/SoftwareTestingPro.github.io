import 'package:flutter/material.dart';

enum UserRole {
  brideGroom,
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
}

class WeddingEvent {
  final String id;
  final String hostId; // User ID of Bride/Groom
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final List<FamilyRole> neededRoles;
  final List<String> approvedMemberIds;

  WeddingEvent({
    required this.id,
    required this.hostId,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.neededRoles,
    this.approvedMemberIds = const [],
  });
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
}
