# Trabajo por ramas en el legacy

Estado al 2026-10-31. Repo `D:\Documentos\Alphamanufacturas\AMSYS\AMSYS`, remoto `origin` = GitHub `jsulca/AMSYS`.

## Modelo

- `main` es el producto base. Cada cliente es una **rama de larga vida** con su propia base de datos, sus
  migraciones EF y su `appsettings.json` (diagnóstico completo en `legacy/planes/PLAN-MULTICLIENTE.md` §1).
- Ramas: agchavin, akdrilling, ares, caja_arequipa, energiaycombustion, eulen, main, oterra, pyme.
  `itc` y `rentanor` se borraron el 2026-10-31 (ya no son clientes; respaldo en `clientes/ex/`).
  Una ficha por rama en `clientes/`.
- Las mejoras de `main` **no llegan solas** a los clientes: hay que portarlas.

## Antes de trabajar en una rama

1. `git fetch` y comparar la rama local con `origin/<rama>` (al 2026-10-31 la local `oterra` estaba atrasada).
2. Leer `clientes/<rama>.md`.
3. Confirmar a qué base apunta `appsettings.Development.json` (localhost vs servidor). No commitear ese cambio.

## Portar desde `main` a una rama de cliente

Modelo: `legacy/portes/PORTE-UI-MAIN-AGCHAVIN.md`.

1. Crear `legacy/portes/PORTE-<QUÉ>-MAIN-<CLIENTE>.md` con estado, siguientes pasos, checklist de pruebas, "qué se
   hizo" y "no portado (y por qué)".
2. Portar archivo por archivo respetando lo propio del cliente (campos extra, estados renombrados, módulos).
3. Migraciones: generar la del cliente en su rama; aplicar en localhost; para el servidor, generar el script **solo
   de esa migración** (`dotnet ef migrations script <anterior> -p AMSYS.Contextos -s AMSYS.WebAdmin -o migracion.sql`).
   Aplicarla en producción es decisión del propietario.
4. Compilar sin errores, probar en el navegador, commit en la rama del cliente.
5. Anotar en la ficha del cliente (bitácora) y en `ESTADO.md`.

## Archivos locales que no se versionan

En `.git/info/exclude` (vale para todas las ramas): `CLAUDE.md` (puente a este cerebro), `ai/`, `.idea/`.
