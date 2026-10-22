from django.db import migrations

from apps.finances.categories import infer_activity_category, infer_expense_category


def reclassify_other(apps, schema_editor):
    """La règle de classement a été enrichie (travaux agricoles) : les dépenses restées en « autre » sont réévaluées.
    Seules les lignes encore en « autre » sont touchées, et seulement si la règle leur trouve désormais une catégorie."""
    Transaction = apps.get_model('finances', 'Transaction')
    Activity = apps.get_model('agriculture', 'Activity')
    for tx in Transaction.objects.filter(transaction_type='expense', category='autre'):
        activity = Activity.objects.filter(pk=tx.activity_id).first() if tx.activity_id else None
        if activity:
            category = infer_activity_category(activity.activity_type, activity.description)
        else:
            category = infer_expense_category(tx.description)
        if category != 'autre':
            Transaction.objects.filter(pk=tx.pk).update(category=category)


class Migration(migrations.Migration):

    dependencies = [
        ('finances', '0007_main_oeuvre_label'),
        ('agriculture', '0010_alter_activity_description'),
    ]

    operations = [
        migrations.RunPython(reclassify_other, migrations.RunPython.noop),
    ]
