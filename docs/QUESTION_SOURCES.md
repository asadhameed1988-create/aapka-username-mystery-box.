# Questions – sources, counts and review status

Three sections, each with endless chapters of 10 boxes (3 questions per box):

| Section | Different questions | Made from |
|---|---|---|
| Islamic knowledge | 722,169 | 72 hand-written (fiqh Hanafi, seerah) + Quran facts + Hijri months |
| General knowledge | 2,360,512 | 58 hand-written (Pakistan) + facts about 193 countries |
| Maths | unlimited | generated sums and equations, 5 levels (harder every 2 chapters) |

No repeats: `scripts/pcg/QuestionDeck.gd` walks every template through a fixed shuffle,
so a question comes back only after every question of its template has been asked.

## Generated question templates
Islamic (`QuizGenerator.gd`, data `QuranData.gd` = npm quran-meta 7.0.0, MIT, Hafs riwaya,
114 surahs, 6236 ayahs; checked against known values such as Al-Baqarah 286 ayahs and
Ya-Sin beginning in para 22):
surah by number, number of a surah, ayah count, surah after / before, para (juz) where a
surah begins, Hijri month after / by number, "which of three surahs comes first",
"which has the most / fewest ayahs" (ties are skipped). Makki/Madani questions are NOT used
because some surahs are classified differently by scholars.

General knowledge (data `CountryData.gd` = npm world-countries 5.1.0, data under ODbL):
capital of a country, country of a capital, continent (transcontinental countries skipped),
land neighbour (only borders both countries list), landlocked country, largest / smallest
of three by area (only when the winner is at least 20% bigger / smaller).
193 UN member states; Israel is left out because Pakistan does not recognise it.
Population questions are only in the hand-written bank (they change; census year is named).
Regenerate the data with `tools/make_question_data.py`.

Rules used when writing the questions
- Only well-established facts. No disputed or controversial matters.
- Fiqh questions follow the Hanafi school.
- No pictures of Prophets, Companions or holy people; no Quranic text drawn on objects.
- Honorifics: ﷺ for the Prophet Muhammad, (AS) / علیہ السلام for Prophets, (RA) / رضی اللہ عنہ for Companions.

## IMPORTANT – review before public release
These questions were written by an AI assistant and checked against the sources below.
Before the game is published, a qualified Hanafi scholar (Mufti / Alim) should read every
Islamic question and answer in both English and Urdu. This review has NOT been done yet.

## Source keys (the `src` field of each question)

| key | what it covers | source |
|---|---|---|
| fiqh | number of daily prayers, fard rak'ahs, Jumu'ah, Hajj month, Eid dates, Adhan, Tarawih | Standard Hanafi texts (Nur al-Idah, Mukhtasar al-Quduri); agreed by all four schools |
| hanafi_wudu | 4 fard acts of wudu (face, arms to elbows, masah of a quarter of the head, feet to ankles) | Quran 5:6; islamqa.org/hanafi/muftionline/129942 ; seekersguidance.org (Hanafi Fiqh) |
| hanafi_ghusl | 3 fard acts of ghusl (mouth, nose, whole body) | islamqa.org/hanafi/askimam/29027 ; Darul Ifta Deoband via islamqa.org/hanafi/darulifta-deoband/24681 ; Fatawa Hindiyya (quoted on qibla.com) |
| hanafi_witr | Witr is wajib, 3 rak'ahs with one salam | seekersguidance.org – "The Hadiths on the Witr Prayer According to the Hanafi Legal School"; daruliftabirmingham.co.uk fatwa 08780 |
| hanafi_fatiha | Reciting Al-Fatiha in salah is wajib in the Hanafi school | Hanafi usul (Hidayah); summarised in Mukhtasar al-Quduri commentaries |
| hanafi_sahw | Sajda-e-Sahw for a wajib missed by mistake | Nur al-Idah, chapter on Sujud al-Sahw |
| hanafi_zakat | Zakat on savings = 2.5% (one fortieth) | Hanafi texts; agreed by all schools |
| quran | number of Surahs (114), Juz (30), first/last/longest/shortest Surah, Ayat al-Kursi (2:255) | quran.com |
| quran_2_185 | Ramadan, Quran revealed in Ramadan | Quran 2:185 (quran.com/2/185) |
| quran_97 | Laylat al-Qadr better than a thousand months | Quran 97:3 |
| quran_112 | Surah Al-Ikhlas – Oneness of Allah | Quran 112 |
| quran_2_144 | Facing the Kaaba (Masjid al-Haram) in prayer | Quran 2:144 |
| quran_2_127 | Ibrahim and Ismail (AS) raised the foundations of the Kaaba | Quran 2:127 |
| quran_2_97 | Jibreel (AS) brought the revelation | Quran 2:97 |
| quran_tayammum | Tayammum with clean earth | Quran 5:6, 4:43 |
| quran_11, quran_37 | Nuh (AS) and the Ark; Yunus (AS) and the fish; Ibrahim (AS) and the sacrifice | Quran 11:37; 37:139-144; 37:102-107 |
| quran_4_163, quran_5_46 | Zabur to Dawood (AS); Injeel to Isa (AS) | Quran 4:163; 5:46 |
| quran_33_40 | The Prophet Muhammad ﷺ is the Seal of the Prophets | Quran 33:40 |
| quran_62 | Jumu'ah (Friday) prayer | Quran 62:9 |
| bukhari_3, bukhari_seerah | First revelation in Cave Hira; age 40 | Sahih al-Bukhari 3 (sunnah.com/bukhari:3); Seerah books |
| hadith_pillars | Islam is built on five | Sahih al-Bukhari 8 (sunnah.com/bukhari:8) |
| seerah | Birth in Makkah, Hijrah to Madinah, Cave Thawr, Badr, Khandaq, parents, Khadijah (RA), Zamzam, Masjid an-Nabawi, Masjid al-Aqsa | Standard Seerah (e.g. Ar-Raheeq Al-Makhtum) |
| history | Khulafa-e-Rashideen, Bilal (RA), Khalid bin Walid (RA), Hijri calendar, Imam Abu Hanifa (Nu'man bin Thabit) | Standard Islamic history books |
| pbs | Pakistan 2023 census: 241.49 million; Punjab most populous; Balochistan largest by area; Karachi largest city | Pakistan Bureau of Statistics, 7th Population and Housing Census 2023 (pbs.gov.pk) |
| un_pop | World population about 8 billion (reached Nov 2022) | United Nations |
| constitution | Urdu national language; four provinces | Constitution of Pakistan (Art. 251, Art. 1) |
| gk | Capitals, national symbols, planets, time units, geography | Common reference facts |

Population figures change; the questions say "about" and name the census year.
Update the world-population and Pakistan-population questions after the next census or UN revision.
