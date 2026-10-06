# Auth API + Data API (Spring Boot, Docker Compose)

```
client ──> auth-api :8080 ──(X-Internal-Token)──> data-api :8081
               │
               └──> postgres (users, processing_log)
```

* **auth-api** – register/login (BCrypt + JWT HS256), protected `POST /api/process`, writes `processing_log`. Schema is created by Flyway (`auth-api/src/main/resources/db/migration/V1__init.sql`).
* **data-api** – `POST /api/transform` (reverse + uppercase). Any request without a valid `X-Internal-Token` gets **403**.
* All three containers share the `app-net` network; auth-api reaches data-api at `http://data-api:8081`.

## Run

Requirements: Docker + Docker Compose (Maven/JDK on the host are optional).

```bash
docker compose up -d --build
```

The Dockerfiles build the jars themselves (multi-stage), so the host `mvn ... package` step is not required.
If you prefer to build on the host first, it still works:

```bash
mvn -f auth-api/pom.xml clean package -DskipTests
mvn -f data-api/pom.xml clean package -DskipTests
```

Config is via env vars (defaults in `docker-compose.yml` are for local dev only). To override, copy `.env.example` to `.env`:
`POSTGRES_DB/USER/PASSWORD`, `JWT_SECRET` (>= 32 chars), `INTERNAL_TOKEN`.

## Test (bash)

```bash
# 1) register -> 201
curl -i -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" -d '{"email":"a@a.com","password":"pass"}'

# 2) login -> 200 {"token":"..."}
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" -d '{"email":"a@a.com","password":"pass"}' \
  | sed -E 's/.*"token":"([^"]+)".*/\1/')

# 3) process -> {"result":"OLLEH"}
curl -s -X POST http://localhost:8080/api/process \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"text":"hello"}'

# 4) no/invalid JWT -> 401
curl -i -X POST http://localhost:8080/api/process -H "Content-Type: application/json" -d '{"text":"hello"}'

# 5) data-api without internal token -> 403
curl -i -X POST http://localhost:8081/api/transform -H "Content-Type: application/json" -d '{"text":"hello"}'

# 6) data-api with the token -> 200 (default dev token shown)
curl -s -X POST http://localhost:8081/api/transform -H "X-Internal-Token: dev-internal-token-change-me" \
  -H "Content-Type: application/json" -d '{"text":"hello"}'

# 7) verify the log row
docker compose exec postgres psql -U app -d appdb \
  -c "select user_id, input_text, output_text, created_at from processing_log;"
```

Windows PowerShell/cmd: use `curl.exe` and escape inner quotes (`"{\"email\":\"a@a.com\",\"password\":\"pass\"}"`), or put the JSON in a file and use `-d @body.json`.

## Notes

* Passwords are stored as BCrypt hashes; passwords, JWTs and the internal token are never logged.
* Spring Boot's auto-generated default password is disabled (a stub `UserDetailsService` is defined).
* Error mapping: bad input 400, duplicate email 409, bad login / missing JWT 401, data-api failure 502.
* Stop / reset: `docker compose down` (add `-v` to drop the database volume).
