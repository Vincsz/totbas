-- Procédure 3 : alimentation de la table de travail (vidée puis remplie).
--   CALL alimente_travail();
--
-- import_table et travail_table ont les mêmes colonnes ; la table de
-- travail ajoute UNIQUE IDENTIFIER CALCULE (ex-codeBusinessNew).
--
-- Règles rules.md pour UNIQUE IDENTIFIER CALCULE —
-- comparaisons insensibles à la casse :
--
-- APSQL + TOTO2I (CODE BUSINESS APPLICATION / COST CENTER) :
--   1) lookup via ASSET DMZR (7 premiers caractères) sur les lignes TOTBAS
--   2) lookup via MZR DATABASE NAME (égalité exacte, ignoré si NA)
--   Chaque lookup donne : un code unique, ERROR_MULTIPLE_CODES_APP si
--   plusieurs codes différents, ou rien si aucune ligne.
--   Combinaison : aucun résultat -> code d'origine ;
--   un seul résultat -> ce résultat ; deux résultats identiques -> ce code ;
--   deux résultats différents -> ERROR_MULTIPLE_CODES_APP.
--
-- NA :
--   CODE BUSINESS APPLICATION = NA -> APNOCODE_<OFFRE>_<METRIQUE DE SERVICE CODE>
--
-- Autres lignes : valeur = CODE BUSINESS APPLICATION d'origine.
-- La valeur calculée est toujours insérée en MAJUSCULES.

CREATE OR REPLACE PROCEDURE alimente_travail()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE travail_table;

    INSERT INTO travail_table (
        id,
        "CODE BUSINESS APPLICATION",
        "COST CENTER",
        "METRIQUE DE SERVICE CODE",
        "OFFRE",
        "ASSET DMZR",
        "MZR DATABASE NAME",
        "VOLUME",
        "PRIX",
        "COMPTE DMZR LABEL",
        "ENVIRONNEMENT",
        "ANNEE",
        "MOIS",
        "UNIQUE IDENTIFIER CALCULE"
    )
    SELECT
        i.id,
        i."CODE BUSINESS APPLICATION",
        i."COST CENTER",
        i."METRIQUE DE SERVICE CODE",
        i."OFFRE",
        i."ASSET DMZR",
        i."MZR DATABASE NAME",
        i."VOLUME",
        i."PRIX",
        i."COMPTE DMZR LABEL",
        i."ENVIRONNEMENT",
        i."ANNEE",
        i."MOIS",
        UPPER(CASE
            -- Règle NA
            WHEN UPPER(i."CODE BUSINESS APPLICATION") = 'NA'
                THEN 'APNOCODE_' || i."OFFRE" || '_' || i."METRIQUE DE SERVICE CODE"
            -- Règle APSQL + TOTO2I : combinaison des lookups 1) et 2)
            WHEN UPPER(i."CODE BUSINESS APPLICATION") = 'APSQL' AND UPPER(i."COST CENTER") = 'TOTO2I'
                THEN CASE
                    WHEN m1.code IS NULL AND m2.code IS NULL THEN i."CODE BUSINESS APPLICATION"
                    WHEN m1.code IS NULL THEN m2.code
                    WHEN m2.code IS NULL THEN m1.code
                    WHEN UPPER(m1.code) = UPPER(m2.code) THEN m1.code
                    ELSE 'ERROR_MULTIPLE_CODES_APP'
                END
            -- Autres lignes
            ELSE i."CODE BUSINESS APPLICATION"
        END)
    FROM import_table i
    -- 1) code par asset (7 premiers caractères) côté TOTBAS
    LEFT JOIN (
        SELECT UPPER(LEFT("ASSET DMZR", 7)) AS asset7,
               CASE WHEN COUNT(DISTINCT UPPER("CODE BUSINESS APPLICATION")) = 1
                        THEN MIN("CODE BUSINESS APPLICATION")
                    ELSE 'ERROR_MULTIPLE_CODES_APP'
               END AS code
        FROM import_table
        WHERE UPPER("COST CENTER") = 'TOTBAS'
        GROUP BY UPPER(LEFT("ASSET DMZR", 7))
    ) m1 ON m1.asset7 = UPPER(LEFT(i."ASSET DMZR", 7))
    -- 2) code par database (égalité exacte, NA ignoré) côté TOTBAS
    LEFT JOIN (
        SELECT UPPER("MZR DATABASE NAME") AS db,
               CASE WHEN COUNT(DISTINCT UPPER("CODE BUSINESS APPLICATION")) = 1
                        THEN MIN("CODE BUSINESS APPLICATION")
                    ELSE 'ERROR_MULTIPLE_CODES_APP'
               END AS code
        FROM import_table
        WHERE UPPER("COST CENTER") = 'TOTBAS'
          AND "MZR DATABASE NAME" IS NOT NULL
          AND UPPER("MZR DATABASE NAME") <> 'NA'
        GROUP BY UPPER("MZR DATABASE NAME")
    ) m2 ON m2.db = UPPER(i."MZR DATABASE NAME")
        AND UPPER(i."MZR DATABASE NAME") <> 'NA';

    RAISE NOTICE 'Table de travail alimentée : % lignes',
        (SELECT count(*) FROM travail_table);
END;
$$;
