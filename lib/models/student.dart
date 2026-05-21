class Student {
  final String roll;
  final String name;
  final String year;
  final String branch;
  final bool busPaid;
  final String busRouteNo;

  /// Local file path of the downloaded image.
  String photoPath;

  /// Original image URL from the CSV.
  final String photoUrl;

  Student({
    required this.roll,
    required this.name,
    required this.year,
    required this.branch,
    required this.busPaid,
    required this.busRouteNo,
    required this.photoPath,
    required this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'roll': roll,
      'name': name,
      'year': year,
      'branch': branch,
      'bus_paid': busPaid ? 1 : 0,
      'bus_route_no': busRouteNo,
      'photo_path': photoPath,
      'photo_url': photoUrl,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      roll: map['roll']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      year: map['year']?.toString() ?? '',
      branch: map['branch']?.toString() ?? '',
      busPaid: (map['bus_paid'] ?? 0) == 1,
      busRouteNo: map['bus_route_no']?.toString() ?? '',
      photoPath: map['photo_path']?.toString() ?? '',
      photoUrl: map['photo_url']?.toString() ?? '',
    );
  }

  Student copyWith({
    String? roll,
    String? name,
    String? year,
    String? branch,
    bool? busPaid,
    String? busRouteNo,
    String? photoPath,
    String? photoUrl,
  }) {
    return Student(
      roll: roll ?? this.roll,
      name: name ?? this.name,
      year: year ?? this.year,
      branch: branch ?? this.branch,
      busPaid: busPaid ?? this.busPaid,
      busRouteNo: busRouteNo ?? this.busRouteNo,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
