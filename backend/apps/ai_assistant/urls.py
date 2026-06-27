from django.urls import path
from .views import AskAIView

app_name = 'ai_assistant'

urlpatterns = [
    path('ask/', AskAIView.as_view(), name='ask_ai'),
]
