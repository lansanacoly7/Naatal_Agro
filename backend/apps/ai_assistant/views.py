import datetime
import uuid

from django.utils import timezone
from rest_framework import views, permissions, status
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.response import Response
from .models import AIConversation, AIInteraction
from .serializers import (
    AIInteractionSerializer,
    AIConversationListSerializer,
    AIConversationDetailSerializer
)
from .services import answer_question
from .actions import (
    detect_action_intent,
    classify_reply,
    analyze_farmer_finances,
    analyze_farmer_inventory
)
from . import dialogue, proposals
from .language import detect as detect_language
from .visuals import visual_for
from .queries import answer_query, detect_query_intent
from .analysis_answers import answer_analysis, detect_analysis_intent, memory_of, resolve_followup
from .proposals import ProposalNotFound, ProposalUnavailable, resolve_proposal

MAX_QUERY_LENGTH = 1000
MAX_IMAGE_BASE64_LENGTH = 7_000_000  # ~5 Mo d'image
MAX_HISTORY_TURNS = 24
CONVERSATION_WINDOW = datetime.timedelta(hours=6)  # sans historique envoyé, on reprend la conversation récente


def clean_history(raw):
    """Valide l'historique envoyé par l'application ; renvoie None s'il est absent ou invalide."""
    if not isinstance(raw, list):
        return None
    turns = []
    for item in raw[-MAX_HISTORY_TURNS:]:
        if (isinstance(item, dict) and item.get('role') in ('user', 'assistant')
                and isinstance(item.get('content'), str) and item['content'].strip()):
            turns.append({'role': item['role'], 'content': item['content'][:MAX_QUERY_LENGTH * 2]})
    return turns


def recent_history(user):
    """Derniers échanges de l'utilisateur (6 dernières heures), du plus ancien au plus récent."""
    since = timezone.now() - CONVERSATION_WINDOW
    interactions = AIInteraction.objects.filter(user=user, created_at__gte=since).order_by('-created_at')[:12]
    turns = []
    for interaction in reversed(list(interactions)):
        turns.append({'role': 'user', 'content': interaction.query})
        turns.append({'role': 'assistant', 'content': interaction.response})
    return turns


def _resolution_response(resolution):
    """201 quand l'appel a produit le résultat, 200 quand il relit un résultat déjà enregistré (idempotence)."""
    code = status.HTTP_200_OK if resolution.replayed else status.HTTP_201_CREATED
    return Response(AIInteractionSerializer(resolution.interaction).data, status=code)


def conversation_history(conversation):
    """Historique spécifique d'une session de conversation, du plus ancien au plus récent."""
    interactions = conversation.interactions.order_by('-created_at')[:12]
    turns = []
    for interaction in reversed(list(interactions)):
        turns.append({'role': 'user', 'content': interaction.query})
        turns.append({'role': 'assistant', 'content': interaction.response})
    return turns


