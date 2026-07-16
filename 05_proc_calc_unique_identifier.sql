-- Procédure 5 : calcul de CODE BUSINESS APPLICATION CORRIGE (ensembliste, par lots).
--   CALL calc_unique_identifier();        -- lots de 100 000 lignes
--   CALL calc_unique_identifier(10000);   -- taille de lot personnalisée
-- Pré-requis : travail_table alimentée (alimente_travail) et
-- COST CENTER CALCULE résolu (calc_cost_center).
--
-- Les deux lookups sont pré-agrégés une seule fois dans des tables
-- temporaires indexées, puis l'UPDATE est appliqué par lots avec COMMIT
-- intermédiaire (verrous relâchés, progression visible par NOTICE).
-- ATTENTION : le COMMIT impose d'appeler la procédure hors transaction
-- explicite (autocommit, le mode par défaut de DBeaver et psql).
-- Les lookups étant figés avant le premier lot, le résultat est identique
-- à un UPDATE unique : les colonnes lues par les lookups ne sont pas
-- modifiées par cette procédure.
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

CREATE OR REPLACE PROCEDURE calc_unique_identifier(batch_size BIGINT DEFAULT 100000)
LANGUAGE plpgsql
AS $$
DECLARE
    lo      BIGINT;
    hi      BIGINT;
    dernier BIGINT;
BEGIN
    -- 1) code par asset (12 premiers caractères) côté TOTBAS
    DROP TABLE IF EXISTS tmp_m1;
    CREATE TEMP TABLE tmp_m1 AS
        SELECT UPPER(LEFT("ASSET DMZR", 12)) AS asset12,
               CASE WHEN COUNT(DISTINCT UPPER("CODE BUSINESS APPLICATION")) = 1
                        THEN MIN("CODE BUSINESS APPLICATION")
                    ELSE 'ERROR_MULTIPLE_CODES_APP'
               END AS code
        FROM travail_table
        WHERE UPPER("COST CENTER CALCULE") = 'TOTBAS'
        GROUP BY UPPER(LEFT("ASSET DMZR", 12));
    CREATE INDEX ON tmp_m1 (asset12);

    -- 2) code par database (égalité exacte, NA ignoré) côté TOTBAS
    DROP TABLE IF EXISTS tmp_m2;
    CREATE TEMP TABLE tmp_m2 AS
        SELECT UPPER("MZR DATABASE NAME") AS db,
               CASE WHEN COUNT(DISTINCT UPPER("CODE BUSINESS APPLICATION")) = 1
                        THEN MIN("CODE BUSINESS APPLICATION")
                    ELSE 'ERROR_MULTIPLE_CODES_APP'
               END AS code
        FROM travail_table
        WHERE UPPER("COST CENTER CALCULE") = 'TOTBAS'
          AND "MZR DATABASE NAME" IS NOT NULL
          AND UPPER("MZR DATABASE NAME") <> 'NA'
        GROUP BY UPPER("MZR DATABASE NAME");
    CREATE INDEX ON tmp_m2 (db);

    SELECT min(id), max(id) INTO lo, dernier FROM travail_table;
    IF lo IS NULL THEN
        RAISE NOTICE 'travail_table est vide, rien à faire';
        RETURN;
    END IF;

    WHILE lo <= dernier LOOP
        hi := lo + batch_size - 1;

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
          LEFT JOIN tmp_m1 m1 ON m1.asset12 = UPPER(LEFT(w0."ASSET DMZR", 12))
          LEFT JOIN tmp_m2 m2 ON m2.db = UPPER(w0."MZR DATABASE NAME")
                             AND UPPER(w0."MZR DATABASE NAME") <> 'NA'
         WHERE w0.id = w.id
           AND w.id BETWEEN lo AND hi;

        COMMIT;
        RAISE NOTICE 'calc_unique_identifier : ids % à % traités', lo, LEAST(hi, dernier);
        lo := hi + 1;
    END LOOP;

    DROP TABLE tmp_m1;
    DROP TABLE tmp_m2;

    RAISE NOTICE 'CODE BUSINESS APPLICATION CORRIGE mis à jour : % lignes',
        (SELECT count(*) FROM travail_table WHERE "CODE BUSINESS APPLICATION CORRIGE" IS NOT NULL);
END;
$$;
