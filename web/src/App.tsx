import React, { useState, useEffect } from 'react';
import { LayoutDashboard, Store, Sprout, CloudSun, Bell, Bot, Users } from 'lucide-react';
import axios from 'axios';

interface MarketPrice {
  id: string;
  product_name: string;
  price: number;
  trend: string;
  date: string;
  market_name?: string;
}

export function App() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [prices, setPrices] = useState<MarketPrice[]>([
    { id: '1', product_name: 'Tomate', price: 450, trend: 'up', date: '2026-07-19', market_name: 'Marché Castors (Dakar)' },
    { id: '2', product_name: 'Oignon', price: 300, trend: 'down', date: '2026-07-19', market_name: 'Marché Castors (Dakar)' },
    { id: '3', product_name: 'Arachide décortiquée', price: 550, trend: 'up', date: '2026-07-19', market_name: 'Marché Kaolack' },
    { id: '4', product_name: 'Riz local', price: 350, trend: 'stable', date: '2026-07-19', market_name: 'Marché Sor (Saint-Louis)' }
  ]);

  return (
    <div className="app-container">
      {/* Sidebar */}
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-icon">
            <Sprout size={24} color="#FFFFFF" />
          </div>
          <span className="brand-title">Naatal Agro</span>
        </div>

        <ul className="nav-list">
          <li className={`nav-item ${activeTab === 'dashboard' ? 'active' : ''}`} onClick={() => setActiveTab('dashboard')}>
            <LayoutDashboard size={20} />
            <span>Tableau de Bord</span>
          </li>
          <li className={`nav-item ${activeTab === 'markets' ? 'active' : ''}`} onClick={() => setActiveTab('markets')}>
            <Store size={20} />
            <span>Marchés & Prix</span>
          </li>
          <li className={`nav-item ${activeTab === 'crops' ? 'active' : ''}`} onClick={() => setActiveTab('crops')}>
            <Sprout size={20} />
            <span>Exploitations</span>
          </li>
          <li className={`nav-item ${activeTab === 'weather' ? 'active' : ''}`} onClick={() => setActiveTab('weather')}>
            <CloudSun size={20} />
            <span>Météo Agricole</span>
          </li>
          <li className={`nav-item ${activeTab === 'ai' ? 'active' : ''}`} onClick={() => setActiveTab('ai')}>
            <Bot size={20} />
            <span>Naatal IA</span>
          </li>
        </ul>
      </aside>

      {/* Main Content */}
      <main className="main-content">
        <header className="header">
          <div className="header-title">
            <h1>Dashboard Administrateur</h1>
            <p>Vue macroscopique et gestion des filières agricoles au Sénégal</p>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <button style={{ padding: '10px', background: 'white', border: '1px solid #E2E8F0', borderRadius: '12px', cursor: 'pointer' }}>
              <Bell size={20} color="#64748B" />
            </button>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: 'white', padding: '6px 16px', borderRadius: '14px', border: '1px solid #E2E8F0' }}>
              <div style={{ width: '36px', height: '36px', background: '#2E7D32', borderRadius: '50%', color: 'white', display: 'flex', alignItems: 'center', justifyCenter: 'center', fontWeight: 'bold' }}>
                A
              </div>
              <span style={{ fontWeight: '600', fontSize: '14px' }}>Admin ISEP</span>
            </div>
          </div>
        </header>

        {/* Stats Grid */}
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-header">
              <span className="stat-title">Exploitants Inscrits</span>
              <Users size={20} color="#2E7D32" />
            </div>
            <div className="stat-value">1 248</div>
          </div>
          <div className="stat-card">
            <div className="stat-header">
              <span className="stat-title">Marchés Suivis</span>
              <Store size={20} color="#FF6B35" />
            </div>
            <div className="stat-value">5 Régions</div>
          </div>
          <div className="stat-card">
            <div className="stat-header">
              <span className="stat-title">Cultures Actives</span>
              <Sprout size={20} color="#2E7D32" />
            </div>
            <div className="stat-value">3 420 Ha</div>
          </div>
          <div className="stat-card">
            <div className="stat-header">
              <span className="stat-title">Requêtes IA / Jour</span>
              <Bot size={20} color="#2563EB" />
            </div>
            <div className="stat-value">856</div>
          </div>
        </div>

        {/* Cotations des Marchés */}
        <div className="card-section">
          <div className="section-header">
            <h2 className="section-title">Cotations des Produits Agricoles en Temps Réel</h2>
            <span style={{ fontSize: '13px', color: '#64748B', fontWeight: '500' }}>Mis à jour aujourd'hui</span>
          </div>

          <table className="data-table">
            <thead>
              <tr>
                <th>Produit</th>
                <th>Marché</th>
                <th>Prix (FCFA/Kg)</th>
                <th>Tendance</th>
                <th>Statut</th>
              </tr>
            </thead>
            <tbody>
              {prices.map((item) => (
                <tr key={item.id}>
                  <td style={{ fontWeight: '600' }}>{item.product_name}</td>
                  <td>{item.market_name}</td>
                  <td style={{ fontWeight: '700', color: '#2E7D32' }}>{item.price} FCFA</td>
                  <td>
                    {item.trend === 'up' ? (
                      <span className="badge badge-green">↗ En hausse</span>
                    ) : item.trend === 'down' ? (
                      <span className="badge badge-orange">↘ En baisse</span>
                    ) : (
                      <span className="badge" style={{ background: '#F1F5F9', color: '#475569' }}>→ Stable</span>
                    )}
                  </td>
                  <td>
                    <span className="badge badge-green">Vérifié</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </main>
    </div>
  );
}

export default App;
