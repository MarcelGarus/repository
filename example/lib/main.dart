import 'package:repository/repository.dart';

void main() async {
  doStuff();
  await Future.delayed(Duration(seconds: 1));
}

Future<void> doStuff() async {
  print('Doing stuff');
  Repository<int> storage = CachedRepository<int>(
    strategy: CacheStrategy.onlyFetchFromSourceIfNotInCache,
    cache: InMemoryStorage(),
    source: ThreeGenerator(),
  );
  //storage = ThreeGenerator();

  var id = const Id<int>('anything');

  var stream = storage.fetch(id);
  print('Fetching from stream $stream.');
  /*var future = stream.first;
  print('First future is $future');
  var first = await future;
  print('First is $first');*/
  //stream.listen((item) => print('Stream yielded $item.'));
  print(await stream.first);

  print('Fetching again.');
  print(await storage.fetch(id).first);
}

class ThreeGenerator extends Repository<int> {
  Stream<int> fetch(Id<int> id) async* {
    print('Doing heavy work.');
    await Future.delayed(Duration(seconds: 1));
    yield 3;
  }
}
