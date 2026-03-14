class AppPreferences {
  const AppPreferences({this.isDarkMode = false});

  final bool isDarkMode;

  AppPreferences copyWith({bool? isDarkMode}) {
    return AppPreferences(isDarkMode: isDarkMode ?? this.isDarkMode);
  }

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    return AppPreferences(isDarkMode: json['isDarkMode'] as bool? ?? false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'isDarkMode': isDarkMode};
  }

  @override
  bool operator ==(Object other) {
    return other is AppPreferences && other.isDarkMode == isDarkMode;
  }

  @override
  int get hashCode => isDarkMode.hashCode;
}
