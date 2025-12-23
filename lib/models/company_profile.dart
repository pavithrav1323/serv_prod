class CompanyProfile {
  final String name;
  final String adminName;
  final String? logoUrl;

  const CompanyProfile({
    required this.name,
    required this.adminName,
    this.logoUrl,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      name: json['name'] ?? '',
      adminName: json['adminName'] ?? '',
      logoUrl: json['logoUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'adminName': adminName,
      if (logoUrl != null) 'logoUrl': logoUrl,
    };
  }
}
