class ProjectSupport {
  static const String address = 'D76NnH9uCFQni3ZpTbZWiiU22BVXHS2xcA';

  // DGB uses 8 decimal places.
  // 0.1 DGB = 10,000,000 base units.
  static const int amount = 10000000;

  static bool enabledFor(String letterCode) {
    return letterCode == 'DGB';
  }
}
