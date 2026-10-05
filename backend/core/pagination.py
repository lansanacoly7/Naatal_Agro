from rest_framework.pagination import PageNumberPagination


class OptionalPageNumberPagination(PageNumberPagination):
    """
    Pagination à la demande, compatible avec les clients existants.

    - Sans paramètre ``page`` ni ``page_size`` : la liste complète est renvoyée sous forme de
      tableau JSON, comme avant (aucune régression pour l'application mobile actuelle).
    - Avec ``?page=2`` et/ou ``?page_size=20`` : réponse paginée
      ``{"count", "next", "previous", "results"}``.

    Quand tous les écrans de liste du mobile enverront ``page``, cette classe pourra être
    remplacée par une pagination obligatoire (exigée par docs/06-Backend-API.md).
    """

    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

    def paginate_queryset(self, queryset, request, view=None):
        if self.page_query_param not in request.query_params and \
                self.page_size_query_param not in request.query_params:
            return None
        return super().paginate_queryset(queryset, request, view)
