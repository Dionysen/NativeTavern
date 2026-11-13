import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/models/vector_storage.dart';
import 'package:native_tavern/domain/services/vector_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VectorStorageService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nt_vector_search');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    service = VectorStorageService();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('search ranks by cosine similarity, honors topK and the threshold', () {
    final collection = service.createCollection(name: 'notes', dimensions: 2);
    service.addDocument(
      collectionId: collection.id,
      content: 'close',
      embedding: const [1, 0],
    );
    service.addDocument(
      collectionId: collection.id,
      content: 'far',
      embedding: const [0, 1],
    );
    service.addDocument(
      collectionId: collection.id,
      content: 'unembedded',
    );

    final top = service.search(
      collectionId: collection.id,
      queryEmbedding: const [1, 0],
      topK: 1,
    );
    expect(top.single.document.content, 'close');
    expect(top.single.similarity, closeTo(1, 0.0001));
    expect(service.generateContext(top), contains('close'));

    final filtered = service.search(
      collectionId: collection.id,
      queryEmbedding: const [1, 0],
      similarityThreshold: 0.9,
    );
    expect(filtered.map((result) => result.document.content), ['close']);
    expect(
      service.search(
        collectionId: 'missing',
        queryEmbedding: const [1, 0],
      ),
      isEmpty,
    );
  });

  test('chunkText splits paragraphs and overlaps fixed windows', () {
    final paragraphs = service.chunkText(
      'Alpha paragraph.\n\nBeta paragraph.',
      const ChunkingOptions(strategy: ChunkingStrategy.paragraph),
    );
    expect(paragraphs, ['Alpha paragraph.', 'Beta paragraph.']);

    final windows = service.chunkText(
      'abcdefghij',
      const ChunkingOptions(
        strategy: ChunkingStrategy.fixedSize,
        chunkSize: 4,
        chunkOverlap: 0,
      ),
    );
    expect(windows, ['abcd', 'efgh', 'ij']);

    final overlapped = service.chunkText(
      'abcdefghij',
      const ChunkingOptions(
        strategy: ChunkingStrategy.fixedSize,
        chunkSize: 4,
        chunkOverlap: 1,
      ),
    );
    expect(overlapped, ['abcd', 'defg', 'ghij', 'j']);
  });
}
