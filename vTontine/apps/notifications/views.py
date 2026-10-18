from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from .models import Notification
from .serializers import NotificationSerializer


class NotificationListView(APIView):
    """
    GET /api/notifications/
    Liste les notifications de l'utilisateur connecté.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        notifications = Notification.objects.filter(user=request.user)
        serializer = NotificationSerializer(notifications, many=True)
        return Response(serializer.data)


class NotificationMarquerLuView(APIView):
    """
    POST /api/notifications/<notification_id>/lu/
    Marque une notification comme lue.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, notification_id):
        notification = get_object_or_404(
            Notification, id=notification_id, user=request.user
        )
        notification.est_lu = True
        notification.save()
        return Response(NotificationSerializer(notification).data)


class NotificationMarquerToutLuView(APIView):
    """
    POST /api/notifications/marquer-tout-lu/
    Marque toutes les notifications de l'utilisateur connecté comme lues.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        Notification.objects.filter(user=request.user, est_lu=False).update(est_lu=True)
        return Response(status=status.HTTP_204_NO_CONTENT)
