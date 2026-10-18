"""
Middleware optionnel Keycloak.
"""
class KeycloakMiddleware:
   
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Code exécuté AVANT la vue
        response = self.get_response(request)
        # Code exécuté APRÈS la vue
        return response
    