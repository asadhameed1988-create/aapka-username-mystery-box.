# Release guide (Phase 10): APK aur AAB banana

Yeh kaam aap ke computer par Godot 4.7.2 mein hoga. APK/AAB is project ke saath NAHIN bane hue;
jahan yeh project likha gaya wahan Android build mumkin nahin tha.

## 0. Sab se tez raasta: sirf test APK (baghair ads plugin ke)
Preset "Android APK (quick test, no ads)" Gradle ke baghair banta hai, is liye is ke liye sirf qadam 1 ke 1-3 chahiyen.
- Windows: `build_apk_windows.bat` ko Notepad mein khol kar Godot ka path theek karein, phir double-click karein.
  APK `build\mystery_box_quick.apk` mein banegi. (Yeh script kabhi chalayi nahin gayi; error aaye to bhej dein.)
- Computer ke baghair: project ko GitHub repository mein daal kar Actions > "Build test APK" chalayen
  (`.github/workflows/build-apk.yml`). Yeh workflow bhi kabhi chala nahin; pehli baar error aa sakta hai.
Is APK mein ads aur purchases nahin honge (un ke liye Gradle wale presets aur plugins chahiyen).

## 1. Ek baar ki tayyari (computer)
1. Godot 4.7.2 Standard install karein, project Import karein, images import hone dein.
2. Editor > Manage Export Templates > Download and Install.
3. Android Studio (ya sirf command-line tools) se Android SDK install karein, aur OpenJDK 17.
   Godot: Editor > Editor Settings > Export > Android mein "Java SDK Path" aur "Android SDK Path" set karein.
   (Agar Godot koi aur JDK version mange to Godot ki "Exporting for Android" docs dekhein.)
4. Project > Install Android Build Template (Gradle build ke liye zaroori; ads aur billing plugins isi par chalte hain).
5. Ads aur purchases chahiyen to docs/MONETIZATION.md ke mutabiq dono plugins install aur enable karein.
6. Online khel chahiye to server live kar ke `scripts/net/Online.gd` mein DEFAULT_SERVER_URL mein HTTPS address likhein.

## 2. Signing key (bohat ahem)
Release key ek baar banti hai aur hamesha wohi istemal hoti hai. Yeh gum ho jaye to app update nahin ho sakti
(Play App Signing on ho to Google se upload key reset karwai ja sakti hai).

    keytool -genkeypair -v -keystore mysterybox-release.keystore -alias mysterybox -keyalg RSA -keysize 2048 -validity 10000

- Keystore file aur passwords ko project folder se BAHAR mehfooz jagah rakhein, aur backup banayen.
- Yeh file ya passwords kabhi chat, email ya ZIP mein na bhejein.
- Godot: Project > Export > preset > Keystore mein Release path, user (alias) aur password likhein.
  Godot inhein `.godot/export_credentials.cfg` mein rakhta hai, jo ZIP mein shamil nahin karni chahiye.

## 3. Test APK
1. Project > Export > "Android APK (testing)" > Export Project.
2. APK phone par install kar ke yeh sab dekhein: touch, awaaz aur music, Urdu, har qisam ka taala, chapters,
   Low graphics, internet band kar ke khel, phone ghumana/app chhor kar wapas aana (Continue).
3. Plugins lage hon to: test ads (interstitial har 4 sandooq baad, rewarded), consent form, test purchase.

## 4. Play Store ke liye AAB
1. Dono presets mein `version/code` har upload par 1 barhayen (1, 2, 3 ...), `version/name` jaise "1.0.0".
2. Package name `com.freegamesstation.mysterybox` hai. Publish se PEHLE chahein to badal lein; baad mein nahin badalta.
3. Project > Export > "Android AAB (Google Play)" > Export Project (Export With Debug OFF).
4. Play Console: Create app > Internal testing par AAB upload > testers ke saath check > phir Closed/Production.
5. Play Console target API level ya kisi aur cheez par warning de to wohi follow karein; yeh qawaid har saal badalte hain.

## 5. Deployment checklist
- [ ] Game phone par shuru se aakhir tak khela gaya (kam se kam 20 sandooq, har chapter ka pehla sandooq)
- [ ] `tests/batch_test.gd` computer par chalaya: `godot --headless --path . -s tests/batch_test.gd` (RESULT: PASS)
- [ ] Music aur awaazein sun kar theek lagin
- [ ] Journal ke tareekhi notes kisi mustanad zariye se check kiye
- [ ] Batch 2 ki backgrounds lagin (ya library wali background par razi hain)
- [ ] ADS_REAL aur asli AdMob IDs sirf release build mein; test ke dauran test ads
- [ ] Server live, HTTPS, admin password mazboot, DEFAULT_SERVER_URL set (ya online band rakhna tay kiya)
- [ ] Privacy policy web par publish aur us ka link Play Console aur game ke andar
- [ ] Account/data delete karne ka web link (Play ki shart) tayyar
- [ ] Data safety form, content rating, ads declaration bhara
- [ ] Store listing: icon 512, feature graphic 1024x500, kam se kam 2 phone screenshots
- [ ] Keystore ka backup mehfooz jagah
