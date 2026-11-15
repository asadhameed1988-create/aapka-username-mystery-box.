# Play Store material (Phase 10)

## Listing text
- **App name (30 huroof tak):** `Mystery Box: Unlock Unknown` (27). Poora naam "Mystery Box: Unlock the Unknown" 31 huroof ka hai, 1 zyada.
  "Mystery Box" ek aam naam hai; Play Store par search kar ke dekh lein ke kisi mashhoor app se takrao na ho.
- **Short description (80 tak):** `Open ancient Arabian puzzle boxes: 13 kinds of locks, endless new mysteries.` (76)
- **Full description:**

      Step into the workshops and libraries of the old Arab world and open boxes that were built to keep secrets.

      Every box is sealed by clever locks: astrolabe rings, dial combinations, sliding plates, gears, mirrors and light,
      mazes with hidden keys, colour codes and symbol ciphers. Turn the box, study the clues and release each lock.

      - 13 kinds of mechanical and logic locks
      - Endless Mystery mode: new boxes are created for you, forever, even offline
      - 5 chapters from Baghdad to Samarkand, 50 boxes
      - Daily and weekly challenges with leaderboards (optional online play)
      - A mystery journal with short notes on real history
      - Fair hints, no timers that punish you, no ads while you are solving
      - English and Urdu

      Every puzzle is checked by the game before you see it, so there is always a solution.

  (Sirf wohi features likhein jo aap ke release build mein on hon; maslan server live na ho to leaderboards wali line hata dein.)

## Graphics
| Cheez | Size | File |
| --- | --- | --- |
| App icon | 512 x 512 PNG | assets/icon/play_store_icon_512.png |
| Feature graphic | 1024 x 500 | Batch 2 ka MB-015 (abhi banana hai) |
| Phone screenshots | kam se kam 2, portrait | apne phone se: menu, ek taala, khula sandooq, chapters |

## Data safety form (game ke code ke mutabiq; bharne se pehle Google ki hidayat se mila lein)
| Data | Kab | Maqsad | Ikhtiyari? |
| --- | --- | --- | --- |
| User ID (random player number) | Online khel on ho | App functionality | Online band kar sakte hain |
| Name (display name) | Player khud likhe | Leaderboard | Haan |
| Email address | Sirf register karne par | Account management | Haan |
| App activity (progress, results, in-app events) | Online / statistics on ho | Functionality, analytics | Haan |
| App performance (FPS, device model, OS) | Statistics on ho | Analytics | Haan |
| Device or other IDs (advertising ID) | Ads SDK (AdMob) | Advertising | Google ki settings se |
| Purchase history | Google Play ke zariye | Purchases | - |

- Data transit mein encrypted: haan, agar server HTTPS par hai (lazmi rakhein).
- Data delete karwane ka tareeqa: game ke andar (Profile and Privacy) aur ek web link (Play ki shart).
- AdMob SDK kya data leta hai, us ke liye Google ka apna "Data safety" guidance page dekh kar form bharein.

## Content rating aur ads
- Content rating questionnaire: puzzle game, tashaddud nahin, users ke darmiyan chat nahin (leaderboard par sirf naam).
- "Contains ads": Yes (agar AdMob laga hai). "In-app purchases": Yes (agar products banaye hain).
- Target audience: bachon ko shamil karne se pehle Play ki Families policy aur AdMob ke qawaid parh lein.
