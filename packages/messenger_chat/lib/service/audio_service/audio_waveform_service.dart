// part of messenger_chat;
//
// mixin _AudioWaveformService {
//   static Future<Float32List> getWaveform(
//     Uint8List bytes,
//     int width, {
//     bool average = false,
//   }) async => compute(
//     _generateWaveform,
//     WaveformParams(bytes: bytes, width: width, average: average),
//   );
//
//   static void dispose() {
//     wave.SoLoud.instance.deinit();
//   }
// }
//
// class WaveformParams {
//   WaveformParams({
//     required this.bytes,
//     required this.width,
//     required this.average,
//   });
//
//   final Uint8List bytes;
//   final int width;
//   final bool average;
// }
//
// Future<Float32List> _generateWaveform(WaveformParams params) async {
//   final data = await wave.SoLoud.instance.readSamplesFromMem(
//     params.bytes,
//     params.width * 4,
//     average: params.average,
//   );
//   return data;
// }
