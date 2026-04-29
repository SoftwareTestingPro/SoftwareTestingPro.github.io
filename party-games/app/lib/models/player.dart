enum Gender { male, female }

class Player {
  final String name;
  final Gender gender;

  Player({required this.name, required this.gender});

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender.name,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    name: json['name'],
    gender: Gender.values.byName(json['gender']),
  );
}
