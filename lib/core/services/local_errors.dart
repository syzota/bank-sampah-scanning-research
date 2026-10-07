class LocalDataException implements Exception {
  final String message;
  final String code;

  const LocalDataException(this.message, {this.code = 'LOCAL'});

  @override
  String toString() => message;
}

class LocalAuthException implements Exception {
  final String message;

  const LocalAuthException(this.message);

  @override
  String toString() => message;
}
