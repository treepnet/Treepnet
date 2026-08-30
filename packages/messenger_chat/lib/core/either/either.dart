part of messenger_chat;

/// Signature of callbacks that have no arguments and return right or left value.
typedef Callback<T> = void Function(T value);

/// Represents a value of one of two possible types (a disjoint union).
/// Instances of [_Either] are either an instance of [_Left] or [_Right].
/// FP Convention dictates that:
///   [_Left] is used for "failure".
///   [_Right] is used for "success".
abstract class _Either<L, R> {
  const _Either();

  /// Represents the left side of [_Either] class which by convention is a "Failure".
  bool get isLeft => this is _Left<L, R>;

  /// Represents the right side of [_Either] class which by convention is a "Success"
  bool get isRight => this is _Right<L, R>;

  L get left {
    if (this is _Left<L, R>) {
      return (this as _Left<L, R>).value;
    } else {
      throw Exception('Illegal use. You should check isLeft() before calling ');
    }
  }

  R get right {
    if (this is _Right<L, R>) {
      return (this as _Right<L, R>).value;
    } else {
      throw Exception('Illegal use. You should check isRight() before calling');
    }
  }

  void either(Callback<L> fnL, Callback<R> fnR) {
    if (isLeft) {
      final left = this as _Left<L, R>;
      fnL(left.value);
    }

    if (isRight) {
      final right = this as _Right<L, R>;
      fnR(right.value);
    }
  }
}
