-- Procédure 2 : création de la structure de la table de travail
-- (vide, à partir de la table d'origine import_table supposée existante).
--   CALL create_travail();

CREATE OR REPLACE PROCEDURE create_travail()
LANGUAGE plpgsql
AS $$
BEGIN
    DROP TABLE IF EXISTS travail_table;

    CREATE TABLE travail_table (
        id                BIGINT PRIMARY KEY REFERENCES import_table(id) ON DELETE CASCADE,
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
        "MOIS"            TEXT,
        "UNIQUE IDENTIFIER CALCULE" TEXT
    );

    RAISE NOTICE 'Table travail_table créée (vide)';
END;
$$;
