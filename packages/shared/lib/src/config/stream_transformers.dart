import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:stream_transform/stream_transform.dart';

/// Cancels the running handler when the same event arrives again. Needed by
/// handlers that hold a subscription open for their whole lifetime, so a
/// re-dispatch replaces the feed instead of stacking a second listener on top.
export 'package:bloc_concurrency/bloc_concurrency.dart' show restartable;

/// The default duration of throttling on `stream`.
const kDefaultThrottleDuration = Duration(milliseconds: 100);

/// Signature for a function which converts an incoming event
/// into an outbound stream of events.
/// Used when defining custom [EventTransformer]s.
typedef EventMapper<Event> = Stream<Event> Function(Event event);

/// Used to change how events are processed.
/// By default events are processed concurrently.
typedef EventTransformer<Event> =
    Stream<Event> Function(
      Stream<Event> events,
      EventMapper<Event> mapper,
    );

/// Throttles events by [duration].
EventTransformer<E> throttleDroppable<E>({
  Duration duration = kDefaultThrottleDuration,
}) {
  return (events, mapper) {
    return droppable<E>().call(events.throttle(duration), mapper);
  };
}
