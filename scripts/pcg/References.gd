extends RefCounted
## References shown with Islamic questions: an Arabic line (surah and ayah numbers, or the
## book) and the same in English / Urdu. Only references are shown, never the text of an
## ayah, so the Holy Quran is never quoted inexactly. Surah names come from QuranData.

const Quran = preload("res://scripts/pcg/QuranData.gd")

## key -> list of [surah, first ayah, last ayah] (0, 0 = the whole surah)
const QURAN := {
	"quran_2_185": [[2, 185, 185]], "quran_2_183": [[2, 183, 185]], "quran_97": [[97, 1, 3]],
	"quran_112": [[112, 0, 0]], "quran_2_144": [[2, 144, 144]], "quran_2_127": [[2, 127, 127]],
	"quran_2_97": [[2, 97, 97]], "quran_tayammum": [[5, 6, 6], [4, 43, 43]], "quran_11": [[11, 37, 37]],
	"quran_37_102": [[37, 102, 107]], "quran_37_139": [[37, 139, 144]], "quran_4_163": [[4, 163, 163]],
	"quran_5_46": [[5, 46, 46]], "quran_2_53": [[2, 53, 53]], "quran_33_40": [[33, 40, 40]],
	"quran_62": [[62, 9, 9]], "quran_2_255": [[2, 255, 255]], "quran_12_2": [[12, 2, 2]],
	"hanafi_wudu": [[5, 6, 6]],
}

## key -> [Arabic, English, Urdu] for books.
const BOOKS := {
	"fiqh": ["نور الإيضاح؛ مختصر القدوري (الفقه الحنفي)", "Nur al-Idah; Mukhtasar al-Quduri (Hanafi fiqh)", "نور الایضاح؛ مختصر القدوری (فقہ حنفی)"],
	"hanafi_witr": ["الهداية، باب صلاة الوتر؛ نور الإيضاح", "Al-Hidayah, chapter on Witr; Nur al-Idah", "الہدایہ، باب الوتر؛ نور الایضاح"],
	"hanafi_wudu": ["مختصر القدوري، كتاب الطهارة", "Mukhtasar al-Quduri, Book of Purification", "مختصر القدوری، کتاب الطہارت"],
	"hanafi_ghusl": ["مختصر القدوري، كتاب الطهارة (فرائض الغسل)", "Mukhtasar al-Quduri, Book of Purification (fard acts of ghusl)", "مختصر القدوری، کتاب الطہارت (غسل کے فرائض)"],
	"hanafi_sahw": ["نور الإيضاح، باب سجود السهو", "Nur al-Idah, chapter on Sajda-e-Sahw", "نور الایضاح، باب سجدۂ سہو"],
	"hanafi_fatiha": ["نور الإيضاح، واجبات الصلاة", "Nur al-Idah, wajib acts of salah", "نور الایضاح، نماز کے واجبات"],
	"hanafi_zakat": ["مختصر القدوري، كتاب الزكاة (ربع العشر)", "Mukhtasar al-Quduri, Book of Zakat (one fortieth)", "مختصر القدوری، کتاب الزکوٰۃ (چالیسواں حصہ)"],
	"hadith_pillars": ["صحيح البخاري، الحديث ٨", "Sahih al-Bukhari, hadith 8", "صحیح بخاری، حدیث 8"],
	"bukhari_3": ["صحيح البخاري، الحديث ٣ (بدء الوحي)", "Sahih al-Bukhari, hadith 3 (beginning of revelation)", "صحیح بخاری، حدیث 3 (آغازِ وحی)"],
	"bukhari_seerah": ["صحيح البخاري، كتاب مناقب الأنصار، باب مبعث النبي ﷺ", "Sahih al-Bukhari, Book of the Merits of the Ansar, chapter on the Prophet's ﷺ mission", "صحیح بخاری، کتاب مناقب الانصار، باب بعثتِ نبوی ﷺ"],
	"seerah": ["الرحيق المختوم", "Ar-Raheeq Al-Makhtum (Seerah)", "الرحیق المختوم (سیرت)"],
	"history": ["تاريخ الخلفاء للسيوطي؛ سير أعلام النبلاء للذهبي", "Tarikh al-Khulafa (as-Suyuti); Siyar A'lam an-Nubala (adh-Dhahabi)", "تاریخ الخلفاء (سیوطی)؛ سیر اعلام النبلاء (ذہبی)"],
	"mushaf": ["المصحف الشريف (رواية حفص عن عاصم): ١١٤ سورة، ٣٠ جزءًا", "The Mushaf (Hafs from 'Asim): 114 surahs, 30 paras", "مصحف شریف (روایتِ حفص عن عاصم): 114 سورتیں، 30 پارے"],
}