class AIConversationListView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'ai'

    def get(self, request, *args, **kwargs):
        """Liste des sessions de conversation de l'utilisateur connecté."""
        conversations = AIConversation.objects.filter(user=request.user).order_by('-updated_at')[:50]
        serializer = AIConversationListSerializer(conversations, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request, *args, **kwargs):
        """Crée une nouvelle session de conversation."""
        title = request.data.get('title', '').strip()
        if title and len(title) > 255:
            return Response({"error": "Le titre ne peut pas dépasser 255 caractères."}, status=status.HTTP_400_BAD_REQUEST)
        conversation = AIConversation.objects.create(
            user=request.user,
            title=title or "Nouvelle discussion"
        )
        serializer = AIConversationDetailSerializer(conversation)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class AIConversationDetailView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'ai'

    def get(self, request, conversation_id, *args, **kwargs):
        """Récupère une conversation et la totalité de son fil d'échanges."""
        try:
            conv_uuid = uuid.UUID(str(conversation_id))
        except (ValueError, TypeError, AttributeError):
            return Response({"error": "Format d'identifiant de conversation invalide."}, status=status.HTTP_400_BAD_REQUEST)

        conversation = AIConversation.objects.filter(id=conv_uuid, user=request.user).first()
        if not conversation:
            return Response({"error": "Conversation introuvable."}, status=status.HTTP_404_NOT_FOUND)

        serializer = AIConversationDetailSerializer(conversation)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def patch(self, request, conversation_id, *args, **kwargs):
        """Renomme une conversation existante."""
        try:
            conv_uuid = uuid.UUID(str(conversation_id))
        except (ValueError, TypeError, AttributeError):
            return Response({"error": "Format d'identifiant de conversation invalide."}, status=status.HTTP_400_BAD_REQUEST)

        conversation = AIConversation.objects.filter(id=conv_uuid, user=request.user).first()
        if not conversation:
            return Response({"error": "Conversation introuvable."}, status=status.HTTP_404_NOT_FOUND)

        title = request.data.get('title', '').strip()
        if not title:
            return Response({"error": "Le titre ne peut pas être vide."}, status=status.HTTP_400_BAD_REQUEST)
        if len(title) > 255:
            return Response({"error": "Le titre ne peut pas dépasser 255 caractères."}, status=status.HTTP_400_BAD_REQUEST)

        conversation.title = title
        conversation.save()
        return Response(AIConversationDetailSerializer(conversation).data, status=status.HTTP_200_OK)

    def delete(self, request, conversation_id, *args, **kwargs):
        """Supprime une conversation et ses messages en cascade."""
        try:
            conv_uuid = uuid.UUID(str(conversation_id))
        except (ValueError, TypeError, AttributeError):
            return Response({"error": "Format d'identifiant de conversation invalide."}, status=status.HTTP_400_BAD_REQUEST)

        conversation = AIConversation.objects.filter(id=conv_uuid, user=request.user).first()
        if not conversation:
            return Response({"error": "Conversation introuvable."}, status=status.HTTP_404_NOT_FOUND)

        conversation.delete()
        return Response({"message": "Conversation supprimée avec succès."}, status=status.HTTP_204_NO_CONTENT)


class AskAIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'ai'

    def get(self, request, *args, **kwargs):
        """Récupère l'historique récent des interactions IA de l'utilisateur."""
        conv_id = request.query_params.get('conversation_id')
        if conv_id:
            try:
                conv_uuid = uuid.UUID(str(conv_id))
            except (ValueError, TypeError, AttributeError):
                return Response({"error": "Format d'identifiant de conversation invalide."}, status=status.HTTP_400_BAD_REQUEST)
            conversation = AIConversation.objects.filter(id=conv_uuid, user=request.user).first()
            if not conversation:
                return Response({"error": "Conversation introuvable."}, status=status.HTTP_404_NOT_FOUND)
            interactions = conversation.interactions.order_by('created_at')
        else:
            interactions = AIInteraction.objects.filter(user=request.user).order_by('-created_at')[:20]
        serializer = AIInteractionSerializer(interactions, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request, *args, **kwargs):
        query = request.data.get('query') or request.data.get('prompt')
        context = request.data.get('context', 'general')
        image_base64 = request.data.get('image_base64')
        conversation_id = request.data.get('conversation_id')

        if query is not None and (not isinstance(query, str) or len(query) > MAX_QUERY_LENGTH):
            return Response({"error": f"La question doit être un texte de {MAX_QUERY_LENGTH} caractères maximum."}, status=status.HTTP_400_BAD_REQUEST)
        if image_base64 is not None and (not isinstance(image_base64, str) or len(image_base64) > MAX_IMAGE_BASE64_LENGTH):
            return Response({"error": "Image invalide ou trop volumineuse."}, status=status.HTTP_400_BAD_REQUEST)

        if not query and not image_base64:
            return Response({"error": "La requête ou l'image est requise."}, status=status.HTTP_400_BAD_REQUEST)

        safe_query = query.strip() if query else "Analyse cette image."

        # Résolution de la session de conversation avec isolation multi-tenant stricte
        conversation = None
        if conversation_id:
            try:
                conv_uuid = uuid.UUID(str(conversation_id))
            except (ValueError, TypeError, AttributeError):
                return Response({"error": "Identifiant de conversation (UUID) invalide."}, status=status.HTTP_400_BAD_REQUEST)
            conversation = AIConversation.objects.filter(id=conv_uuid, user=request.user).first()
            if not conversation:
                return Response({"error": "Conversation introuvable."}, status=status.HTTP_404_NOT_FOUND)
        else:
            since = timezone.now() - CONVERSATION_WINDOW
            conversation = AIConversation.objects.filter(user=request.user, updated_at__gte=since).order_by('-updated_at').first()
            if not conversation:
                auto_title = safe_query[:40].strip()
                if len(safe_query) > 40:
                    auto_title += "..."
                conversation = AIConversation.objects.create(
                    user=request.user,
                    title=auto_title or "Nouvelle discussion"
                )

        # 1. L'utilisateur répond-il à une proposition d'opération en attente ?
        #    Seule une réponse composée uniquement de « oui » / « non » (et politesse) décide ;
        #    « ok mais mets 5000 » n'exécute rien.
        intent = None
        if not image_base64:
            reply = classify_reply(safe_query)
            pending = proposals.latest_pending(conversation)
            if pending and reply in proposals.DECISIONS_BY_REPLY:
                try:
                    resolution = resolve_proposal(
                        request.user, pending.pk, proposals.DECISIONS_BY_REPLY[reply],
                        query=safe_query, context=context,
                    )
                except ProposalUnavailable as exc:
                    return Response({"error": exc.message, "code": exc.code}, status=status.HTTP_409_CONFLICT)
                dialogue.remember(conversation, product=dialogue.product_of(pending.action_data))
                return _resolution_response(resolution)

            intent = detect_action_intent(safe_query, user=request.user)
            actionable = intent.get('has_intent') or intent.get('note')
            if pending and reply == 'ambiguous' and not actionable:
                note = proposals.create_note(
                    user=request.user, conversation=conversation, query=safe_query, context=context,
                    text=proposals.CLARIFICATION_TEXT, suggestions=['Oui, valider', 'Non, annuler'],
                    kind=proposals.CLARIFICATION_KIND,
                )
                return Response(AIInteractionSerializer(note).data, status=status.HTTP_201_CREATED)

            if not pending and reply == 'confirm':
                recent = conversation.interactions.order_by('-created_at').first()
                if recent and proposals.is_recent_outcome(recent):
                    note = proposals.create_note(
                        user=request.user, conversation=conversation, query=safe_query, context=context,
                        text=proposals.ALREADY_HANDLED_TEXT, suggestions=['Consulter mon solde', 'Vérifier mon stock'],
                    )
                    return Response(AIInteractionSerializer(note).data, status=status.HTTP_201_CREATED)

            # 1bis. Demande incomplète (« j'ai vendu du mil ») ou réponse à une question de précision : l'assistant ne devine
            #       pas, il pose la question qui manque, puis construit la proposition habituelle quand tout est connu
            turn = dialogue.handle_turn(request.user, conversation, safe_query, intent, context=context)
            if turn is not None:
                dialogue.remember(conversation, product=dialogue.product_of(turn.action_data))
                return Response(AIInteractionSerializer(turn).data, status=status.HTTP_201_CREATED)

        # 2. Demande d'opération reconnue mais impossible à proposer (rappel introuvable, plusieurs candidats…)
        if intent and intent.get('note'):
            note = proposals.create_note(
                user=request.user, conversation=conversation, query=safe_query, context=context,
                text=intent['note'], suggestions=intent.get('suggestions') or [],
            )
            return Response(AIInteractionSerializer(note).data, status=status.HTTP_201_CREATED)

        # 3. Nouvelle intention d'opération métier : on propose, on n'écrit rien avant confirmation
        if intent and intent.get('has_intent'):
            interaction = proposals.create_proposal(
                user=request.user, conversation=conversation, query=safe_query, context=context, intent=intent,
            )
            dialogue.remember(conversation, product=dialogue.product_of(interaction.action_data))
            return Response(AIInteractionSerializer(interaction).data, status=status.HTTP_201_CREATED)

        # 4. Consultation en lecture seule : la réponse vient de la base, sans modèle de langage
        if not image_base64:
            query_intent = detect_query_intent(safe_query)
            if query_intent:
                answer = answer_query(request.user, query_intent)
                note = proposals.create_note(
                    user=request.user, conversation=conversation, query=safe_query, context=context,
                    text=answer['text'], suggestions=answer['suggestions'], kind='query',
                )
                return Response(AIInteractionSerializer(note).data, status=status.HTTP_201_CREATED)

            # 5. Analyse chiffrée (revenus, dépenses, marges, ruptures…) : calculée par le code, jamais par le modèle
            #    « ce produit », « et le mois dernier ? », « et la tomate ? » se comprennent grâce à la mémoire de la conversation
            last = dialogue.last_facts(conversation)
            analysis_intent = detect_analysis_intent(safe_query, request.user, last=last) or resolve_followup(safe_query, request.user, last)
            if analysis_intent:
                answer = answer_analysis(request.user, analysis_intent)
                dialogue.remember(conversation, **memory_of(analysis_intent, answer))
                visual = visual_for(analysis_intent, answer)
                note = proposals.create_note(
                    user=request.user, conversation=conversation, query=safe_query, context=context,
                    text=answer['text'], suggestions=answer['suggestions'], kind='analysis',
                    extra={'visual': visual} if visual else None,
                )
                return Response(AIInteractionSerializer(note).data, status=status.HTTP_201_CREATED)

        # Résolution de l'historique conversationnel
        history = clean_history(request.data.get('history'))
        if history is None:
            conv_hist = conversation_history(conversation) if conversation else []
            history = conv_hist if conv_hist else recent_history(request.user)

        # Appel au service IA avec contexte sécurisé et langue
        # Langue : celle demandée par le client, sinon détectée ; un message trop court (« oui », « 15000 ») garde la langue
        # de l'échange précédent, ce qui conserve le contexte quand la conversation passe du français au wolof.
        detected = detect_language(safe_query, (dialogue.last_facts(conversation).get('lang') if conversation else None))
        language = request.data.get('language') or ('wo' if detected.is_wolof else None)
        if conversation:
            dialogue.remember(conversation, lang=detected.language)
        result = answer_question(
            safe_query,
            context,
            image_base64=image_base64,
            user=request.user,
            history=history,
            language=language
        )

        action_data = result.get('action_data', {})

        # Sauvegarde en BDD de l'interaction
        interaction = AIInteraction.objects.create(
            user=request.user,
            conversation=conversation,
            query=safe_query,
            response=result['answer'],
            context_type=context,
            origin=result['origin'],
            sources=result['sources'],
            suggestions=result.get('suggestions', []),
            action_data=action_data,
        )

        if conversation:
            if conversation.title in ("Nouvelle conversation", "Nouvelle discussion"):
                new_title = safe_query[:40].strip()
                if len(safe_query) > 40:
                    new_title += "..."
                conversation.title = new_title or "Discussion"
            conversation.save()

        # Langue de l'échange : le téléphone ne peut pas lire le wolof à voix haute, il doit le savoir
        payload = dict(AIInteractionSerializer(interaction).data, language=detected.language)
        return Response(payload, status=status.HTTP_201_CREATED)


