enum TempUnit { c, f }

enum WindUnit { kmh, mph, ms }

class Units {
  final TempUnit temp;
  final WindUnit wind;
  const Units(this.temp, this.wind);

  bool get imperial => temp == TempUnit.f;

  double t(double c) => temp == TempUnit.c ? c : c * 9 / 5 + 32;
  String deg(double c) => '${t(c).round()}°';
  String degU(double c) => '${t(c).round()}°${temp == TempUnit.c ? 'C' : 'F'}';

  String speed(double kmh) {
    switch (wind) {
      case WindUnit.kmh:
        return '${kmh.round()} km/h';
      case WindUnit.mph:
        return '${(kmh * 0.621371).round()} mph';
      case WindUnit.ms:
        return '${(kmh / 3.6).toStringAsFixed(1)} m/s';
    }
  }

  double speedValue(double kmh) => switch (wind) {
        WindUnit.kmh => kmh,
        WindUnit.mph => kmh * 0.621371,
        WindUnit.ms => kmh / 3.6,
      };

  String get speedUnit => switch (wind) {
        WindUnit.kmh => 'km/h',
        WindUnit.mph => 'mph',
        WindUnit.ms => 'm/s',
      };

  String precipShort(double mm) => imperial
      ? (mm / 25.4 < 0.01 ? '<0.01"' : '${(mm / 25.4).toStringAsFixed(2)}"')
      : (mm < 0.1 ? '<0.1' : mm.toStringAsFixed(1));

  String precip(double mm) =>
      imperial ? '${(mm / 25.4).toStringAsFixed(2)} in' : '${mm.toStringAsFixed(1)} mm';

  String distance(double meters) {
    if (imperial) {
      final mi = meters / 1609.34;
      return mi >= 10 ? '${mi.round()} mi' : '${mi.toStringAsFixed(1)} mi';
    }
    final km = meters / 1000;
    return km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
  }

  String pressure(double hpa) =>
      imperial ? '${(hpa * 0.02953).toStringAsFixed(2)} inHg' : '${hpa.round()} hPa';
}

String compass(int deg) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[((deg % 360) / 45).round() % 8];
}

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String weekday(DateTime d) => _wd[d.weekday - 1];

String hourLabel(DateTime t, {bool h24 = false}) {
  if (h24) return '${t.hour.toString().padLeft(2, '0')}:00';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h ${t.hour < 12 ? 'AM' : 'PM'}';
}

String clock(DateTime t, {bool h24 = false}) {
  final m = t.minute.toString().padLeft(2, '0');
  if (h24) return '${t.hour.toString().padLeft(2, '0')}:$m';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String shortDate(DateTime d) => '${weekday(d)}, ${_mo[d.month - 1]} ${d.day}';

const _wdLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
String longWeekday(DateTime d) => _wdLong[d.weekday - 1];
