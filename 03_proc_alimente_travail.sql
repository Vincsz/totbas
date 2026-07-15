-- Procédure 3 : alimentation de la table de travail, en deux phases.
--   CALL alimente_travail();
--
-- PHASE 1 : copie import_table -> travail_table.
--   COST CENTER pris dans t_business_application (jointure case-insensitive
--   "Unique identifier" = CODE BUSINESS APPLICATION) ; sans correspondance
--   -> NO_COST_CENTER. UNIQUE IDENTIFIER CALCULE laissé à NULL.
--
-- PHASE 2 : parcours de travail_table ligne par ligne, UPDATE de
--   UNIQUE IDENTIFIER CALCULE selon les règles rules.md.
--   Les lookups s'appuient sur travail_table (donc sur le COST CENTER
--   rafraîchi en phase 1). Comparaisons insensibles à la casse.
--
-- Règles :
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

CREATE OR REPLACE PROCEDURE alimente_travail()
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
    ------------------------------------------------------------------
    -- PHASE 1 : copie + COST CENTER depuis t_business_application
    ------------------------------------------------------------------
    TRUNCATE travail_table;

    INSERT INTO travail_table (
        id, "CODE BUSINESS APPLICATION", "COST CENTER",
        "METRIQUE DE SERVICE CODE", "OFFRE", "ASSET DMZR",
        "MZR DATABASE NAME", "VOLUME", "PRIX", "COMPTE DMZR LABEL",
        "ENVIRONNEMENT", "ANNEE", "MOIS", "UNIQUE IDENTIFIER CALCULE"
    )
    SELECT
        i.id,
        i."CODE BUSINESS APPLICATION",
        COALESCE(ba.cc, 'NO_COST_CENTER'),
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
        NULL
    FROM import_table i
    -- t_business_application dédupliquée : 1 ligne par identifiant
    LEFT JOIN (
        SELECT UPPER("Unique identifier") AS uid, MIN("Cost center") AS cc
        FROM t_business_application
        GROUP BY UPPER("Unique identifier")
    ) ba ON ba.uid = UPPER(i."CODE BUSINESS APPLICATION");

    ------------------------------------------------------------------
    -- PHASE 2 : calcul de UNIQUE IDENTIFIER CALCULE ligne par ligne
    ------------------------------------------------------------------
    FOR r IN SELECT * FROM travail_table LOOP

        IF UPPER(r."CODE BUSINESS APPLICATION") = 'NA' THEN
            -- Règle NA
            v_uic := 'APNOCODE_' || r."OFFRE" || '_' || r."METRIQUE DE SERVICE CODE";

        ELSIF UPPER(r."CODE BUSINESS APPLICATION") IN ('APSQL', 'APORA')
          AND UPPER(r."COST CENTER") <> 'TOTBAS' THEN
            -- Règle (APSQL ou APORA) + cost center différent de TOTBAS
            -- 1) lookup via asset (12 premiers caractères) côté TOTBAS
            SELECT COUNT(DISTINCT UPPER(t."CODE BUSINESS APPLICATION")),
                   MIN(t."CODE BUSINESS APPLICATION")
              INTO v_cnt1, v_code1
              FROM travail_table t
             WHERE UPPER(t."COST CENTER") = 'TOTBAS'
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
                 WHERE UPPER(t."COST CENTER") = 'TOTBAS'
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
           SET "UNIQUE IDENTIFIER CALCULE" = UPPER(v_uic)
         WHERE id = r.id;

    END LOOP;

    RAISE NOTICE 'Table de travail alimentée : % lignes',
        (SELECT count(*) FROM travail_table);
END;
$$;
