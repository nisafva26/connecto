enum CircleStateStatus { idle, loading, success, error }

class CircleState {
  final CircleStateStatus status;
  final String? errorMessage;

  CircleState({required this.status, this.errorMessage});

  factory CircleState.idle() => CircleState(status: CircleStateStatus.idle);
  factory CircleState.loading() => CircleState(status: CircleStateStatus.loading);
  factory CircleState.success() => CircleState(status: CircleStateStatus.success);
  factory CircleState.error(String message) =>
      CircleState(status: CircleStateStatus.error, errorMessage: message);
}
