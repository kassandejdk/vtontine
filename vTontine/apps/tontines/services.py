import calendar
from datetime import timedelta, date
from django.utils import timezone
from django.db import transaction
from django.db.models import Max
from .models import (
    Tontine, Participation, AcceptationRegle,
    InvitationTontine, InvitationLien, DemandeAdhesion, Cycle,
)

DUREE_VALIDITE_INVITATION = timedelta(days=7)


def generer_lien_partage(tontine: Tontine, cree_par) -> InvitationLien:
    """
    Crée un lien d'invitation *générique* et partageable (WhatsApp/SMS...),
    non rattaché à un compte précis : n'importe qui possédant le lien pourra
    rejoindre la tontine indiquée (après avoir accepté les règles).
    Les anciens liens actifs de cette tontine sont désactivés (un seul lien courant).
    """
    InvitationLien.objects.filter(tontine=tontine, est_actif=True).update(est_actif=False)
    return InvitationLien.objects.create(tontine=tontine, cree_par=cree_par)

def inviter_ou_reinviter(tontine: Tontine, invite_par, user) -> InvitationTontine:
    """
    Crée une invitation directe (par téléphone) pour `user`, valable 7 jours.
    Si une invitation existe déjà :
      - en attente → erreur (pas de double invitation)
      - refusée/expirée/acceptée → on la réactive avec un nouveau délai
    """
    invitation, created = InvitationTontine.objects.get_or_create(
        tontine=tontine,
        invite=user,
        defaults={
            'invite_par': invite_par,
            'type': 'DIRECTE',
            'date_expiration': timezone.now() + DUREE_VALIDITE_INVITATION,
        },
    )

    if not created:
        if invitation.statut == 'EN_ATTENTE' and not invitation.est_expiree():
            raise ValueError('Une invitation est déjà en attente pour cet utilisateur')
        invitation.statut = 'EN_ATTENTE'
        invitation.invite_par = invite_par
        invitation.date_expiration = timezone.now() + DUREE_VALIDITE_INVITATION
        invitation.save(update_fields=['statut', 'invite_par', 'date_expiration'])

    return invitation

def _verifier_regles_acceptees(user, tontine, regles_ids: list):
    
    regles_obligatoires = tontine.regles.filter(est_obligatoire=True)
    ids_obligatoires    = set(regles_obligatoires.values_list('id', flat=True))
    ids_envoyes         = set(regles_ids)
    manquantes          = ids_obligatoires - ids_envoyes

    if manquantes:
        titres = list(
            tontine.regles.filter(id__in=manquantes).values_list('titre', flat=True)
        )
        raise ValueError(f"Règles obligatoires non acceptées : {', '.join(titres)}")

    
    for regle_id in ids_envoyes & ids_obligatoires:
        AcceptationRegle.objects.get_or_create(participant=user, regle_id=regle_id)

def _verifier_disponibilite(tontine):

    if tontine.statut == 'TERMINE':
        raise ValueError("Cette tontine est terminée.")
    if tontine.nombre_places_restantes <= 0:
        raise ValueError("Cette tontine est complète.")

def _prochain_ordre_prise(tontine) -> int:
    max_ordre = tontine.participations.filter(
        statut='CONFIRME'
    ).aggregate(Max('ordre_prise'))['ordre_prise__max']
    return (max_ordre or 0) + 1

def _creer_participation(user, tontine) -> Participation:
    participation, created = Participation.objects.get_or_create(
        tontine=tontine,
        participant=user,
        defaults={'statut': 'CONFIRME'}
    )
    if not created:
        if participation.statut in ('EN_ATTENTE', 'CONFIRME'):
            raise ValueError("Vous participez déjà à cette tontine.")
        # Ancien participant exclu réintégré
        participation.statut = 'CONFIRME'
        participation.save(update_fields=['statut'])

    if participation.ordre_prise is None:
        participation.ordre_prise = _prochain_ordre_prise(tontine)
        participation.save(update_fields=['ordre_prise'])

    tontine.recalculer_statut()
    return participation

def infos_invitation(token: str) -> Tontine:
    """
    Résout un jeton d'invitation (directe ou lien de partage) vers sa tontine,
    sans rejoindre — utilisé par le deep link pour prévisualiser l'invitation.
    """
    invitation = InvitationTontine.objects.select_related('tontine').filter(token=token).first()
    if invitation:
        return invitation.tontine

    lien = InvitationLien.objects.select_related('tontine').filter(token=token).first()
    if lien:
        return lien.tontine

    raise ValueError("Lien d'invitation invalide.")


