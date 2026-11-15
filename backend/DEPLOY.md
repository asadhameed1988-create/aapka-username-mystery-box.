# Backend deployment (Phase 6)

Yeh folder game ka online server hai: API, database, mission generation aur admin dashboard.

## Kya test ho chuka hai
- 9 automated tests SQLite aur asli PostgreSQL 16 dono par pass (`python3 -m pytest -q tests`).
- `migrations/001_init.sql` PostgreSQL 16 par saaf chalti hai.
- Tests mein missions asli Godot engine se nikale gaye hain (`tests/fixtures/missions.json`).

## Kya test NAHIN hua
- Docker image ka build, aur official Godot binary se `tools/server_generate.gd` ka chalna
  (yahan official Godot download nahin ho saka). Pehli deployment par yeh command chala kar dekhein:
      docker compose exec api /opt/godot/godot --headless --path /srv/game -s res://tools/server_generate.gd -- /tmp/t.json 3 12345
      docker compose exec api cat /tmp/t.json
- Asli internet par load, HTTPS setup.
- Email se password reset abhi nahin bana (us ke liye email bhejne wali service chahiye).

## Kharcha
Software sab muft aur open-source hai (FastAPI, PostgreSQL, Godot). Paisa in cheezon par lagta hai:
VPS/server (mahana), domain name (salana), aur zyada players hon to bandwidth/storage.
Chhota VPS (1-2 GB RAM) shuru ke liye kaafi hai. Qeematein provider ki website par dekhein.

## Qadam (Ubuntu VPS, Docker ke saath)
1. Server par Docker install karein, phir poora project folder upload karein.
2. `cd backend` aur `cp .env.example .env`
3. `.env` mein SECRET_KEY, POSTGRES_PASSWORD aur ADMIN_PASSWORD bharein (lambi random values).
   Yeh values kabhi chat mein paste na karein.
4. Dockerfile mein GODOT_URL ko godotengine.org ke archive se mila kar check karein.
5. `docker compose up -d --build`
6. Check: `curl http://127.0.0.1:8000/health` ka jawab `{"ok":true}` hona chahiye.
7. Domain ke saath HTTPS lagayen (Caddy sab se aasan hai):
       api.aapkadomain.com {
           reverse_proxy 127.0.0.1:8000
       }
8. Admin dashboard: https://api.aapkadomain.com/admin (ADMIN_USER / ADMIN_PASSWORD). Sirf HTTPS par kholein.

## Missions khud kaise bante hain
- BACKGROUND_WORKER=1 ho to server har 30 minute mein khud: aaj aur kal ka daily, is hafte ke 5 weekly,
  aur har level ka pool (default 20) bana deta hai. Ek pass mein zyada se zyada `max_generate_per_run` (default 60).
- Agar koi player daily mange aur woh abhi na bana ho to usi waqt ban jata hai.
- Admin mein kisi mission ko "Disable" karein to agli request par us ki jagah naya ban jata hai.
- Generator fail ho to game ko 503 milta hai aur game apna local daily sandooq istemal karta hai.
- Cron se chalana ho to: `docker compose exec api python -m app.worker`

## Cheating se bachao (abhi)
Server har mission ka kam se kam mumkin waqt janta hai; us se tez result reject hota hai, ek player ka sirf
pehla result gina jata hai, aur band mission par result nahin liya jata. Poora replay check (server par
player ki chaalein dobara chalana) baad ka kaam hai.

## Backup
    docker compose exec db pg_dump -U mystery mystery_box > backup.sql
