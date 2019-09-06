import 'package:hive/hive.dart';
import 'package:repository/repository.dart';
import 'package:repository_hive/repository_hive.dart';

void main() async {
  await Hive.init('hive');
  var storage = HiveRepository<int>('test');
  storage.update(Id<int>('a'), 1);
}