@transaction.atomic
def rejoindre_via_invitation(user, token: str, regles_ids: list) -> Participation:
    """
    Rejoindre une tontine via un jeton, qu'il s'agisse :
      - d'une invitation directe (InvitationTontine, à usage unique pour un user) ;
      - d'un lien de partage générique (InvitationLien, réutilisable).
    """
    invitation_directe = InvitationTontine.objects.select_related('tontine').filter(token=token).first()
    if invitation_directe:
        return _rejoindre_via_invitation_directe(user, invitation_directe, regles_ids)

    lien = InvitationLien.objects.select_related('tontine').filter(token=token).first()
    if lien:
        return _rejoindre_via_lien(user, lien, regles_ids)

    raise ValueError("Lien d'invitation invalide.")


def _rejoindre_via_invitation_directe(user, invitation, regles_ids: list) -> Participation:
    if invitation.statut != 'EN_ATTENTE':
        raise ValueError(f"Cette invitation a déjà été {invitation.get_statut_display().lower()}.")
    if invitation.est_expiree():
        invitation.statut = 'EXPIREE'
        invitation.save(update_fields=['statut'])
        raise ValueError("Ce lien d'invitation a expiré.")

    if invitation.type == 'DIRECTE' and invitation.invite and invitation.invite != user:
        raise ValueError("Cette invitation ne vous est pas destinée.")

    tontine = invitation.tontine
    _verifier_disponibilite(tontine)
    _verifier_regles_acceptees(user, tontine, regles_ids)

    participation = _creer_participation(user, tontine)

    invitation.statut = 'ACCEPTEE'
    invitation.save(update_fields=['statut'])

    return participation


def _rejoindre_via_lien(user, lien, regles_ids: list) -> Participation:
    if not lien.est_valide():
        raise ValueError("Ce lien d'invitation a expiré ou n'est plus actif.")

    tontine = lien.tontine
    _verifier_disponibilite(tontine)
    _verifier_regles_acceptees(user, tontine, regles_ids)

    # Le lien est réutilisable (plusieurs personnes peuvent l'utiliser) : on ne le consomme pas.
    return _creer_participation(user, tontine)


def refuser_invitation(user, token: str) -> InvitationTontine:

    try:
        invitation = InvitationTontine.objects.select_related('tontine').get(token=token)
    except InvitationTontine.DoesNotExist:
        raise ValueError("Lien d'invitation invalide.")

    if invitation.type == 'DIRECTE' and invitation.invite and invitation.invite != user:
        raise ValueError("Cette invitation ne vous est pas destinée.")

    if invitation.statut != 'EN_ATTENTE':
        raise ValueError(f"Cette invitation a déjà été {invitation.get_statut_display().lower()}.")

    invitation.statut = 'REFUSEE'
    invitation.save(update_fields=['statut'])

    return invitation

@transaction.atomic
def soumettre_demande_adhesion(user, tontine: Tontine, message: str, regles_ids: list) -> DemandeAdhesion:
    
    if not tontine.visibilite:
        raise ValueError("Cette tontine n'est pas publique.")

    _verifier_disponibilite(tontine)

    if Participation.objects.filter(
        tontine=tontine, participant=user, statut__in=['EN_ATTENTE', 'CONFIRME']
    ).exists():
        raise ValueError("Vous participez déjà à cette tontine.")

    if DemandeAdhesion.objects.filter(tontine=tontine, demandeur=user, statut='EN_ATTENTE').exists():
        raise ValueError("Vous avez déjà une demande en attente pour cette tontine.")

    # On pré-enregistre les acceptations de règles dès la demande
    _verifier_regles_acceptees(user, tontine, regles_ids)

    demande = DemandeAdhesion.objects.create(
        tontine=tontine,
        demandeur=user,
        message=message
    )

    # Notifier le créateur de la nouvelle demande
    from apps.notifications.models import Notification
    Notification.objects.create(
        user=tontine.createur,
        titre="Nouvelle demande d'adhésion",
        message=(
            f'{user.prenom} {user.nom} souhaite rejoindre la tontine "{tontine.nom}".'
        ),
        tontine=tontine,
    )

    return demande

