import 'package:hive/hive.dart';
import 'package:repository/repository.dart';
import 'package:repository_hive/repository_hive.dart';

void main() async {
  await Hive.init('.');
  doStuff();
  await Future.delayed(Duration(seconds: 1));
}

Future<void> doStuff() async {
  print('Doing stuff');
  Repository<int> storage = CachedRepository<int>(
    strategy: CacheStrategy.onlyFetchFromSourceIfNotInCache,
    cache: HiveRepository('threes'),
    source: ThreeGenerator(),
  );

  var id = const Id<int>('anything');

  var stream = storage.fetch(id);
  print('Fetching from stream $stream.');
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
