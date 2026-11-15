import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/chat/backend/dm_api.dart';

void main() {
  test('no answer in time is its own result, not a refusal', () {
    const timedOut = DmSendResult.timedOut();
    expect(timedOut.ok, isFalse);
    expect(timedOut.timedOut, isTrue);
    expect(timedOut.isRejected, isFalse, reason: 'it may still arrive');

    final refused = DmSendResult.fromAck({'status': 'error', 'code': 'BLOCKED'});
    expect(refused.timedOut, isFalse);
    expect(refused.isRejected, isTrue);
  });
}
