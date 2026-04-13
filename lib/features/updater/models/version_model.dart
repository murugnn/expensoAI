class VersionModel {
  final String version;
  final String buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  VersionModel({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
  });

  factory VersionModel.fromJson(Map<String, dynamic> json) {
    return VersionModel(
      version: json['version'] ?? '',
      buildNumber: json['build_number']?.toString() ?? '',
      downloadUrl: json['download_url'] ?? '',
      releaseNotes: json['release_notes'] ?? '',
      forceUpdate: json['force_update'] ?? false,
    );
  }
}
