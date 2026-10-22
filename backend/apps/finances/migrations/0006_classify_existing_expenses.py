from django.db import migrations

from apps.finances.categories import infer_expense_category


def classify_existing_expenses(apps, schema_editor):
    """Classe les dépenses déjà enregistrées (même règle déterministe que pour les nouvelles) et relie
    à leur culture celles issues d'une activité de culture."""
    Transaction = apps.get_model('finances', 'Transaction')
    for tx in Transaction.objects.filter(transaction_type='expense', category='').select_related('activity'):
        updates = {'category': infer_expense_category(tx.description)}
        if tx.activity_id and tx.crop_id is None:
            updates['crop_id'] = tx.activity.crop_id
        Transaction.objects.filter(pk=tx.pk).update(**updates)


class Migration(migrations.Migration):

    dependencies = [
        ('finances', '0005_phase2_data_model'),
        ('agriculture', '0010_alter_activity_description'),
    ]

    operations = [
        # Rien à défaire : la colonne n'existe plus si l'on revient à 0004.
        migrations.RunPython(classify_existing_expenses, migrations.RunPython.noop),
    ]
