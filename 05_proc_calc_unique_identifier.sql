-- Procédure 5 : calcul de CODE BUSINESS APPLICATION CORRIGE (ensembliste).
--   CALL calc_unique_identifier();
-- Pré-requis : travail_table alimentée (alimente_travail) et
-- COST CENTER CALCULE résolu (calc_cost_center).
--
-- Version ensembliste : les deux lookups sont pré-agrégés une fois
-- (CTE m1 et m2), puis un seul UPDATE joint le tout — 3 scans au total,
-- contre 2 requêtes corrélées par ligne dans l'ancienne version en boucle.
-- Résultats strictement identiques (validés par tests/resultats_attendus.md).
--
-- Règles rules.md — comparaisons insensibles à la casse, les conditions
-- TOTBAS s'évaluent sur le COST CENTER CALCULE :
--
--   (APSQL ou APORA) + COST CENTER CALCULE différent de TOTBAS :
--     1) lookup via ASSET DMZR (12 premiers caractères) sur les lignes TOTBAS
--     2) lookup via MZR DATABASE NAME (égalité exacte, ignoré si NA)
--     Chaque lookup donne : un code unique, ERROR_MULTIPLE_CODES_APP si
--     plusieurs codes différents, ou rien si aucune ligne.
--     Combinaison : aucun résultat -> code d'origine ; un seul -> ce
--     résultat ; deux identiques -> ce code ; deux différents ->
--     ERROR_MULTIPLE_CODES_APP.
--   NA : -> APNOCODE_<OFFRE>_<METRIQUE DE SERVICE CODE>
--   Autres lignes : -> CODE BUSINESS APPLICATION d'origine.
--   La valeur est toujours insérée en MAJUSCULES.

CREATE OR REPLACE PROCEDURE calc_unique_identifier()
LANGUAGE plpgsql
AS $$
BEGIN
    WITH
    -- 1) code par asset (12 premiers caractères) côté TOTBAS
    m1 AS (
        SELECT UPPER(LEFT("ASSET DMZR", 12)) AS asset12,
               CASE WHEN COUNT(DISTINCT UPPER("CODE BUSINESS APPLICATION")) = 1
                        THEN MIN("CODE BUSINESS APPLICATION")
                    ELSE 'ERROR_MULTIPLE_CODES_APP'
               END AS code
        FROM travail_table
        WHERE UPPER("COST CENTER CALCULE") = 'TOTBAS'
        GROUP BY UPPER(LEFT("ASSET DMZR", 12))
    ),
    -- 2) code par database (égalité exacte, NA ignoré) côté TOTBAS
    m2 AS (
        SELECT UPPER("MZR DATABASE NAME") AS db,
               CASE WHEN COUNT(DISTINCT UPPER("CODE BUSINESS APPLICATION")) = 1
                        THEN MIN("CODE BUSINESS APPLICATION")
                    ELSE 'ERROR_MULTIPLE_CODES_APP'
               END AS code
        FROM travail_table
        WHERE UPPER("COST CENTER CALCULE") = 'TOTBAS'
          AND "MZR DATABASE NAME" IS NOT NULL
          AND UPPER("MZR DATABASE NAME") <> 'NA'
        GROUP BY UPPER("MZR DATABASE NAME")
    )
    UPDATE travail_table w
       SET "CODE BUSINESS APPLICATION CORRIGE" = UPPER(CASE
            -- Règle NA
            WHEN UPPER(w0."CODE BUSINESS APPLICATION") = 'NA'
                THEN 'APNOCODE_' || w0."OFFRE" || '_' || w0."METRIQUE DE SERVICE CODE"
            -- Règle (APSQL ou APORA) + cost center différent de TOTBAS
            WHEN UPPER(w0."CODE BUSINESS APPLICATION") IN ('APSQL', 'APORA')
             AND UPPER(w0."COST CENTER CALCULE") <> 'TOTBAS'
                THEN CASE
                    WHEN m1.code IS NULL AND m2.code IS NULL THEN w0."CODE BUSINESS APPLICATION"
                    WHEN m1.code IS NULL THEN m2.code
                    WHEN m2.code IS NULL THEN m1.code
                    WHEN UPPER(m1.code) = UPPER(m2.code) THEN m1.code
                    ELSE 'ERROR_MULTIPLE_CODES_APP'
                END
            -- Règle par défaut
            ELSE w0."CODE BUSINESS APPLICATION"
        END)
      FROM travail_table w0
      LEFT JOIN m1 ON m1.asset12 = UPPER(LEFT(w0."ASSET DMZR", 12))
      LEFT JOIN m2 ON m2.db = UPPER(w0."MZR DATABASE NAME")
                  AND UPPER(w0."MZR DATABASE NAME") <> 'NA'
     WHERE w0.id = w.id;

    RAISE NOTICE 'CODE BUSINESS APPLICATION CORRIGE mis à jour : % lignes',
        (SELECT count(*) FROM travail_table WHERE "CODE BUSINESS APPLICATION CORRIGE" IS NOT NULL);
END;
$$;
