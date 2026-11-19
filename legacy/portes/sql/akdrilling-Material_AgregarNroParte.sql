START TRANSACTION;


DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261116161935_Material_AgregarNroParte') THEN
    ALTER TABLE material ADD nroparte character varying(100);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261116161935_Material_AgregarNroParte') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20261116161935_Material_AgregarNroParte', '8.0.11');
    END IF;
END $EF$;
COMMIT;

