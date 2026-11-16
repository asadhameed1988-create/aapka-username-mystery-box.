# Online server lagana (leaderboard, daily/weekly online, progress backup)

Kharcha: dono services ke free plan. Render ka free server 15 minute khali rehne par so jata hai;
pehli request par 30-60 second lagte hain (game is dauran offline chalta rehta hai).

## 1. Database (Neon, free)
1. https://neon.tech par "Sign up" (GitHub se login kar sakte hain).
2. "Create project": naam `mystery-box`, region: Asia (Singapore).
3. "Connection string" copy karein (postgresql://... se shuru hoti hai).
   Yeh password wali line hai: kisi chat mein na bhejein.

## 2. Server (Render, free)
1. https://render.com par GitHub se login karein.
2. "New" > "Blueprint" > repository `aapka-username-mystery-box.` chunen > "Apply".
3. Render `DATABASE_URL` maangega: Neon wali connection string wahan paste karein.
4. Build 10-15 minute leta hai. Phir server ka address milega, jaise
   `https://mystery-box-api.onrender.com`.
5. Browser mein `.../health` kholen: `{"ok": true}` jaisa jawab aana chahiye.

## 3. Game ko server se jorna
Server ka address (sirf address, password nahin) Claude ko bhej dein. Woh
`scripts/net/Online.gd` mein `DEFAULT_SERVER_URL` bhar kar nayi build bana dega.

## Admin panel
`https://<server>/admin` – user `owner`, password Render dashboard > Environment > ADMIN_PASSWORD
mein milega (Render ne khud banaya hai).
