-- Procédure 4 : alimentation de COST CENTER CALCULE dans travail_table.
--   CALL calc_cost_center();
-- Pré-requis : travail_table alimentée par alimente_travail().
--
-- Résolution depuis t_business_application : jointure case-insensitive
-- entre "Unique identifier" et le CODE BUSINESS APPLICATION de la ligne.
-- Sans correspondance -> NO_COST_CENTER.

CREATE OR REPLACE PROCEDURE calc_cost_center()
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE travail_table w
       SET "COST CENTER CALCULE" = COALESCE(ba.cc, 'NO_COST_CENTER')
      FROM travail_table w2
      -- t_business_application dédupliquée : 1 ligne par identifiant
      LEFT JOIN (
          SELECT UPPER("Unique identifier") AS uid, MIN("Cost center") AS cc
          FROM t_business_application
          GROUP BY UPPER("Unique identifier")
      ) ba ON ba.uid = UPPER(w2."CODE BUSINESS APPLICATION")
     WHERE w2.id = w.id;

    RAISE NOTICE 'COST CENTER CALCULE alimenté : % lignes (dont % NO_COST_CENTER)',
        (SELECT count(*) FROM travail_table WHERE "COST CENTER CALCULE" IS NOT NULL),
        (SELECT count(*) FROM travail_table WHERE "COST CENTER CALCULE" = 'NO_COST_CENTER');
END;
$$;
