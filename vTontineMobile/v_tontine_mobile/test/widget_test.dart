// Tests unitaires du modèle TontineModel (parsing + helpers de statut).

import 'package:flutter_test/flutter_test.dart';
import 'package:v_tontine_mobile/features/tontines/data/models/tontine_model.dart';

Map<String, dynamic> _baseJson({String statut = 'INCOMPLET', int actuels = 2}) => {
      'id': 1,
      'nom': 'Wend kunni',
      'frequence_valeur': 1,
      'frequence_type': 'MOIS',
      'nbre_participant': 5,
      'nbre_participants_actuels': actuels,
      'montant': '5000.00',
      'statut': statut,
    };

void main() {
  group('TontineModel.fromJson', () {
    test('parse les champs essentiels', () {
      final t = TontineModel.fromJson(_baseJson());
      expect(t.id, 1);
      expect(t.nom, 'Wend kunni');
      expect(t.montant, 5000.0);
      expect(t.nbreParticipant, 5);
    });

    test('statut par défaut = INCOMPLET si absent', () {
      final json = _baseJson()..remove('statut');
      expect(TontineModel.fromJson(json).statut, 'INCOMPLET');
    });
  });

  group('Helpers de statut', () {
    test('libellés lisibles', () {
      expect(TontineModel.fromJson(_baseJson(statut: 'INCOMPLET')).statutLabel, 'Incomplet');
      expect(TontineModel.fromJson(_baseJson(statut: 'COMPLET')).statutLabel, 'Complet');
      expect(TontineModel.fromJson(_baseJson(statut: 'TERMINE')).statutLabel, 'Terminé');
    });

    test('estComplet vrai si statut COMPLET ou places remplies', () {
      expect(TontineModel.fromJson(_baseJson(statut: 'COMPLET', actuels: 2)).estComplet, isTrue);
      expect(TontineModel.fromJson(_baseJson(actuels: 5)).estComplet, isTrue);
      expect(TontineModel.fromJson(_baseJson(actuels: 2)).estComplet, isFalse);
    });

    test('progression = membres / places', () {
      expect(TontineModel.fromJson(_baseJson(actuels: 2)).progression, 0.4);
    });
  });
}
