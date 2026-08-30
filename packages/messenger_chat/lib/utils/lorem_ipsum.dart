part of messenger_chat;

mixin _RandomLoremIpsum {
  static String generate({int min = 3, int max = 10}) {
    final random = math.Random();
    final count = min + random.nextInt(max - min + 1);
    return List.generate(count, (index) => 'lorem ').join(' ');
  }
}
