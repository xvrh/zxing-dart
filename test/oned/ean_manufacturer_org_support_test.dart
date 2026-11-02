import 'package:test/test.dart';
import 'package:zxing2/src/oned/ean_manufacturer_org_support.dart';

/// Tests {@link EANManufacturerOrgSupport}.
///
/// @author Sean Owen
void main() {
  test('Lookup', () {
    var support = EANManufacturerOrgSupport();
    expect(support.lookupCountryIdentifier('472000'), isNull);
    expect(support.lookupCountryIdentifier('000000'), 'US/CA');
    expect(support.lookupCountryIdentifier('958000'), 'MO');
    expect(support.lookupCountryIdentifier('500000'), 'GB');
    expect(support.lookupCountryIdentifier('509000'), 'GB');
  });
}
