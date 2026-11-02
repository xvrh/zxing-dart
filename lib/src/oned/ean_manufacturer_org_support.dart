/// Records EAN prefix to GS1 Member Organization, where the member organization
/// correlates strongly with a country. This is an imperfect means of identifying
/// a country of origin by EAN-13 barcode value. See
/// <a href="http://en.wikipedia.org/wiki/List_of_GS1_country_codes">
/// http://en.wikipedia.org/wiki/List_of_GS1_country_codes</a>.
///
/// @author Sean Owen
class EANManufacturerOrgSupport {
  static const _ranges = [
    _Range([0, 19], 'US/CA'),
    _Range([30, 39], 'US'),
    _Range([60, 139], 'US/CA'),
    _Range([300, 379], 'FR'),
    _Range([380], 'BG'),
    _Range([383], 'SI'),
    _Range([385], 'HR'),
    _Range([387], 'BA'),
    _Range([400, 440], 'DE'),
    _Range([450, 459], 'JP'),
    _Range([460, 469], 'RU'),
    _Range([471], 'TW'),
    _Range([474], 'EE'),
    _Range([475], 'LV'),
    _Range([476], 'AZ'),
    _Range([477], 'LT'),
    _Range([478], 'UZ'),
    _Range([479], 'LK'),
    _Range([480], 'PH'),
    _Range([481], 'BY'),
    _Range([482], 'UA'),
    _Range([484], 'MD'),
    _Range([485], 'AM'),
    _Range([486], 'GE'),
    _Range([487], 'KZ'),
    _Range([489], 'HK'),
    _Range([490, 499], 'JP'),
    _Range([500, 509], 'GB'),
    _Range([520], 'GR'),
    _Range([528], 'LB'),
    _Range([529], 'CY'),
    _Range([531], 'MK'),
    _Range([535], 'MT'),
    _Range([539], 'IE'),
    _Range([540, 549], 'BE/LU'),
    _Range([560], 'PT'),
    _Range([569], 'IS'),
    _Range([570, 579], 'DK'),
    _Range([590], 'PL'),
    _Range([594], 'RO'),
    _Range([599], 'HU'),
    _Range([600, 601], 'ZA'),
    _Range([603], 'GH'),
    _Range([608], 'BH'),
    _Range([609], 'MU'),
    _Range([611], 'MA'),
    _Range([613], 'DZ'),
    _Range([616], 'KE'),
    _Range([618], 'CI'),
    _Range([619], 'TN'),
    _Range([621], 'SY'),
    _Range([622], 'EG'),
    _Range([624], 'LY'),
    _Range([625], 'JO'),
    _Range([626], 'IR'),
    _Range([627], 'KW'),
    _Range([628], 'SA'),
    _Range([629], 'AE'),
    _Range([640, 649], 'FI'),
    _Range([690, 695], 'CN'),
    _Range([700, 709], 'NO'),
    _Range([729], 'IL'),
    _Range([730, 739], 'SE'),
    _Range([740], 'GT'),
    _Range([741], 'SV'),
    _Range([742], 'HN'),
    _Range([743], 'NI'),
    _Range([744], 'CR'),
    _Range([745], 'PA'),
    _Range([746], 'DO'),
    _Range([750], 'MX'),
    _Range([754, 755], 'CA'),
    _Range([759], 'VE'),
    _Range([760, 769], 'CH'),
    _Range([770], 'CO'),
    _Range([773], 'UY'),
    _Range([775], 'PE'),
    _Range([777], 'BO'),
    _Range([779], 'AR'),
    _Range([780], 'CL'),
    _Range([784], 'PY'),
    _Range([785], 'PE'),
    _Range([786], 'EC'),
    _Range([789, 790], 'BR'),
    _Range([800, 839], 'IT'),
    _Range([840, 849], 'ES'),
    _Range([850], 'CU'),
    _Range([858], 'SK'),
    _Range([859], 'CZ'),
    _Range([860], 'YU'),
    _Range([865], 'MN'),
    _Range([867], 'KP'),
    _Range([868, 869], 'TR'),
    _Range([870, 879], 'NL'),
    _Range([880], 'KR'),
    _Range([885], 'TH'),
    _Range([888], 'SG'),
    _Range([890], 'IN'),
    _Range([893], 'VN'),
    _Range([896], 'PK'),
    _Range([899], 'ID'),
    _Range([900, 919], 'AT'),
    _Range([930, 939], 'AU'),
    _Range([940, 949], 'AZ'),
    _Range([955], 'MY'),
    _Range([958], 'MO'),
  ];

  String? lookupCountryIdentifier(String productCode) {
    var prefix = int.parse(productCode.substring(0, 3));
    for (var range in _ranges) {
      var start = range.range[0];
      if (prefix < start) {
        return null;
      }
      var end = range.range.length == 1 ? start : range.range[1];
      if (prefix <= end) {
        return range.countryIdentifier;
      }
    }
    return null;
  }
}

class _Range {
  final List<int> range;
  final String countryIdentifier;

  const _Range(this.range, this.countryIdentifier);
}