@transaction.atomic
def traiter_demande_adhesion(createur, demande: DemandeAdhesion, accepter: bool) -> DemandeAdhesion:
    
    if demande.tontine.createur != createur:
        raise ValueError("Seul le créateur peut traiter les demandes.")
    if demande.statut != 'EN_ATTENTE':
        raise ValueError("Cette demande a déjà été traitée.")

    demande.statut      = 'ACCEPTEE' if accepter else 'REFUSEE'
    demande.traite_par  = createur
    demande.date_traitement = timezone.now()
    demande.save(update_fields=['statut', 'traite_par', 'date_traitement'])

    if accepter:
        # Le demandeur a pu rejoindre par un autre biais (invitation) pendant
        # que sa demande restait en attente : dans ce cas on se contente
        # d'acter la demande, sans tenter de recréer une participation.
        deja_membre = Participation.objects.filter(
            tontine=demande.tontine, participant=demande.demandeur, statut='CONFIRME'
        ).exists()
        if not deja_membre:
            _verifier_disponibilite(demande.tontine)
            _creer_participation(demande.demandeur, demande.tontine)

    return demande


# ─── Cycles (tours) ──────────────────────────────────────────────────────────

def _ajouter_periode(depart: date, frequence_type: str, valeur: int, n: int) -> date:
    """Retourne `depart` décalé de n périodes (n*valeur unités de frequence_type)."""
    pas = valeur * n
    if frequence_type == 'JOUR':
        return depart + timedelta(days=pas)
    if frequence_type == 'SEMAINE':
        return depart + timedelta(weeks=pas)
    # MOIS : arithmétique calendaire avec bornage du jour (28/30/31).
    total = depart.month - 1 + pas
    annee = depart.year + total // 12
    mois = total % 12 + 1
    jour = min(depart.day, calendar.monthrange(annee, mois)[1])
    return date(annee, mois, jour)


def _statut_pour_dates(cycle_debut, cycle_fin, aujourdhui) -> str:
    """Déduit A_VENIR / EN_COURS / CLOTURE d'un cycle à partir de ses dates."""
    if not cycle_debut:
        return 'A_VENIR'
    if aujourdhui < cycle_debut:
        return 'A_VENIR'
    if cycle_fin and aujourdhui > cycle_fin:
        return 'CLOTURE'
    return 'EN_COURS'


@transaction.atomic
def generer_cycles(tontine: Tontine) -> list:
    """
    Crée/rafraîchit les cycles d'une tontine (idempotent).

    - Un cycle par tour : numéros 1..nbre_participant.
    - Dates calculées depuis `date_debut` + fréquence (si `date_debut` est défini).
    - Bénéficiaire = la participation dont `ordre_prise == numero`.
    - Le statut A_VENIR/EN_COURS/CLOTURE suit les dates ; un cycle dont la prise
      est déjà versée reste CLOTURE.
    """
    total = tontine.nbre_participant or 0
    aujourdhui = timezone.localdate()

    # Bénéficiaires indexés par ordre_prise (membres confirmés).
    par_ordre = {
        p.ordre_prise: p
        for p in tontine.participations.filter(statut='CONFIRME')
        if p.ordre_prise
    }

    cycles = []
    for numero in range(1, total + 1):
        if tontine.date_debut:
            debut = _ajouter_periode(tontine.date_debut, tontine.frequence_type,
                                     tontine.frequence_valeur, numero - 1)
            prochain = _ajouter_periode(tontine.date_debut, tontine.frequence_type,
                                        tontine.frequence_valeur, numero)
            fin = prochain - timedelta(days=1)
        else:
            debut = fin = None

        cycle, _ = Cycle.objects.get_or_create(tontine=tontine, numero=numero)
        cycle.date_debut = debut
        cycle.date_fin = fin
        cycle.beneficiaire = par_ordre.get(numero)
        if not cycle.prise_versee:
            cycle.statut = _statut_pour_dates(debut, fin, aujourdhui)
        cycle.save()
        cycles.append(cycle)

    return cycles


def cycle_courant(tontine: Tontine):
    """
    Le cycle « en cours » : celui dont l'intervalle de dates contient aujourd'hui.
    À défaut de dates, le premier cycle non clôturé. Renvoie None si aucun cycle.
    """
    cycles = list(tontine.cycles.order_by('numero'))
    if not cycles:
        return None
    aujourdhui = timezone.localdate()
    for c in cycles:
        if c.date_debut and c.date_fin and c.date_debut <= aujourdhui <= c.date_fin:
            return c
    for c in cycles:
        if c.statut != 'CLOTURE':
            return c
    return cycles[-1]


def cycles_non_soldes(tontine: Tontine) -> list:
    """
    Cycles ayant un bénéficiaire dont la prise n'a pas encore été versée.

    Tant que cette liste n'est pas vide, la tontine ne peut pas être terminée :
    c'est le garde-fou qui empêche le créateur de clôturer avant d'avoir remis
    sa prise à chaque bénéficiaire.
    """
    return list(
        tontine.cycles.filter(beneficiaire__isnull=False, prise_versee=False)
        .select_related('beneficiaire', 'beneficiaire__participant')
        .order_by('numero')
    )