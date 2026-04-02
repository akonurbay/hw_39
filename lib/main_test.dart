// filepath: /Users/konarsj/development/hw_39/lib/main_test.dart
// Расширённые тесты для hw_39 — mapper (доп. кейсы), AddNoteUseCase с мок-репозиторием (spy, null-пэйлоад), обработка ошибок, widget-test для main.dart
// Coverage: run `flutter test --coverage` and generate lcov via `genhtml coverage/lcov.info -o coverage/html`

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hw_39/main.dart' as app;

// --- Fixtures ---
final Map<String, Map<String, dynamic>> fixtures = {
  'full': {'id': '1', 'title': 'Shopping', 'content': 'Buy milk and bread'},
  'no_content': {'id': '2', 'title': 'Todo', 'content': null},
  'empty_title': {'id': '3', 'title': '', 'content': 'Some content'},
  'weird_id': {'id': '000-xyz', 'title': 'Weird', 'content': 'Weird id note'},
  'long_text': {
    'id': '5',
    'title': 'Long',
    'content': List.filled(500, 'A').join(), // long content (500 chars)
  },
  // additional fixtures
  'huge_text': {
    'id': '6',
    'title': 'Huge',
    'content': List.filled(1000, 'H').join(), // 1000 chars
  },
  'null_id': {'id': null, 'title': 'NoId', 'content': 'no id here'},
  'whitespace_title': {'id': '7', 'title': '   ', 'content': 'ws'},
  'padded_title': {'id': '8', 'title': '  Hello  ', 'content': ' spaced '},
  'unicode_content': {'id': '9', 'title': 'Emoji', 'content': '✅ 🚀 Привет'},
  'numeric_id': {
    'id': 123, // will be converted to "123"
    'title': 'Num',
    'content': 'numeric id',
  },
};

// --- Local test models and utilities (kept in test to be explicit) ---
class NoteDTO {
  final String? id;
  final String? title;
  final String? content;

  NoteDTO({this.id, this.title, this.content});

  factory NoteDTO.fromMap(Map<String, dynamic> map) {
    return NoteDTO(
      id: map['id']?.toString(),
      title: map['title'] as String?,
      content: map['content'] as String?,
    );
  }
}

class Note {
  final String id;
  final String title;
  final String content;

  Note({required this.id, required this.title, required this.content});

  @override
  bool operator ==(Object other) {
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content;
  }

  @override
  int get hashCode => Object.hash(id, title, content);

  @override
  String toString() =>
      'Note(id: $id, title: $title, content: ${content.length} chars)';
}

Note noteDtoToDomain(NoteDTO dto) {
  // Normalization rules:
  // - id -> if null use empty string
  // - title -> if null or empty (after trim) -> 'Untitled'
  // - content -> if null -> ''
  final id = dto.id ?? '';
  final title = (dto.title == null || dto.title!.trim().isEmpty)
      ? 'Untitled'
      : dto.title!.trim();
  final content = dto.content ?? '';
  return Note(id: id, title: title, content: content);
}

// Simple Result wrapper for tests
class Result<T> {
  final T? value;
  final String? message;
  final bool isSuccess;

  Result.success(this.value) : isSuccess = true, message = null;

  Result.failure(this.message) : isSuccess = false, value = null;
}

// Repository interface
abstract class NoteRepository {
  Future<Result<Note>> add(Note note);
}

// Mock repository with configurable behavior
class MockNoteRepository implements NoteRepository {
  final Future<Result<Note>> Function(Note note) handler;
  MockNoteRepository(this.handler);

  @override
  Future<Result<Note>> add(Note note) => handler(note);
}

// Spy mock to assert call count and last argument
class SpyNoteRepository implements NoteRepository {
  final Future<Result<Note>> Function(Note note) handler;
  int callCount = 0;
  Note? lastNote;

  SpyNoteRepository(this.handler);

  @override
  Future<Result<Note>> add(Note note) {
    callCount += 1;
    lastNote = note;
    return handler(note);
  }
}

// Use case
class AddNoteUseCase {
  final NoteRepository repository;
  AddNoteUseCase(this.repository);

  Future<Result<Note>> call(Note note) async {
    try {
      return await repository.add(note);
    } catch (e) {
      return Result.failure('unexpected error: ${e.toString()}');
    }
  }
}

