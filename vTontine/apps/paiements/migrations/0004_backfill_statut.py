from django.db import migrations


def backfill_statut(apps, schema_editor):
    Paiement = apps.get_model('paiements', 'Paiement')
    Paiement.objects.filter(est_confirmer=True).update(statut='CONFIRME')
    Paiement.objects.filter(est_confirmer=False).update(statut='EN_ATTENTE')


def reverse_noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('paiements', '0003_alter_paiement_options_paiement_statut'),
    ]

    operations = [
        migrations.RunPython(backfill_statut, reverse_noop),
    ]