class ExecuteAIActionView(views.APIView):
    """
    Confirme ou annule, depuis un bouton de l'interface, une proposition d'opération déjà faite par l'assistant.

    Corps : ``{"interaction_id": "<uuid de la proposition>", "decision": "confirm" | "cancel"}``.

    Le client ne fournit jamais l'opération elle-même : seuls les paramètres enregistrés par le serveur
    au moment de la proposition sont exécutés. Rappeler l'endpoint pour une proposition déjà traitée
    renvoie le résultat existant (HTTP 200) sans nouvelle écriture.
    """
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'ai'

    def post(self, request, *args, **kwargs):
        interaction_id = request.data.get('interaction_id')
        decision = request.data.get('decision')

        if not interaction_id:
            return Response(
                {"error": "Une opération doit d'abord être proposée par l'assistant, puis confirmée par son identifiant.",
                 "code": "proposal_required"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            proposal_uuid = uuid.UUID(str(interaction_id))
        except (ValueError, TypeError, AttributeError):
            return Response({"error": "Identifiant de proposition invalide.", "code": "invalid_id"}, status=status.HTTP_400_BAD_REQUEST)
        if decision not in proposals.DECISIONS:
            return Response({"error": "La décision doit être « confirm » ou « cancel ».", "code": "invalid_decision"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            resolution = resolve_proposal(request.user, proposal_uuid, decision)
        except ProposalNotFound:
            return Response({"error": "Proposition introuvable.", "code": "not_found"}, status=status.HTTP_404_NOT_FOUND)
        except ProposalUnavailable as exc:
            return Response({"error": exc.message, "code": exc.code}, status=status.HTTP_409_CONFLICT)
        return _resolution_response(resolution)


class AnalyticsAIView(views.APIView):
    """
    Synthèse financière déterministe et état des stocks certifié par Naatal Agro.
    """
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'ai'

    def get(self, request, *args, **kwargs):
        period = request.query_params.get('period', 'all')
        finances = analyze_farmer_finances(request.user, period=period)
        inventory = analyze_farmer_inventory(request.user)
        return Response({
            'finances': finances,
            'inventory': inventory,
            'timestamp': timezone.now().isoformat()
        }, status=status.HTTP_200_OK)


class TranscribeAudioView(views.APIView):
    """
    Transcription d'un message vocal en texte. Accepte un fichier multipart ``audio`` ou une chaîne ``audio_base64``.
    L'audio n'est jamais conservé ; le texte renvoyé est ensuite envoyé par le client dans le circuit normal de
    l'assistant (rien n'est exécuté sans confirmation).
    """
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'ai'

    def post(self, request, *args, **kwargs):
        import base64
        import binascii
        from . import voice

        audio_bytes = None
        content_type = "audio/m4a"
        filename = "audio.m4a"

        if 'audio' in request.FILES:
            f = request.FILES['audio']
            audio_bytes = f.read()
            content_type = f.content_type or content_type
            filename = f.name or filename
        elif 'audio_base64' in request.data:
            raw_b64 = str(request.data.get('audio_base64') or '')
            if len(raw_b64) > voice.MAX_AUDIO_BYTES * 4 // 3 + 8:  # on refuse avant de décoder une charge énorme
                return Response({"error": "Enregistrement trop volumineux (15 Mo maximum).", "code": "too_large"},
                                status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)
            try:
                audio_bytes = base64.b64decode(raw_b64, validate=True)
            except (binascii.Error, ValueError):
                return Response({"error": "Format base64 audio invalide.", "code": "bad_audio"},
                                status=status.HTTP_400_BAD_REQUEST)

        if not audio_bytes:
            return Response({"error": "Fichier audio ou audio_base64 requis.", "code": "missing_audio"},
                            status=status.HTTP_400_BAD_REQUEST)
        if len(audio_bytes) > voice.MAX_AUDIO_BYTES:
            return Response({"error": "Enregistrement trop volumineux (15 Mo maximum).", "code": "too_large"},
                            status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)
        if len(audio_bytes) < voice.MIN_AUDIO_BYTES:
            return Response({"text": "", "error": "Enregistrement trop court : maintenez le micro et parlez.",
                             "code": "too_short"}, status=status.HTTP_422_UNPROCESSABLE_ENTITY)

        detected = voice.sniff_audio_format(audio_bytes)
        if detected:
            filename, content_type = detected

        text = voice.transcribe_audio_bytes(audio_bytes, filename=filename, content_type=content_type)
        if text is None:
            return Response({"text": "", "error": "Le service de transcription est momentanément indisponible. "
                                                  "Vous pouvez écrire votre message.", "code": "unavailable"},
                            status=status.HTTP_503_SERVICE_UNAVAILABLE)
        if not text:
            return Response({"text": "", "error": "Je n'ai rien entendu. Rapprochez-vous du micro et réessayez.",
                             "code": "no_speech"}, status=status.HTTP_422_UNPROCESSABLE_ENTITY)
        return Response({"text": text}, status=status.HTTP_200_OK)
