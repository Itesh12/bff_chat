class ParticipantEntity {
  final String id;
  final String username;
  final String identityKeyPub;

  const ParticipantEntity({
    required this.id,
    required this.username,
    required this.identityKeyPub,
  });

  ParticipantEntity copyWith({
    String? id,
    String? username,
    String? identityKeyPub,
  }) {
    return ParticipantEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      identityKeyPub: identityKeyPub ?? this.identityKeyPub,
    );
  }
}
