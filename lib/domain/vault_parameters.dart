class VaultParameters {
  final int schemaVersion;
  final String cipher;
  final String kdf;
  final int memory;
  final int iterations;
  final int parallelism;
  final String salt;
  final DateTime createdAt;

  const VaultParameters({
    required this.schemaVersion,
    required this.cipher,
    required this.kdf,
    required this.memory,
    required this.iterations,
    required this.parallelism,
    required this.salt,
    required this.createdAt,
  });

  factory VaultParameters.fromJson(Map<String, dynamic> json) {
    return VaultParameters(
      schemaVersion: json['schema_version'] as int,
      cipher: json['cipher'] as String,
      kdf: json['kdf'] as String,
      memory: json['memory'] as int,
      iterations: json['iterations'] as int,
      parallelism: json['parallelism'] as int,
      salt: json['salt'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'cipher': cipher,
      'kdf': kdf,
      'memory': memory,
      'iterations': iterations,
      'parallelism': parallelism,
      'salt': salt,
      'created_at': createdAt.toIso8601String(),
    };
  }
}