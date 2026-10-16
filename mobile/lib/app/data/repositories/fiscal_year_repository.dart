import '../../core/constants/entities.dart';
import '../../core/errors/app_exception.dart';
import '../models/fiscal_year.dart';
import 'base_repository.dart';

class FiscalYearRepository extends BaseRepository {
  @override
  String get entity => Entities.fiscalYear;

  Future<List<FiscalYear>> list() async {
    final response = await api.fiscalYears();
    return response.rows.map(FiscalYear.fromJson).toList();
  }

  Future<FiscalYear?> active() async {
    try {
      final response = await api.activeFiscalYear();
      return FiscalYear.fromJson(response.object);
    } on ValidationException catch (e) {
      // A shop that has not set up its first year yet is a normal state, not an
      // error worth showing: the forms already say what to do about it.
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// The year a document dated [dateMs] belongs to.
  ///
  /// Falls back to the active year when none covers the date, so a form is
  /// never blocked — but the caller should say which it used, because filing a
  /// bill under a year that does not contain its own date is how a record ends
  /// up somewhere nobody thinks to look.
  ///
  /// Answered from the full list rather than by an endpoint of its own: there
  /// are a handful of years in a shop's life, and one round trip that also
  /// covers "is there an active one" beats two.
  Future<FiscalYear?> forDate(int dateMs) async {
    final years = await list();
    for (final year in years) {
      if (year.containsMs(dateMs)) return year;
    }
    for (final year in years) {
      if (year.isActive) return year;
    }
    return null;
  }

  /// Creates or updates a year. Pass an empty [FiscalYear.id] to create.
  ///
  /// Marking one active is part of the same request rather than a second call:
  /// the server clears the flag on the others in the same transaction, so there
  /// is never a moment with two active years or none.
  Future<FiscalYear> save(FiscalYear year) async {
    final name = year.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('A fiscal year needs a name.');
    }
    if (year.endDate <= year.startDate) {
      throw const ValidationException('The year has to end after it starts.');
    }

    final body = year.copyWith(name: name).toRequestBody();

    return write(() async {
      final response = year.id.isEmpty
          ? await api.createFiscalYear(body)
          : await api.updateFiscalYear(year.id, body);
      return FiscalYear.fromJson(response.object);
    });
  }

  /// Makes [id] the year new records are filed under.
  Future<FiscalYear> activate(String id) => write(() async {
        final response = await api.activateFiscalYear(id);
        return FiscalYear.fromJson(response.object);
      });

  /// A year with anything filed under it refuses, and the server says so in
  /// words worth repeating — so the message is passed through rather than
  /// replaced with a generic one.
  Future<void> delete(String id) => write(() => api.deleteFiscalYear(id));
}
