import '../../core/constants/entities.dart';
import '../../core/errors/app_exception.dart';
import '../models/customer.dart';
import 'base_repository.dart';

class CustomerRepository extends BaseRepository {
  @override
  String get entity => Entities.customer;

  /// Each row carries what that customer has bought, derived by the server from
  /// their sales.
  Future<List<Customer>> list({String? search, int? limit}) async {
    final response = await api.customers(
      query: {'q': search, 'limit': pageSize(limit)},
    );
    return response.rows.map(Customer.fromJson).toList();
  }

  Future<Customer?> byId(String id) async {
    if (id.isEmpty) return null;
    try {
      final response = await api.customer(id);
      return Customer.fromJson(response.object);
    } on ValidationException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  Future<Customer> save(Customer customer) async {
    final name = customer.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('A customer needs a name.');
    }

    final draft = customer.copyWith(name: name);

    return write(() async {
      final response = draft.id.isEmpty
          ? await api.createCustomer(draft.toRequestBody())
          : await api.updateCustomer(draft.id, draft.toRequestBody());
      return Customer.fromJson(response.object);
    });
  }

  /// A customer with invoices refuses — those sales would lose the name they
  /// were made out to. The server enforces it and says so.
  Future<void> delete(String id) => write(() => api.deleteCustomer(id));
}
