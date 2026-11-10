# Herramientas de prueba de los portes de Administración

- `prueba_rama.sh <correo> <clave>`: recorre por HTTP los catálogos de Administración (Index, Listar con uso, Editar) contra la app en `http://localhost:5199`. `EXTRA="Cliente Area ..."` añade catálogos opcionales.
- `prueba_http.sh <cookiejar>`: pruebas de la Fase 0 (alta/edición/filtros de los catálogos opcionales, Feriado, Prioridad, Material).
- `hashclave/`: imprime el hash de una clave para poner en una **copia** de BD de prueba. `dotnet run -- <clave>` = PBKDF2 (formato nuevo); `dotnet run -- <clave> sha` = formato heredado (eulen, caja_arequipa).

Arranque de la app contra una copia: `create database X template Y;` en el contenedor `bdpostgresql` (5432), luego
`ConnectionStrings__AMSYS_PG="Host=localhost;Port=5432;Database=X;..." dotnet run --project AMSYS.WebAdmin --urls http://localhost:5199`.
