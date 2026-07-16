-- Procédure 4 : calcul de CODE BUSINESS APPLICATION CORRIGE, ligne par ligne.
--   CALL calc_unique_identifier();
-- Pré-requis : travail_table alimentée par alimente_travail().
--
-- Règles rules.md — comparaisons insensibles à la casse, les conditions
-- TOTBAS s'évaluent sur le COST CENTER résolu depuis t_business_application :
--
--   (APSQL ou APORA) + COST CENTER différent de TOTBAS :
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
DECLARE
    r        RECORD;
    v_uic    TEXT;
    v_code1  TEXT;   -- résultat lookup 1) via asset
    v_cnt1   INT;
    v_code2  TEXT;   -- résultat lookup 2) via database
    v_cnt2   INT;
BEGIN
    FOR r IN SELECT * FROM travail_table LOOP

        IF UPPER(r."CODE BUSINESS APPLICATION") = 'NA' THEN
            -- Règle NA
            v_uic := 'APNOCODE_' || r."OFFRE" || '_' || r."METRIQUE DE SERVICE CODE";

        ELSIF UPPER(r."CODE BUSINESS APPLICATION") IN ('APSQL', 'APORA')
          AND UPPER(r."COST CENTER CALCULE") <> 'TOTBAS' THEN
            -- Règle (APSQL ou APORA) + cost center différent de TOTBAS
            -- 1) lookup via asset (12 premiers caractères) côté TOTBAS
            SELECT COUNT(DISTINCT UPPER(t."CODE BUSINESS APPLICATION")),
                   MIN(t."CODE BUSINESS APPLICATION")
              INTO v_cnt1, v_code1
              FROM travail_table t
             WHERE UPPER(t."COST CENTER CALCULE") = 'TOTBAS'
               AND UPPER(LEFT(t."ASSET DMZR", 12)) = UPPER(LEFT(r."ASSET DMZR", 12));
            IF v_cnt1 > 1 THEN
                v_code1 := 'ERROR_MULTIPLE_CODES_APP';
            ELSIF v_cnt1 = 0 THEN
                v_code1 := NULL;
            END IF;

            -- 2) lookup via database (égalité exacte, NA ignoré) côté TOTBAS
            IF r."MZR DATABASE NAME" IS NULL OR UPPER(r."MZR DATABASE NAME") = 'NA' THEN
                v_code2 := NULL;
            ELSE
                SELECT COUNT(DISTINCT UPPER(t."CODE BUSINESS APPLICATION")),
                       MIN(t."CODE BUSINESS APPLICATION")
                  INTO v_cnt2, v_code2
                  FROM travail_table t
                 WHERE UPPER(t."COST CENTER CALCULE") = 'TOTBAS'
                   AND UPPER(t."MZR DATABASE NAME") = UPPER(r."MZR DATABASE NAME");
                IF v_cnt2 > 1 THEN
                    v_code2 := 'ERROR_MULTIPLE_CODES_APP';
                ELSIF v_cnt2 = 0 THEN
                    v_code2 := NULL;
                END IF;
            END IF;

            -- Combinaison
            IF v_code1 IS NULL AND v_code2 IS NULL THEN
                v_uic := r."CODE BUSINESS APPLICATION";
            ELSIF v_code1 IS NULL THEN
                v_uic := v_code2;
            ELSIF v_code2 IS NULL THEN
                v_uic := v_code1;
            ELSIF UPPER(v_code1) = UPPER(v_code2) THEN
                v_uic := v_code1;
            ELSE
                v_uic := 'ERROR_MULTIPLE_CODES_APP';
            END IF;

        ELSE
            -- Règle par défaut
            v_uic := r."CODE BUSINESS APPLICATION";
        END IF;

        UPDATE travail_table
           SET "CODE BUSINESS APPLICATION CORRIGE" = UPPER(v_uic)
         WHERE id = r.id;

    END LOOP;

    RAISE NOTICE 'CODE BUSINESS APPLICATION CORRIGE mis à jour : % lignes',
        (SELECT count(*) FROM travail_table WHERE "CODE BUSINESS APPLICATION CORRIGE" IS NOT NULL);
END;
$$;
