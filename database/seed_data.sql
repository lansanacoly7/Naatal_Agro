-- ========================================================
-- Naatal Agro — Script SQL de peuplement (Seed Data)
-- ========================================================

-- 1. Marchés régionaux du Sénégal
INSERT INTO markets_market (id, name, region, location_gps, created_at) VALUES
('b1a2c3d4-0001-4000-8000-000000000001', 'Marché Castors', 'Dakar', '14.7077,-17.4526', CURRENT_TIMESTAMP),
('b1a2c3d4-0002-4000-8000-000000000002', 'Marché Central', 'Thiès', '14.7928,-16.9267', CURRENT_TIMESTAMP),
('b1a2c3d4-0003-4000-8000-000000000003', 'Marché de Kaolack', 'Kaolack', '14.1500,-16.0833', CURRENT_TIMESTAMP),
('b1a2c3d4-0004-4000-8000-000000000004', 'Marché Sor', 'Saint-Louis', '16.0167,-16.4833', CURRENT_TIMESTAMP),
('b1a2c3d4-0005-4000-8000-000000000005', 'Marché Boucotte', 'Ziguinchor', '12.5833,-16.2667', CURRENT_TIMESTAMP);

-- 2. Cotations des prix récents
INSERT INTO markets_price (id, market_id, product_name, price, trend, date) VALUES
-- Dakar
('c1a2c3d4-0001-4000-8000-000000000101', 'b1a2c3d4-0001-4000-8000-000000000001', 'Tomate', 450.00, 'up', CURRENT_DATE),
('c1a2c3d4-0001-4000-8000-000000000102', 'b1a2c3d4-0001-4000-8000-000000000001', 'Oignon', 300.00, 'down', CURRENT_DATE),
('c1a2c3d4-0001-4000-8000-000000000103', 'b1a2c3d4-0001-4000-8000-000000000001', 'Pomme de terre', 400.00, 'stable', CURRENT_DATE),
('c1a2c3d4-0001-4000-8000-000000000104', 'b1a2c3d4-0001-4000-8000-000000000001', 'Riz local', 350.00, 'stable', CURRENT_DATE),
-- Thiès
('c1a2c3d4-0002-4000-8000-000000000201', 'b1a2c3d4-0002-4000-8000-000000000002', 'Tomate', 400.00, 'stable', CURRENT_DATE),
('c1a2c3d4-0002-4000-8000-000000000202', 'b1a2c3d4-0002-4000-8000-000000000002', 'Oignon', 250.00, 'up', CURRENT_DATE),
('c1a2c3d4-0002-4000-8000-000000000203', 'b1a2c3d4-0002-4000-8000-000000000002', 'Arachide', 500.00, 'up', CURRENT_DATE),
-- Kaolack
('c1a2c3d4-0003-4000-8000-000000000301', 'b1a2c3d4-0003-4000-8000-000000000003', 'Arachide décortiquée', 550.00, 'up', CURRENT_DATE),
('c1a2c3d4-0003-4000-8000-000000000302', 'b1a2c3d4-0003-4000-8000-000000000003', 'Mil', 280.00, 'stable', CURRENT_DATE),
('c1a2c3d4-0003-4000-8000-000000000303', 'b1a2c3d4-0003-4000-8000-000000000003', 'Maïs', 260.00, 'down', CURRENT_DATE),
-- Saint-Louis
('c1a2c3d4-0004-4000-8000-000000000401', 'b1a2c3d4-0004-4000-8000-000000000004', 'Riz de la Vallée', 320.00, 'stable', CURRENT_DATE),
('c1a2c3d4-0004-4000-8000-000000000402', 'b1a2c3d4-0004-4000-8000-000000000004', 'Oignon local', 230.00, 'down', CURRENT_DATE);

-- 3. Données Météorologiques
INSERT INTO weather_weatherdata (id, location, temperature, humidity, rainfall, forecast_date, created_at) VALUES
('d1a2c3d4-0001-4000-8000-000000000001', 'thiès, sénégal', 32.5, 45.0, 0.0, CURRENT_DATE, CURRENT_TIMESTAMP),
('d1a2c3d4-0002-4000-8000-000000000002', 'dakar, sénégal', 29.0, 68.0, 0.0, CURRENT_DATE, CURRENT_TIMESTAMP),
('d1a2c3d4-0003-4000-8000-000000000003', 'saint-louis, sénégal', 31.0, 52.0, 2.5, CURRENT_DATE, CURRENT_TIMESTAMP),
('d1a2c3d4-0004-4000-8000-000000000004', 'kaolack, sénégal', 36.0, 40.0, 0.0, CURRENT_DATE, CURRENT_TIMESTAMP);
