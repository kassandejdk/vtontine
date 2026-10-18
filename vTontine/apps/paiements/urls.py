from django.urls import path
from .views import (
    PaiementListCreateView,
    PaiementDetailView,
    PaiementConfirmerView,
    PaiementRefuserView,
)

urlpatterns = [
    path('', PaiementListCreateView.as_view(), name='paiement-list-create'),
    path('<int:paiement_id>/', PaiementDetailView.as_view(), name='paiement-detail'),
    path('<int:paiement_id>/confirmer/', PaiementConfirmerView.as_view(), name='paiement-confirmer'),
    path('<int:paiement_id>/refuser/', PaiementRefuserView.as_view(), name='paiement-refuser'),
]
