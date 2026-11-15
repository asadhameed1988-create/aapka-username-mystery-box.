# Monetization setup (Phase 8)

Game ka ads aur purchases wala code tayyar hai, lekin yeh hissa sirf asli Android phone par chal sakta hai.
Jab tak neeche wale plugins install na hon, game baghair ads aur baghair dukaan ke bilkul theek chalta hai.

## Kya test ho chuka hai, kya nahin
- TEST HUA (engine mein, naqli ad provider ke saath): ads ke tamam qawaid, rewarded ka inaam aur rozana had,
  purchase ka inaam sirf ek baar milna, pending payment par inaam na milna, "remove ads" ke baad interstitial band.
- TEST NAHIN HUA: asli AdMob aur Google Play Billing plugin ke saath chalna. `AdmobProvider.gd` aur
  `PlayBillingProvider.gd` ke tamam naam plugins ke apne source code se parh kar likhe gaye hain
  (godot-admob commit 83d7144, 2026-11-03; godot-google-play-billing master, 2026-07-26), magar phone par kabhi nahin chale.

## Plugins (dono MIT licence, muft)
| Kaam | Plugin | Folder |
| --- | --- | --- |
| Ads | godot-sdk-integrations/godot-admob, release v7.0 (Godot 4.7 par tested likha hai) | addons/AdmobPlugin |
| Purchases | godot-sdk-integrations/godot-google-play-billing, release 3.x (Godot 4.2+) | addons/GodotGooglePlayBilling |

Install: Godot Editor > AssetLib mein naam se dhoond kar Download/Install, phir
Project > Project Settings > Plugins mein dono ko Enable karein.
(Admob: "Ignore asset root" CHECKED rakhein. Billing: "Ignore asset root" UNCHECKED rakhein. Yeh un ki apni docs mein likha hai.)
Android export mein "Use Gradle Build" on hona zaroori hai, aur Admob plugin Android 6.0 (min SDK 23) mangta hai.

## Ads ke qawaid jo code mein hain (scripts/monetize/Ads.gd)
- Puzzle ke dauran kabhi ad nahin. Interstitial sirf do sandooqon ke darmiyan, "Next Box" dabane par.
- Naye player ke pehle 3 sandooqon mein koi interstitial nahin; phir har 4 sandooq baad (server config se badal sakta hai),
  aur do ads ke darmiyan kam se kam 2 minute.
- Rewarded ad sirf tab chalta hai jab player khud button dabaye: +3 hint tokens, din mein zyada se zyada 5 baar.
- Hints sirf game ke andar ke liye hain: na paise, na kisi ko transfer.
- "Remove ads" khareedne par interstitial band; rewarded ad ikhtiyari hai is liye rehta hai.
- Ad band hone ki khabar na aaye to 2 minute baad game khud aage barh jata hai (atakta nahin).
- Players se consent (ijazat) ka form Google ka UMP system khud dikhata hai jahan qanoon mangta ho.

## AdMob set karna
1. https://admob.google.com par account banayen, app add karein, 2 ad units banayen: Interstitial aur Rewarded.
2. `scripts/monetize/AdmobProvider.gd` mein ADMOB_APP_ID, ADMOB_INTERSTITIAL_ID, ADMOB_REWARDED_ID likhein.
3. `addons/AdmobPlugin/android_export.cfg` file banayen (plugin ki docs ke mutabiq):

       [General]
       is_real = false

       [Debug]
       app_id = "ca-app-pub-3940256099942544~3347511713"

       [Release]
       app_id = "APNA-ADMOB-APP-ID"

4. Pehle TEST ads ke saath phone par check karein (ADS_REAL = false). Apne asli ads par khud click na karein;
   is se AdMob account band ho sakta hai.
5. Release build ke liye ADS_REAL = true aur cfg mein is_real = true karein.
6. AdMob IDs raaz nahin hote (app ke andar hi hote hain), lekin AdMob account ka password kabhi chat mein na likhein.

## Purchases set karna
1. Play Console > Monetize > Products > In-app products mein do products banayen, IDs bilkul yehi:
   `remove_ads` (ek baar ki khareedari) aur `hint_pack_20` (bar bar khareeda ja sakta hai).
2. Purchases sirf us build mein chalti hain jo Play Console (internal testing) par upload ho, aur tester account se.
3. Qeemat game Play Store se khud le kar button par dikhata hai.

## Zaroori kaam publish se pehle
- Privacy policy mein likhna hoga ke app ads dikhata hai (Google AdMob) aur gumnaam statistics bhejta hai.
- Play Console ke Data safety form mein ads SDK ka data (jaise advertising ID) declare karna hoga.
- App ko bachon ke liye ("Designed for Families") mark karne se pehle AdMob aur Play ki maujooda policies parh lein;
  un ke qawaid alag hain.
- AdMob aur Google Play ki policies badalti rehti hain. Release se pehle un ke official pages dobara dekh lein.

## Analytics
Game gumnaam ginti bhejta hai (session, sandooq mukammal, ad dikha, inaam, khareedari, performance) sirf jab online
khel on ho aur Profile mein "Anonymous usage statistics" on ho. Admin dashboard > Analytics mein rozana active players,
naye players, agle din wapsi aur events nazar aate hain. Ads ki asal kamai sirf AdMob console mein dikhti hai.

## Abhi nahin bana
- Premium puzzle packs aur sponsorship: dhancha maujood hai (Store.PRODUCTS mein naya product), content nahin bana.
- Server par purchase ki tasdeeq (receipt verification).
- Naqd inaam ya paise wale muqable: yeh qanooni aur policy review ke baghair nahin banenge.