const HIJRI_AR := ["محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"]


static func ar_digits(n: int) -> String:
	var out: String = ""
	for ch in str(n):
		out += "٠١٢٣٤٥٦٧٨٩"[int(ch)] if ch >= "0" and ch <= "9" else ch
	return out


static func surah_ar(num: int) -> String:
	return str(Quran.SURAHS[num - 1][1])


static func surah_en(num: int) -> String:
	return str(Quran.SURAHS[num - 1][0])


## One Quran reference as [Arabic, English, Urdu].
static func quran_ref(num: int, a: int, b: int) -> Array:
	if a == 0:
		return ["سورة %s (%s)" % [surah_ar(num), ar_digits(num)],
			"Holy Quran, Surah %s (%d)" % [surah_en(num), num],
			"قرآن مجید، سورۃ %s (%d)" % [surah_ar(num), num]]
	if a == b:
		return ["سورة %s، الآية %s" % [surah_ar(num), ar_digits(a)],
			"Holy Quran, Surah %s %d:%d" % [surah_en(num), num, a],
			"قرآن مجید، سورۃ %s، آیت %d" % [surah_ar(num), a]]
	return ["سورة %s، الآيات %s–%s" % [surah_ar(num), ar_digits(a), ar_digits(b)],
		"Holy Quran, Surah %s %d:%d-%d" % [surah_en(num), num, a, b],
		"قرآن مجید، سورۃ %s، آیات %d تا %d" % [surah_ar(num), a, b]]


## A surah's facts from the verified data: number, ayahs, para where it begins.
static func surah_facts(num: int) -> Array:
	var ayahs: int = int(Quran.SURAHS[num - 1][2])
	var juz: int = int(Quran.SURAHS[num - 1][3])
	return ["سورة %s: رقمها %s، آياتها %s، تبدأ في الجزء %s" % [surah_ar(num), ar_digits(num), ar_digits(ayahs), ar_digits(juz)],
		"Surah %s: number %d, %d ayahs, begins in para %d" % [surah_en(num), num, ayahs, juz],
		"سورۃ %s: نمبر %d، آیات %d، پارہ %d سے شروع" % [surah_ar(num), num, ayahs, juz]]


## Joins several [ar, en, ur] lines into one.
static func _join(lines: Array) -> Dictionary:
	var ar: PackedStringArray = []
	var en: PackedStringArray = []
	var ur: PackedStringArray = []
	for l in lines:
		ar.append(str(l[0]))
		en.append(str(l[1]))
		ur.append(str(l[2]))
	return {"ar": "\n".join(ar), "en": "\n".join(en), "ur": "\n".join(ur)}


## Reference for a bank question's "src" key ({} if it has none, e.g. general knowledge).
static func for_key(key: String) -> Dictionary:
	var lines: Array = []
	if QURAN.has(key):
		for r in QURAN[key]:
			lines.append(quran_ref(int(r[0]), int(r[1]), int(r[2])))
	if BOOKS.has(key):
		lines.append(BOOKS[key])
	return {} if lines.is_empty() else _join(lines)


## Reference for generated Quran / Hijri questions.
static func for_surahs(nums: Array) -> Dictionary:
	var lines: Array = []
	for n in nums:
		lines.append(surah_facts(int(n)))
	lines.append(BOOKS["mushaf"])
	return _join(lines)


static func for_hijri() -> Dictionary:
	return _join([["الأشهر الهجرية بالترتيب: " + "، ".join(PackedStringArray(HIJRI_AR)),
		"Islamic (Hijri) months in order: Muharram, Safar, Rabi-ul-Awwal, Rabi-us-Sani, Jumada-al-Ula, Jumada-al-Akhirah, Rajab, Shaban, Ramadan, Shawwal, Dhul-Qadah, Dhul-Hijjah",
		"اسلامی مہینے ترتیب سے: محرم، صفر، ربیع الاول، ربیع الثانی، جمادی الاولیٰ، جمادی الآخرہ، رجب، شعبان، رمضان، شوال، ذوالقعدہ، ذوالحجہ"],
		["سورة التوبة، الآية ٣٦", "Holy Quran, Surah At-Tawbah 9:36 (twelve months)", "قرآن مجید، سورۃ التوبہ، آیت 36 (بارہ مہینے)"]])
