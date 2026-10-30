from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AgronomicGuideViewSet, CropCalendarView, CropViewSet, ActivityViewSet, PestReportViewSet

router = DefaultRouter()
router.register(r'crops', CropViewSet, basename='crop')
router.register(r'activities', ActivityViewSet, basename='activity')
router.register(r'pest-reports', PestReportViewSet, basename='pest-report')
router.register(r'guides', AgronomicGuideViewSet, basename='guide')

app_name = 'agriculture'

urlpatterns = [
    path('calendar/', CropCalendarView.as_view(), name='crop-calendar'),
    path('', include(router.urls)),
]
