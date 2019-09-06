import 'package:http/http.dart' as http;

import 'package:repository/repository.dart';

void main() {
  var comicUrls = CachedRepository<String>(
    source: ComicMetadataDownloader(),
    cache: InMemoryStorage(),
  );
}

class ComicMetadataDownloader extends Repository<String> {
  ComicMetadataDownloader() : super(isFinite: false, isMutable: false);

  @override
  Stream<String> fetch(Id<String> id) async* {
    yield http.get('https://xkcd.com/$id/info.0.json')['img'] as String;
  }
}
