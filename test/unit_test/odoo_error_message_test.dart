import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_event/core/services/error_manager.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

OdooException _odoo(String name, String message) => OdooException({
  'code': 200,
  'message': 'Odoo Server Error',
  'data': {
    'name': name,
    'message': message,
    'debug': 'Traceback ... KeyError: stock.picking ... error',
  },
});

void main() {
  test('a UserError shows the message Odoo wrote, as a server error', () {
    final info = ErrorManager.analyzeError(
      _odoo('odoo.exceptions.UserError', 'You cannot delete a started event.'),
    );
    expect(info.type, ErrorType.server);
    expect(info.message, 'You cannot delete a started event.');
  });

  test('a ValidationError is titled and not read as a missing module', () {
    final info = ErrorManager.analyzeError(
      _odoo('odoo.exceptions.ValidationError', 'End date is before start.'),
    );
    expect(info.type, ErrorType.server);
    expect(info.title, 'Validation Error');
    expect(info.message, 'End date is before start.');
  });

  test('an AccessError keeps Odoo wording under Access Denied', () {
    final info = ErrorManager.analyzeError(
      _odoo('odoo.exceptions.AccessError', 'You are not allowed to read events.'),
    );
    expect(info.type, ErrorType.permission);
    expect(info.message, 'You are not allowed to read events.');
  });

  test('an unclassified Odoo error still surfaces its message', () {
    final info = ErrorManager.analyzeError(
      _odoo('builtins.ZeroDivisionError', 'division by zero'),
    );
    expect(info.type, ErrorType.server);
    expect(info.message, 'division by zero');
  });

  test('a genuine missing model is still reported as a missing module', () {
    final info = ErrorManager.analyzeError(
      _odoo('builtins.KeyError', "'stock.picking'"),
    );
    expect(info.type, ErrorType.moduleNotInstalled);
    expect(info.modelName, 'stock.picking');
  });
}
