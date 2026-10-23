from django.urls import path
from .views import (
    AskAIView,
    AIConversationListView,
    AIConversationDetailView,
    ExecuteAIActionView,
    AnalyticsAIView,
    TranscribeAudioView,
)

app_name = 'ai_assistant'

urlpatterns = [
    path('ask/', AskAIView.as_view(), name='ask_ai'),
    path('conversations/', AIConversationListView.as_view(), name='conversation_list'),
    path('conversations/<str:conversation_id>/', AIConversationDetailView.as_view(), name='conversation_detail'),
    path('actions/execute/', ExecuteAIActionView.as_view(), name='execute_action'),
    path('analytics/', AnalyticsAIView.as_view(), name='ai_analytics'),
    path('voice/transcribe/', TranscribeAudioView.as_view(), name='voice_transcribe'),
]
