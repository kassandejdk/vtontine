from django.urls import path
from .views import (
    TontineListCreateView,
    TontineDetailView,
    TontineParticipantsView,
    ExclureParticipantView,
    OrdrePriseView,
    TerminerTontineView,
    DecouvrirTontinesView,
    MesTontinesView,
    RejoindreViaInvitationView,
    RefuserInvitationView,
    DemandeAdhesionView,
    TraiterDemandeAdhesionView,
    GenererLienInvitationView,
    RechercherUserParTelephoneView,
    InviterParTelephoneView,
    RegleListCreateView,
    RegleDetailView,
    InvitationsRecuesView,
    QuitterTontineView,
    MessagesTontineView,
    MethodePaiementListCreateView,
    MethodePaiementDetailView,
    CyclesRegistreView,
    VerserPriseView,
)


urlpatterns = [
    path('', TontineListCreateView.as_view(), name='tontine-list-create'),
    path('mes-tontines/', MesTontinesView.as_view(), name='mes-tontines'),
    path('decouvrir/', DecouvrirTontinesView.as_view(), name='decouvrir-tontines'),
    # Routes statiques avant les routes <int:tontine_id> pour éviter les collisions
    path('invitations/', InvitationsRecuesView.as_view(), name='invitations-recues'),
    path('demandes/<int:demande_id>/traiter/', TraiterDemandeAdhesionView.as_view(), name='traiter-demande'),
    path('rejoindre/<uuid:token>/', RejoindreViaInvitationView.as_view(), name='rejoindre-invitation'),
    path('rejoindre/<uuid:token>/refuser/', RefuserInvitationView.as_view(), name='refuser-invitation'),

    path('<int:tontine_id>/', TontineDetailView.as_view(), name='tontine-detail'),
    path('<int:tontine_id>/terminer/', TerminerTontineView.as_view(), name='terminer-tontine'),
    path('<int:tontine_id>/quitter/', QuitterTontineView.as_view(), name='quitter-tontine'),
    path('<int:tontine_id>/participants/', TontineParticipantsView.as_view(), name='tontine-participants'),
    path('<int:tontine_id>/participants/<int:participation_id>/exclure/', ExclureParticipantView.as_view(), name='exclure-participant'),
    path('<int:tontine_id>/participants/<int:participation_id>/ordre/', OrdrePriseView.as_view(), name='ordre-prise'),
    path('<int:tontine_id>/demandes/', DemandeAdhesionView.as_view(), name='demandes-adhesion'),

    path('<int:tontine_id>/regles/', RegleListCreateView.as_view(), name='regle-list-create'),
    path('<int:tontine_id>/regles/<int:regle_id>/', RegleDetailView.as_view(), name='regle-detail'),

    path('<int:tontine_id>/messages/', MessagesTontineView.as_view(), name='messages-tontine'),

    path('<int:tontine_id>/methodes-paiement/', MethodePaiementListCreateView.as_view(), name='methodes-paiement'),
    path('<int:tontine_id>/methodes-paiement/<int:methode_id>/', MethodePaiementDetailView.as_view(), name='methode-paiement-detail'),

    path('<int:tontine_id>/cycles/', CyclesRegistreView.as_view(), name='cycles-registre'),
    path('<int:tontine_id>/cycles/<int:numero>/verser-prise/', VerserPriseView.as_view(), name='verser-prise'),

    path('<int:tontine_id>/invitations/lien/', GenererLienInvitationView.as_view(), name='invitation-lien'),
    path('<int:tontine_id>/invitations/rechercher/', RechercherUserParTelephoneView.as_view(), name='invitation-rechercher'),
    path('<int:tontine_id>/invitations/telephone/', InviterParTelephoneView.as_view(), name='invitation-telephone'),
]