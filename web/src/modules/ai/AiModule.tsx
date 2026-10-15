import React, { useState } from 'react';
import { Bot, Send, Sparkles, AlertCircle, BookOpen } from 'lucide-react';
import axios from 'axios';

interface ChatMessage {
  id: string;
  sender: 'user' | 'ia';
  text: string;
  origin?: string;
  sources?: string[];
  suggestions?: string[];
}

export function AiModule() {
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: 'welcome',
      sender: 'ia',
      text: 'Salam alikoum ! Je suis Naatal IA, votre agronome intelligent. Posez-moi vos questions sur vos cultures, la rentabilité des marchés ou la détection de ravageurs.',
      suggestions: ['Prix oignon Tilène ?', 'Traitement mildiou tomate', 'Cycle semis arachide']
    }
  ]);
  const [inputQuery, setInputQuery] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSend = async (queryText?: string) => {
    const textToSend = (queryText || inputQuery).trim();
    if (!textToSend || isLoading) return;

    const userMsgId = String(Date.now());
    const userMsg: ChatMessage = {
      id: userMsgId,
      sender: 'user',
      text: textToSend,
    };

    setMessages((prev) => [...prev, userMsg]);
    setInputQuery('');
    setIsLoading(true);
    setErrorMessage(null);

    // Build history for context
    const historyPayload = messages
      .filter((m) => m.id !== 'welcome')
      .slice(-6)
      .map((m) => ({
        role: m.sender === 'user' ? 'user' : 'assistant',
        content: m.text,
      }));

    try {
      const token = localStorage.getItem('access_token');
      const headers: Record<string, string> = {};
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const response = await axios.post(
        '/api/ai/ask/',
        {
          query: textToSend,
          context: 'general',
          history: historyPayload,
        },
        { headers, timeout: 25000 }
      );

      const data = response.data;
      const iaMsg: ChatMessage = {
        id: String(Date.now() + 1),
        sender: 'ia',
        text: data.response || data.answer || "Conseil agronomique enregistré.",
        origin: data.origin,
        sources: Array.isArray(data.sources) ? data.sources : [],
        suggestions: Array.isArray(data.suggestions) ? data.suggestions : [],
      };
      setMessages((prev) => [...prev, iaMsg]);
    } catch (err: any) {
      console.error('Erreur API Naatal IA:', err);
      // Récupérer message d'erreur précis du backend
      let errText = "Connexion au copilote IA indisponible. Vérifiez votre connexion ou la configuration des clés API.";
      if (err.response?.status === 401) {
        errText = "Veuillez vous connecter pour poser une question au copilote agronomique Naatal IA.";
      } else if (err.response?.data?.error) {
        errText = err.response.data.error;
      }
      setErrorMessage(errText);
      setMessages((prev) => [
        ...prev,
        {
          id: String(Date.now() + 2),
          sender: 'ia',
          text: `⚠️ ${errText}`,
        }
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="card-section" style={{ minHeight: '520px', display: 'flex', flexDirection: 'column' }}>
      <div className="section-header" style={{ marginBottom: '16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ background: '#2E7D32', padding: '10px', borderRadius: '12px', color: 'white', display: 'flex' }}>
            <Bot size={24} />
          </div>
          <div>
            <h2 className="section-title">Copilote Agronomique Naatal IA</h2>
            <p style={{ fontSize: '13px', color: '#64748B' }}>
              Intelligence agronomique connectée (ISRA / ANCAR / Gemini & Groq)
            </p>
          </div>
        </div>
      </div>

      {errorMessage && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', background: '#FEF2F2', border: '1px solid #FCA5A5', padding: '10px 14px', borderRadius: '10px', color: '#B91C1C', fontSize: '13px', marginBottom: '12px' }}>
          <AlertCircle size={16} />
          <span>{errorMessage}</span>
        </div>
      )}

      {/* Zone de conversation */}
      <div style={{ flex: 1, minHeight: '340px', maxHeight: '450px', overflowY: 'auto', padding: '16px', background: '#F8FAFC', borderRadius: '16px', marginBottom: '16px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
        {messages.map((msg) => (
          <div
            key={msg.id}
            style={{
              alignSelf: msg.sender === 'user' ? 'flex-end' : 'flex-start',
              maxWidth: '82%',
              padding: '14px 18px',
              borderRadius: '16px',
              background: msg.sender === 'user' ? '#2E7D32' : 'white',
              color: msg.sender === 'user' ? 'white' : '#0F172A',
              boxShadow: '0 2px 6px rgba(0,0,0,0.05)',
              fontSize: '14px',
              lineHeight: 1.6,
            }}
          >
            <div>{msg.text}</div>
            
            {/* Sources vérifiées */}
            {msg.sources && msg.sources.length > 0 && (
              <div style={{ marginTop: '8px', paddingTop: '8px', borderTop: '1px solid #E2E8F0', fontSize: '11px', color: '#64748B', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <BookOpen size={13} color="#2E7D32" />
                <span>Sources vérifiées : {msg.sources.join(', ')}</span>
              </div>
            )}

            {/* Suggestions de questions */}
            {msg.suggestions && msg.suggestions.length > 0 && (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginTop: '10px' }}>
                {msg.suggestions.map((sug, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => handleSend(sug)}
                    style={{
                      background: '#F1F5F9',
                      border: '1px solid #CBD5E1',
                      borderRadius: '12px',
                      padding: '4px 10px',
                      fontSize: '12px',
                      cursor: 'pointer',
                      color: '#1E293B',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                    }}
                  >
                    <Sparkles size={11} color="#2E7D32" />
                    <span>{sug}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        ))}
        {isLoading && (
          <div style={{ alignSelf: 'flex-start', background: 'white', padding: '12px 18px', borderRadius: '16px', boxShadow: '0 2px 6px rgba(0,0,0,0.05)', fontSize: '13px', color: '#64748B', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <div className="animate-spin" style={{ width: '14px', height: '14px', border: '2px solid #2E7D32', borderTopColor: 'transparent', borderRadius: '50%' }} />
            <span>Naatal IA formule son analyse agronomique...</span>
          </div>
        )}
      </div>

      {/* Barre de saisie */}
      <form
        onSubmit={(e) => {
          e.preventDefault();
          handleSend();
        }}
        style={{ display: 'flex', gap: '10px' }}
      >
        <input
          type="text"
          placeholder="Posez votre question agronomique (ex: dosage engrais oignon, cours du mil à Kaolack...)"
          value={inputQuery}
          onChange={(e) => setInputQuery(e.target.value)}
          disabled={isLoading}
          style={{
            flex: 1,
            padding: '14px 18px',
            borderRadius: '14px',
            border: '1px solid #CBD5E1',
            outline: 'none',
            fontSize: '14px',
          }}
        />
        <button
          type="submit"
          disabled={isLoading || !inputQuery.trim()}
          style={{
            padding: '0 24px',
            background: inputQuery.trim() && !isLoading ? '#2E7D32' : '#94A3B8',
            color: 'white',
            border: 'none',
            borderRadius: '14px',
            fontWeight: 700,
            cursor: inputQuery.trim() && !isLoading ? 'pointer' : 'default',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
          }}
        >
          <span>Envoyer</span>
          <Send size={16} />
        </button>
      </form>
    </div>
  );
}
