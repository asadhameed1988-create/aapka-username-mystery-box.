extends RefCounted
## Static game content: chapters, achievements and mystery-journal notes.
## Chapter boxes are NOT hand-made levels: each one is a fixed seed that the
## procedural generator turns into a mission (see MissionService.chapter_mission).

const BOXES_PER_CHAPTER := 10
const UNLOCK_NEEDED := 7   # boxes of the previous chapter needed to open the next one

const CHAPTERS := [
	{"id": 1, "en": "Baghdad - House of Wisdom", "ur": "بغداد - بیت الحکمت", "backdrop": "house_of_wisdom",
		"levels": [1, 1, 1, 2, 1, 2, 2, 2, 2, 3]},
	{"id": 2, "en": "Damascus - The Craftsman's Workshop", "ur": "دمشق - کاریگر کی دکان", "backdrop": "damascus_workshop",
		"levels": [2, 2, 2, 3, 2, 3, 3, 3, 3, 3]},
	{"id": 3, "en": "Cordoba - The Great Library", "ur": "قرطبہ - عظیم کتب خانہ", "backdrop": "cordoba_library",
		"levels": [3, 3, 3, 3, 4, 3, 4, 4, 4, 4]},
	{"id": 4, "en": "Cairo - The Old Bazaar", "ur": "قاہرہ - قدیم بازار", "backdrop": "cairo_bazaar",
		"levels": [4, 4, 4, 4, 4, 5, 4, 5, 5, 5]},
	{"id": 5, "en": "Samarkand - The Observatory", "ur": "سمرقند - رصد گاہ", "backdrop": "samarkand_observatory",
		"levels": [5, 5, 5, 5, 5, 5, 5, 5, 5, 5]},
]

## "stat" names are resolved by MissionService.stat().
const ACHIEVEMENTS := [
	{"id": "first_box", "stat": "solved", "need": 1, "en": "First Lock", "ur": "پہلا تالا", "desc": "ach_solved"},
	{"id": "boxes_10", "stat": "solved", "need": 10, "en": "Apprentice", "ur": "شاگرد", "desc": "ach_solved"},
	{"id": "boxes_50", "stat": "solved", "need": 50, "en": "Journeyman", "ur": "کاریگر", "desc": "ach_solved"},
	{"id": "boxes_100", "stat": "solved", "need": 100, "en": "Master Locksmith", "ur": "استاد قفل ساز", "desc": "ach_solved"},
	{"id": "clean_5", "stat": "no_hint", "need": 5, "en": "Clear Mind", "ur": "صاف ذہن", "desc": "ach_no_hint"},
	{"id": "clean_25", "stat": "no_hint", "need": 25, "en": "Unaided", "ur": "بغیر مدد", "desc": "ach_no_hint"},
	{"id": "swift", "stat": "fast", "need": 1, "en": "Swift Hands", "ur": "تیز ہاتھ", "desc": "ach_fast"},
	{"id": "types_5", "stat": "types", "need": 5, "en": "Curious", "ur": "متجسس", "desc": "ach_types"},
	{"id": "types_13", "stat": "types", "need": 13, "en": "Every Mechanism", "ur": "ہر مشین", "desc": "ach_types"},
	{"id": "daily_3", "stat": "daily_best", "need": 3, "en": "Three Days", "ur": "تین دن", "desc": "ach_daily"},
	{"id": "daily_7", "stat": "daily_best", "need": 7, "en": "A Full Week", "ur": "پورا ہفتہ", "desc": "ach_daily"},
	{"id": "chapter_1", "stat": "chapter:1", "need": 10, "en": "Scholar of Baghdad", "ur": "بغداد کا عالم", "desc": "ach_chapter"},
	{"id": "chapter_2", "stat": "chapter:2", "need": 10, "en": "Craftsman of Damascus", "ur": "دمشق کا کاریگر", "desc": "ach_chapter"},
	{"id": "chapter_3", "stat": "chapter:3", "need": 10, "en": "Librarian of Cordoba", "ur": "قرطبہ کا کتب دار", "desc": "ach_chapter"},
	{"id": "chapter_4", "stat": "chapter:4", "need": 10, "en": "Merchant of Cairo", "ur": "قاہرہ کا تاجر", "desc": "ach_chapter"},
	{"id": "chapter_5", "stat": "chapter:5", "need": 10, "en": "Astronomer of Samarkand", "ur": "سمرقند کا فلکیات دان", "desc": "ach_chapter"},
]

