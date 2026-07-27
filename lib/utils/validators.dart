class Validators {
  static String? required(String? val, String fieldName) {
    if (val == null || val.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? minLength(String? val, int min, String fieldName) {
    if (val == null || val.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (val.trim().length < min) {
      return '$fieldName must be at least $min characters';
    }
    return null;
  }

  static String? positiveDouble(String? val, String fieldName) {
    if (val == null || val.isEmpty) return null;
    final d = double.tryParse(val);
    if (d == null || d <= 0) {
      return '$fieldName must be a positive number';
    }
    return null;
  }

  static String? positiveInteger(String? val, String fieldName) {
    if (val == null || val.isEmpty) return null;
    final i = int.tryParse(val);
    if (i == null || i < 0) {
      return '$fieldName must be a non-negative integer';
    }
    return null;
  }
}