void main() {
  group('Mapper DTO -> Domain (base cases)', () {
    test('maps full DTO correctly', () {
      final dto = NoteDTO.fromMap(fixtures['full']!);
      final note = noteDtoToDomain(dto);
      expect(
        note,
        Note(id: '1', title: 'Shopping', content: 'Buy milk and bread'),
      );
    });

    test('handles null content as empty string', () {
      final dto = NoteDTO.fromMap(fixtures['no_content']!);
      final note = noteDtoToDomain(dto);
      expect(note, Note(id: '2', title: 'Todo', content: ''));
    });

    test('handles empty title and normalizes to Untitled', () {
      final dto = NoteDTO.fromMap(fixtures['empty_title']!);
      final note = noteDtoToDomain(dto);
      expect(note, Note(id: '3', title: 'Untitled', content: 'Some content'));
    });

    test('preserves weird id values', () {
      final dto = NoteDTO.fromMap(fixtures['weird_id']!);
      final note = noteDtoToDomain(dto);
      expect(
        note,
        Note(id: '000-xyz', title: 'Weird', content: 'Weird id note'),
      );
    });

    test('handles long content (500 chars)', () {
      final dto = NoteDTO.fromMap(fixtures['long_text']!);
      final note = noteDtoToDomain(dto);
      expect(note.id, '5');
      expect(note.title, 'Long');
      expect(note.content.length, 500);
    });
  });

  group('Mapper DTO -> Domain (extra cases)', () {
    test('null id becomes empty string', () {
      final dto = NoteDTO.fromMap(fixtures['null_id']!);
      final note = noteDtoToDomain(dto);
      expect(note.id, '');
      expect(note.title, 'NoId');
      expect(note.content, 'no id here');
    });

    test('whitespace-only title normalizes to Untitled', () {
      final dto = NoteDTO.fromMap(fixtures['whitespace_title']!);
      final note = noteDtoToDomain(dto);
      expect(note.title, 'Untitled');
    });

    test('padded title is trimmed', () {
      final dto = NoteDTO.fromMap(fixtures['padded_title']!);
      final note = noteDtoToDomain(dto);
      expect(note.title, 'Hello');
      expect(note.content, ' spaced ');
    });

    test('unicode content is preserved', () {
      final dto = NoteDTO.fromMap(fixtures['unicode_content']!);
      final note = noteDtoToDomain(dto);
      expect(note.content, '✅ 🚀 Привет');
    });

    test('numeric id is converted to string', () {
      final dto = NoteDTO.fromMap(fixtures['numeric_id']!);
      final note = noteDtoToDomain(dto);
      expect(note.id, '123');
      expect(note.title, 'Num');
    });

    test('huge content length (1000 chars) handled', () {
      final dto = NoteDTO.fromMap(fixtures['huge_text']!);
      final note = noteDtoToDomain(dto);
      expect(note.content.length, 1000);
    });
  });

  group('AddNoteUseCase with MockNoteRepository (base cases)', () {
    test('returns success when repository returns success', () async {
      final note = Note(id: '10', title: 'X', content: 'x');
      final mock = MockNoteRepository((n) async {
        expect(n, note); // ensure note forwarded
        return Result.success(n);
      });

      final useCase = AddNoteUseCase(mock);
      final res = await useCase.call(note);
      expect(res.isSuccess, true);
      expect(res.value, note);
    });

    test('returns failure when repository returns failure', () async {
      final note = Note(id: '11', title: 'Err', content: 'err');
      final mock = MockNoteRepository((n) async {
        return Result.failure('db write failed');
      });

      final useCase = AddNoteUseCase(mock);
      final res = await useCase.call(note);
      expect(res.isSuccess, false);
      expect(res.message, 'db write failed');
    });

    test('handles repository throwing exception and wraps message', () async {
      final note = Note(id: '12', title: 'Throw', content: 'boom');
      final mock = MockNoteRepository((n) async {
        throw Exception('connection lost');
      });

      final useCase = AddNoteUseCase(mock);
      final res = await useCase.call(note);
      expect(res.isSuccess, false);
      expect(res.message, contains('connection lost'));
    });
  });

  group('AddNoteUseCase with SpyNoteRepository (extra cases)', () {
    test('repository add called exactly once and with correct arg', () async {
      final note = Note(id: '20', title: 'Spy', content: 'spy');
      final spy = SpyNoteRepository((n) async => Result.success(n));
      final useCase = AddNoteUseCase(spy);

      final res = await useCase.call(note);
      expect(res.isSuccess, true);
      expect(spy.callCount, 1);
      expect(spy.lastNote, note);
    });

    test(
      'repository returns success with null payload (allowed) -> propagate success with null',
      () async {
        final note = Note(id: '21', title: 'NullPayload', content: 'np');
        final mock = MockNoteRepository((n) async {
          return Result.success(null); // weird but possible
        });

        final useCase = AddNoteUseCase(mock);
        final res = await useCase.call(note);
        expect(res.isSuccess, true);
        expect(res.value, isNull);
      },
    );

    test(
      'delayed repository response still returns expected success',
      () async {
        final note = Note(id: '22', title: 'Delayed', content: 'd');
        final mock = MockNoteRepository((n) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return Result.success(n);
        });

        final useCase = AddNoteUseCase(mock);
        final res = await useCase.call(note);
        expect(res.isSuccess, true);
        expect(res.value, note);
      },
    );

    test('repository failure message is exact and asserted', () async {
      final note = Note(id: '23', title: 'FailMsg', content: 'fm');
      final mock = MockNoteRepository((n) async {
        return Result.failure('explicit failure reason');
      });

      final useCase = AddNoteUseCase(mock);
      final res = await useCase.call(note);
      expect(res.isSuccess, false);
      expect(res.message, 'explicit failure reason');
    });
  });

  // Widget test to cover lib/main.dart
  testWidgets('MainApp shows Hello World', (WidgetTester tester) async {
    await tester.pumpWidget(const app.MainApp());
    expect(find.text('Hello World!'), findsOneWidget);
  });
}
