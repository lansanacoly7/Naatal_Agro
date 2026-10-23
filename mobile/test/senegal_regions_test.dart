import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/location/senegal_regions.dart';

void main() {
  test('Le Sénégal compte 14 régions', () {
    expect(SenegalRegions.all.length, 14);
  });

  test('La région la plus proche d\'une position est son chef-lieu', () {
    expect(SenegalRegions.nearest(14.74, -17.45).name, 'Dakar');
    expect(SenegalRegions.nearest(14.80, -16.92).name, 'Thiès');
    expect(SenegalRegions.nearest(16.03, -16.50).name, 'Saint-Louis');
    expect(SenegalRegions.nearest(12.58, -16.27).name, 'Ziguinchor');
    expect(SenegalRegions.nearest(13.77, -13.67).name, 'Tambacounda');
  });

  test('Le nom donné par le système est reconnu malgré les accents et les suffixes', () {
    expect(SenegalRegions.fromName('Thiès Region')?.name, 'Thiès');
    expect(SenegalRegions.fromName('DAKAR')?.name, 'Dakar');
    expect(SenegalRegions.fromName('Kédougou')?.name, 'Kédougou');
    expect(SenegalRegions.fromName('Paris'), isNull);
  });

  test('Une fiche est mise en avant seulement si ses zones citent la région', () {
    final dakar = SenegalRegions.fromName('Dakar')!;
    final kolda = SenegalRegions.fromName('Kolda')!;
    expect(SenegalRegions.zonesMention(dakar, 'Niayes. [1]'), isTrue);
    expect(SenegalRegions.zonesMention(kolda, 'Niayes. [1]'), isFalse);
    expect(SenegalRegions.zonesMention(kolda, 'Sénégal-Oriental, Sine-Saloum et Casamance (culture pluviale)'), isTrue);
    expect(SenegalRegions.zonesMention(dakar, ''), isFalse, reason: 'zone non documentée : jamais devinée');
  });
}
