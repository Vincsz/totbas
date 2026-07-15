-- Procédure 1 : import du CSV dans la table d'origine import_table.
-- Étape de préparation uniquement — sert à recréer la situation cible
-- où la table d'origine existe déjà.
--   CALL import_csv();                      -- charge /data/test1.csv
--   CALL import_csv('/data/autre.csv');     -- autre fichier
-- CSV attendu : en-têtes, séparateur ';' (dossier totbas monté sur /data).

CREATE OR REPLACE PROCEDURE import_csv(csv_path TEXT DEFAULT '/data/tests/test_etendu.csv')
LANGUAGE plpgsql
AS $$
BEGIN
    DROP TABLE IF EXISTS travail_table;   -- dépend d'import_table (FK)
    DROP TABLE IF EXISTS import_table;

    -- Noms de colonnes identiques à ceux du fichier
    CREATE TABLE import_table (
        id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        "CODE BUSINESS APPLICATION"    TEXT,
        "COST CENTER"     TEXT,
        "METRIQUE DE SERVICE CODE"   TEXT,
        "OFFRE"           TEXT,
        "ASSET DMZR"      TEXT,
        "MZR DATABASE NAME"        TEXT,
        "VOLUME"          TEXT,
        "PRIX"            TEXT,
        "COMPTE DMZR LABEL"             TEXT,
        "ENVIRONNEMENT"      TEXT,
        "ANNEE"           TEXT,
        "MOIS"            TEXT
    );

    EXECUTE format(
        'COPY import_table("CODE BUSINESS APPLICATION","COST CENTER","METRIQUE DE SERVICE CODE","OFFRE",
                           "ASSET DMZR","MZR DATABASE NAME","VOLUME","PRIX","COMPTE DMZR LABEL","ENVIRONNEMENT","ANNEE","MOIS")
         FROM %L WITH (FORMAT csv, HEADER true, DELIMITER '';'')',
        csv_path
    );

    RAISE NOTICE 'Import terminé : % lignes dans import_table',
        (SELECT count(*) FROM import_table);
END;
$$;
