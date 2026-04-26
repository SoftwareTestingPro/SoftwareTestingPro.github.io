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
  fatherInLaw,
  motherInLaw,
  brotherInLaw,
  sisterInLaw,
  friend,
  colleague,
  neighbor,
  bestMan,
  maidOfHonor,
  girlfriend,
  exGirlfriend,
  boyfriend,
  exBoyfriend,
  other,
}

extension FamilyRoleExtension on FamilyRole {
  String toLabel() {
    String name = this.name;
    String label = name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').toLowerCase();
    if (label.startsWith('ex ')) {
      label = 'Ex-${label.substring(3)}';
    }
    return label[0].toUpperCase() + label.substring(1);
  }

  bool isValidForGender(String gender) {
    if (this == FamilyRole.other) return true;
    final fixedGender = EventRole.getFixedGender(this);
    if (fixedGender == null) return true; // Flexible roles
    
    // Determine the user's identification for role mapping
    if (gender == 'Male' || gender == 'Transgender man') {
      return fixedGender == 'Male';
    } else if (gender == 'Female' || gender == 'Transgender woman') {
      return fixedGender == 'Female';
    }
    
    // For non-binary, genderqueer, etc., allow all roles
    return true;
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
  houseParty,
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
    userRole: json['userRole'] != null && json['userRole'] < UserRole.values.length 
        ? UserRole.values[json['userRole']] 
        : UserRole.baratiMember,
    possibleRoles: (json['possibleRoles'] as List? ?? []).map((r) {
      int index = r as int;
      return index < FamilyRole.values.length ? FamilyRole.values[index] : FamilyRole.other;
    }).toList(),
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

  factory EventRole.fromJson(Map<String, dynamic> json) {
    int roleIndex = json['role'] ?? FamilyRole.other.index;
    return EventRole(
      role: roleIndex < FamilyRole.values.length ? FamilyRole.values[roleIndex] : FamilyRole.other,
      description: json['description'] ?? '',
      gender: json['gender'] ?? 'Any',
      forWhom: json['forWhom'] ?? 'Other',
    );
  }
  
  static bool matchGender(String userGender, String requiredGender) {
    if (requiredGender == 'Any') return true;
    
    // Determine user's identity group
    if (userGender == 'Male' || userGender == 'Transgender man') {
      return requiredGender == 'Male';
    } else if (userGender == 'Female' || userGender == 'Transgender woman') {
      return requiredGender == 'Female';
    }
    
    // For non-binary, genderqueer, agender, etc., they are allowed for any role requirement
    return true;
  }

  static String? getFixedGender(FamilyRole role) {
    switch (role) {
      case FamilyRole.father:
      case FamilyRole.elderBrother:
      case FamilyRole.youngerBrother:
      case FamilyRole.uncle:
      case FamilyRole.fatherInLaw:
      case FamilyRole.brotherInLaw:
      case FamilyRole.bestMan:
      case FamilyRole.boyfriend:
      case FamilyRole.exBoyfriend:
        return 'Male';
      case FamilyRole.mother:
      case FamilyRole.elderSister:
      case FamilyRole.youngerSister:
      case FamilyRole.aunt:
      case FamilyRole.motherInLaw:
      case FamilyRole.sisterInLaw:
      case FamilyRole.maidOfHonor:
      case FamilyRole.girlfriend:
      case FamilyRole.exGirlfriend:
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
  final String imageUrl;
  final String city;
  final String state;

  BaratiEvent({
    required this.id,
    required this.hostId,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.eventType,
    required this.neededRoles,
    required this.imageUrl,
    required this.city,
    required this.state,
    this.approvedMemberIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'hostId': hostId,
    'title': title,
    'description': description,
    'date': date.toUtc().toIso8601String(),
    'location': location,
    'eventType': eventType.index,
    'neededRoles': neededRoles.map((r) => r.toJson()).toList(),
    'approvedMemberIds': approvedMemberIds,
    'imageUrl': imageUrl,
    'city': city,
    'state': state,
  };

  factory BaratiEvent.fromJson(Map<String, dynamic> json) => BaratiEvent(
    id: json['id'],
    hostId: json['hostId'],
    title: json['title'],
    description: json['description'],
    date: DateTime.parse(json['date']),
    location: json['location'],
    eventType: (json['eventType'] ?? 0) < EventType.values.length 
        ? EventType.values[json['eventType'] ?? 0] 
        : EventType.other,
    neededRoles: (json['needed_roles'] ?? json['neededRoles'] as List)
        .map((r) {
          if (r is int) {
            return EventRole(
              role: r < FamilyRole.values.length ? FamilyRole.values[r] : FamilyRole.other, 
              description: '', 
              gender: 'Any'
            );
          }
          return EventRole.fromJson(r);
        })
        .toList(),
    approvedMemberIds: List<String>.from(json['approved_member_ids'] ?? json['approvedMemberIds'] ?? []),
    imageUrl: json['imageUrl'] ?? 'https://images.unsplash.com/photo-1519741497674-611481863552',
    city: json['city'] ?? '',
    state: json['state'] ?? '',
  );
}

enum ApplicationStatus { pending, approved, declined, withdrawn, invitationPending, invitationAccepted, invitationDeclined }

class RoleApplication {
  final String id;
  final String eventId;
  final String applicantId;
  final FamilyRole appliedRole;
  final String message;
  final bool isApproved;
  final ApplicationStatus status;
  final bool isInvitation;
   final double? userRating; // Guest's rating of the event
  final double? hostRating; // Host's rating of the guest
  final String? userComment; // Guest's comment about the event
  final String? hostComment; // Host's comment about the guest

  RoleApplication({
    required this.id,
    required this.eventId,
    required this.applicantId,
    required this.appliedRole,
    this.message = '',
    this.isApproved = false,
    this.status = ApplicationStatus.pending,
    this.isInvitation = false,
    this.userRating,
    this.hostRating,
    this.userComment,
    this.hostComment,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'applicantId': applicantId,
    'appliedRole': appliedRole.index,
    'message': message,
    'isApproved': isApproved,
    'status': status.index,
    'isInvitation': isInvitation,
    'userRating': userRating,
    'hostRating': hostRating,
    'userComment': userComment,
    'hostComment': hostComment,
  };

  factory RoleApplication.fromJson(Map<String, dynamic> json) => RoleApplication(
    id: json['id'],
    eventId: json['eventId'],
    applicantId: json['applicantId'],
    appliedRole: (json['appliedRole'] ?? 0) < FamilyRole.values.length 
        ? FamilyRole.values[json['appliedRole']] 
        : FamilyRole.other,
    message: json['message'] ?? '',
    isApproved: json['isApproved'] ?? false,
    status: (json['status'] ?? 0) < ApplicationStatus.values.length 
        ? ApplicationStatus.values[json['status'] ?? 0] 
        : ApplicationStatus.pending,
    isInvitation: json['isInvitation'] ?? false,
    userRating: json['userRating']?.toDouble(),
    hostRating: json['hostRating']?.toDouble(),
    userComment: json['userComment'],
    hostComment: json['hostComment'],
  );
}