## A note opens when `need` boxes of its chapter are complete.
const JOURNAL := [
	{"chapter": 1, "need": 1,
		"en_title": "The House of Wisdom", "ur_title": "بیت الحکمت",
		"en": "In 9th-century Baghdad the House of Wisdom was a great library and translation centre. Scholars there gathered books from many lands and turned them into Arabic.",
		"ur": "نویں صدی کے بغداد میں بیت الحکمت ایک عظیم کتب خانہ اور ترجمے کا مرکز تھا۔ وہاں کے علما مختلف ملکوں کی کتابیں جمع کر کے عربی میں منتقل کرتے تھے۔"},
	{"chapter": 1, "need": 5,
		"en_title": "The Banu Musa Brothers", "ur_title": "بنو موسیٰ برادران",
		"en": "Three brothers of Baghdad wrote the Book of Ingenious Devices in the 9th century. It describes about a hundred clever machines, many of them trick vessels and self-working fountains.",
		"ur": "بغداد کے تین بھائیوں نے نویں صدی میں کتاب الحیل لکھی۔ اس میں تقریباً سو ہوشیار مشینوں کا بیان ہے، جن میں بہت سے حیرت انگیز برتن اور خودکار فوارے ہیں۔"},
	{"chapter": 2, "need": 1,
		"en_title": "The Inlay of Damascus", "ur_title": "دمشق کی پچی کاری",
		"en": "Damascus craftsmen were famous for wooden boxes inlaid with mother-of-pearl and for metal decorated with fine gold and silver lines.",
		"ur": "دمشق کے کاریگر لکڑی کے ایسے صندوقوں کے لیے مشہور تھے جن میں سیپ جڑی ہوتی تھی، اور ایسی دھات کے لیے جس پر سونے چاندی کی باریک لکیروں سے نقش بنے ہوتے تھے۔"},
	{"chapter": 2, "need": 5,
		"en_title": "Al-Jazari's Lock", "ur_title": "الجزری کا تالا",
		"en": "In 1206 the engineer al-Jazari finished his Book of Knowledge of Ingenious Mechanical Devices. Among its machines is a box locked by dials that must be set to the right combination.",
		"ur": "1206 میں انجینئر الجزری نے اپنی مشہور کتاب مکمل کی جس میں حیرت انگیز مشینوں کا بیان ہے۔ ان میں ایک ایسا صندوق بھی ہے جو ڈائلوں کو درست ترتیب پر لانے سے کھلتا ہے۔"},
	{"chapter": 3, "need": 1,
		"en_title": "The Library of Cordoba", "ur_title": "قرطبہ کا کتب خانہ",
		"en": "In the 10th century the library of the caliph al-Hakam II in Cordoba was said to hold hundreds of thousands of books, one of the largest collections of its age.",
		"ur": "دسویں صدی میں قرطبہ کے خلیفہ الحکم ثانی کے کتب خانے کے بارے میں کہا جاتا ہے کہ اس میں لاکھوں کتابیں تھیں، جو اپنے دور کے سب سے بڑے ذخیروں میں سے ایک تھا۔"},
	{"chapter": 3, "need": 5,
		"en_title": "The Astrolabe", "ur_title": "اصطرلاب",
		"en": "An astrolabe is a brass instrument of turning plates used to find the positions of stars and to tell the time. In 11th-century al-Andalus, al-Zarqali designed one that worked at any latitude.",
		"ur": "اصطرلاب پیتل کا ایک آلہ ہے جس کی گھومتی پلیٹوں سے ستاروں کا مقام اور وقت معلوم کیا جاتا تھا۔ گیارہویں صدی کے اندلس میں الزرقالی نے ایسا اصطرلاب بنایا جو ہر عرض بلد پر کام کرتا تھا۔"},
	{"chapter": 4, "need": 1,
		"en_title": "The Book of Optics", "ur_title": "کتاب المناظر",
		"en": "Working in Cairo in the 11th century, Ibn al-Haytham wrote the Book of Optics. He showed by experiment that we see because light travels from objects into the eye.",
		"ur": "گیارہویں صدی میں قاہرہ میں ابن الہیثم نے کتاب المناظر لکھی۔ انہوں نے تجربے سے ثابت کیا کہ ہم اس لیے دیکھتے ہیں کہ روشنی چیزوں سے آنکھ تک پہنچتی ہے۔"},
	{"chapter": 4, "need": 5,
		"en_title": "Girih Patterns", "ur_title": "گرہ کے نقوش",
		"en": "Girih are star-and-polygon patterns drawn with only a compass and a straight edge. Craftsmen repeated a few simple shapes to cover walls, doors and boxes without gaps.",
		"ur": "گرہ ستاروں اور کثیر الاضلاع شکلوں کے وہ نقوش ہیں جو صرف پرکار اور سیدھے پیمانے سے بنائے جاتے ہیں۔ کاریگر چند سادہ شکلیں دہرا کر دیواریں، دروازے اور صندوق بغیر خالی جگہ کے سجا دیتے تھے۔"},
	{"chapter": 5, "need": 1,
		"en_title": "Al-Khwarizmi", "ur_title": "الخوارزمی",
		"en": "The 9th-century scholar al-Khwarizmi wrote a book on solving equations whose title gave us the word algebra. The word algorithm comes from his own name.",
		"ur": "نویں صدی کے عالم الخوارزمی نے مساوات حل کرنے پر ایک کتاب لکھی جس کے عنوان سے لفظ الجبرا نکلا۔ لفظ الگورتھم خود ان کے نام سے بنا ہے۔"},
	{"chapter": 5, "need": 5,
		"en_title": "Ulugh Beg's Observatory", "ur_title": "الغ بیگ کی رصد گاہ",
		"en": "In the 1420s Ulugh Beg built a great observatory in Samarkand. His astronomers measured the positions of about a thousand stars with remarkable accuracy.",
		"ur": "1420 کی دہائی میں الغ بیگ نے سمرقند میں ایک عظیم رصد گاہ بنوائی۔ ان کے ماہرینِ فلکیات نے تقریباً ایک ہزار ستاروں کے مقامات غیر معمولی درستی سے ناپے۔"},
]


static func chapter(id: int) -> Dictionary:
	for c in CHAPTERS:
		if int(c["id"]) == id:
			return c
	return CHAPTERS[0]
