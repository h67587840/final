extends Node2D

# 晨曦王國的守護者們
# 八關對應三年級自然上、下學期各四個單元
# 角色造型全部用程式繪製（原創），不需要任何圖片檔

const GRID_W := 12
const GRID_H := 8
const TILE := 64
const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

enum Phase { IDLE, MOVING, ATTACKING, ENEMY_TURN, GAME_OVER, DIALOGUE, QUIZ }

var map_rows: Array[String] = []

# cost = -1 代表無法通行；def = 站在上面的防禦加成
var terrain := {
	".": {"name": "草地", "cost": 1, "def": 0, "color": Color(0.25, 0.4, 0.25)},
	"F": {"name": "森林", "cost": 2, "def": 1, "color": Color(0.18, 0.33, 0.2)},
	"M": {"name": "山地", "cost": -1, "def": 0, "color": Color(0.35, 0.33, 0.3)},
	"W": {"name": "水", "cost": -1, "def": 0, "color": Color(0.2, 0.35, 0.65)},
}

# 我方出場順序；每一關出場人數（隨劇情逐步加入夥伴）
var roster_order := ["swordsman", "archer", "brawler", "sorcerer", "knight", "archmage", "dragoon", "robot"]
var roster_count := [3, 4, 5, 6, 7, 8, 8, 8]
var spawn_cells := [
	Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 4), Vector2i(0, 5),
	Vector2i(2, 3), Vector2i(1, 1), Vector2i(0, 2), Vector2i(2, 5),
]

# 職業資料表：who 角色名、name 職業名
# magic：用魔防計算傷害　fly：無視地形　terrain_cost：覆寫特定地形的移動消耗
var classes := {
	"swordsman": {"who": "賽恩", "name": "劍士", "hp": 24, "atk": 8, "def": 3, "res": 1, "move": 4, "min_range": 1, "range": 1, "magic": false, "fly": false, "terrain_cost": {}},
	"archer": {"who": "莉雅", "name": "弓箭手", "hp": 16, "atk": 7, "def": 1, "res": 1, "move": 4, "min_range": 2, "range": 2, "magic": false, "fly": false, "terrain_cost": {}},
	"brawler": {"who": "巴洛", "name": "拳擊手", "hp": 28, "atk": 9, "def": 2, "res": 0, "move": 4, "min_range": 1, "range": 1, "magic": false, "fly": false, "terrain_cost": {}},
	"sorcerer": {"who": "卡蓮", "name": "巫師", "hp": 15, "atk": 8, "def": 0, "res": 4, "move": 3, "min_range": 1, "range": 2, "magic": true, "fly": false, "terrain_cost": {}},
	"knight": {"who": "雷恩", "name": "騎士", "hp": 26, "atk": 8, "def": 5, "res": 1, "move": 5, "min_range": 1, "range": 1, "magic": false, "fly": false, "terrain_cost": {"F": 3}},
	"archmage": {"who": "米拉", "name": "大法師", "hp": 14, "atk": 10, "def": 0, "res": 5, "move": 3, "min_range": 1, "range": 3, "magic": true, "fly": false, "terrain_cost": {}},
	"dragoon": {"who": "薇菈", "name": "龍騎士", "hp": 22, "atk": 9, "def": 3, "res": 2, "move": 5, "min_range": 1, "range": 1, "magic": false, "fly": true, "terrain_cost": {}},
	"robot": {"who": "零號", "name": "機器人", "hp": 34, "atk": 8, "def": 6, "res": 6, "move": 2, "min_range": 1, "range": 1, "magic": false, "fly": false, "terrain_cost": {}},
	"goblin": {"who": "哥布林", "name": "哥布林", "hp": 14, "atk": 5, "def": 1, "res": 0, "move": 3, "min_range": 1, "range": 1, "magic": false, "fly": false, "terrain_cost": {}},
	"orc": {"who": "獸人", "name": "獸人", "hp": 24, "atk": 8, "def": 2, "res": 0, "move": 2, "min_range": 1, "range": 1, "magic": false, "fly": false, "terrain_cost": {}},
	"bandit_archer": {"who": "盜賊弓手", "name": "盜賊弓手", "hp": 12, "atk": 6, "def": 0, "res": 0, "move": 3, "min_range": 2, "range": 2, "magic": false, "fly": false, "terrain_cost": {}},
	"skeleton": {"who": "骷髏兵", "name": "骷髏兵", "hp": 16, "atk": 7, "def": 2, "res": 1, "move": 3, "min_range": 1, "range": 1, "magic": false, "fly": false, "terrain_cost": {}},
	"dark_mage": {"who": "暗黑法師", "name": "暗黑法師", "hp": 12, "atk": 8, "def": 0, "res": 3, "move": 3, "min_range": 1, "range": 2, "magic": true, "fly": false, "terrain_cost": {}},
	"wolf": {"who": "暗影狼", "name": "暗影狼", "hp": 14, "atk": 6, "def": 1, "res": 0, "move": 5, "min_range": 1, "range": 1, "magic": false, "fly": false, "terrain_cost": {}},
	"golem": {"who": "石魔像", "name": "石魔像", "hp": 32, "atk": 9, "def": 5, "res": 1, "move": 2, "min_range": 1, "range": 1, "magic": false, "fly": false, "terrain_cost": {}},
	"boss": {"who": "暗影領主", "name": "暗影領主", "hp": 44, "atk": 10, "def": 4, "res": 4, "move": 3, "min_range": 1, "range": 2, "magic": false, "fly": false, "terrain_cost": {}},
}

# 角色外觀（顏色）；造型細節在 _draw_character 裡
var looks := {
	"swordsman": {"skin": Color(1.0, 0.85, 0.7), "hair": Color(0.45, 0.25, 0.1), "outfit": Color(0.2, 0.4, 0.85), "trim": Color(0.95, 0.85, 0.3)},
	"archer": {"skin": Color(1.0, 0.86, 0.72), "hair": Color(0.9, 0.7, 0.2), "outfit": Color(0.2, 0.6, 0.3), "trim": Color(0.5, 0.3, 0.1)},
	"brawler": {"skin": Color(0.9, 0.7, 0.5), "hair": Color(0.1, 0.1, 0.1), "outfit": Color(0.85, 0.6, 0.25), "trim": Color(0.8, 0.1, 0.1)},
	"sorcerer": {"skin": Color(0.95, 0.85, 0.85), "hair": Color(0.15, 0.1, 0.25), "outfit": Color(0.1, 0.45, 0.5), "trim": Color(0.8, 0.9, 0.4)},
	"knight": {"skin": Color(1.0, 0.85, 0.7), "hair": Color(0.3, 0.2, 0.1), "outfit": Color(0.75, 0.78, 0.85), "trim": Color(0.85, 0.15, 0.15)},
	"archmage": {"skin": Color(1.0, 0.87, 0.75), "hair": Color(0.95, 0.95, 0.98), "outfit": Color(0.35, 0.3, 0.8), "trim": Color(0.95, 0.8, 0.3)},
	"dragoon": {"skin": Color(1.0, 0.85, 0.7), "hair": Color(0.8, 0.2, 0.1), "outfit": Color(0.7, 0.12, 0.15), "trim": Color(0.95, 0.8, 0.3)},
	"robot": {"skin": Color(0.7, 0.75, 0.8), "hair": Color(0.3, 0.3, 0.35), "outfit": Color(0.55, 0.6, 0.68), "trim": Color(0.3, 0.9, 1.0)},
	"goblin": {"skin": Color(0.45, 0.75, 0.3), "hair": Color(0.2, 0.2, 0.1), "outfit": Color(0.5, 0.35, 0.2), "trim": Color(0.3, 0.2, 0.1)},
	"orc": {"skin": Color(0.3, 0.55, 0.25), "hair": Color(0.1, 0.1, 0.1), "outfit": Color(0.45, 0.3, 0.2), "trim": Color(0.7, 0.7, 0.7)},
	"bandit_archer": {"skin": Color(0.95, 0.8, 0.65), "hair": Color(0.2, 0.15, 0.1), "outfit": Color(0.4, 0.28, 0.18), "trim": Color(0.2, 0.15, 0.1)},
	"skeleton": {"skin": Color(0.93, 0.92, 0.85), "hair": Color(0.9, 0.9, 0.9), "outfit": Color(0.45, 0.45, 0.5), "trim": Color(0.3, 0.3, 0.35)},
	"dark_mage": {"skin": Color(0.8, 0.78, 0.85), "hair": Color(0.1, 0.1, 0.1), "outfit": Color(0.35, 0.12, 0.45), "trim": Color(0.9, 0.3, 0.3)},
	"wolf": {"skin": Color(0.5, 0.5, 0.55), "hair": Color(0.3, 0.3, 0.35), "outfit": Color(0.42, 0.42, 0.48), "trim": Color(0.8, 0.2, 0.2)},
	"golem": {"skin": Color(0.5, 0.45, 0.4), "hair": Color(0.3, 0.3, 0.3), "outfit": Color(0.52, 0.48, 0.42), "trim": Color(1.0, 0.6, 0.1)},
	"boss": {"skin": Color(0.85, 0.8, 0.9), "hair": Color(0.2, 0.1, 0.3), "outfit": Color(0.25, 0.12, 0.35), "trim": Color(0.95, 0.8, 0.3)},
}

# 說話者名字 → 對話時顯示的大頭像
var speaker_look := {
	"賽恩": "swordsman", "莉雅": "archer", "巴洛": "brawler", "卡蓮": "sorcerer",
	"雷恩": "knight", "米拉": "archmage", "薇菈": "dragoon", "零號": "robot",
	"暗影領主": "boss",
}

var stages := [
	{
		"name": "翠綠森林",
		"map": [
			"..F....FF...",
			"....F...F..F",
			".F..FF......",
			"......F..FF.",
			".F...FF.F...",
			"....F.....F.",
			"..F...F..F..",
			"F....FF.....",
		],
		"enemies": [["goblin", Vector2i(9, 2)], ["goblin", Vector2i(9, 5)], ["goblin", Vector2i(10, 4)]],
		"intro": [
			{"who": "旁白", "text": "晨曦王國遭到暗影軍入侵，王都的守衛節節敗退。"},
			{"who": "賽恩", "text": "我是王國的劍士賽恩。邊境的翠綠森林已經被佔領了，我們要先把它奪回來！"},
			{"who": "莉雅", "text": "我是弓箭手莉雅。聽說暗影軍被打倒之後，還會再站起來……"},
			{"who": "巴洛", "text": "哈！那就把他們揍到爬不起來！"},
			{"who": "莉雅", "text": "沒用的啦。古書上說，只有答對自然科學的問題，才能徹底擊敗他們。"},
			{"who": "賽恩", "text": "那就用知識和力量一起戰鬥吧！出發！"},
		],
		"win": [
			{"who": "賽恩", "text": "翠綠森林奪回來了！"},
			{"who": "巴洛", "text": "原來動腦筋比揮拳還重要……不過揮拳也很重要。"},
		],
	},
	{
		"name": "磁石山道",
		"map": [
			"..FMM.MMMM..",
			"...M...M.MM.",
			"......MM....",
			"..F.........",
			"......MM....",
			"...M...M.MM.",
			"...MM.MMMM.F",
			"..FMM.MMM...",
		],
		"enemies": [["goblin", Vector2i(9, 2)], ["goblin", Vector2i(9, 4)], ["bandit_archer", Vector2i(11, 3)], ["orc", Vector2i(10, 3)]],
		"intro": [
			{"who": "旁白", "text": "穿過森林，隊伍來到崎嶇的磁石山道，暗影軍守住了狹窄的通道。"},
			{"who": "卡蓮", "text": "等一下！我是巫師卡蓮，我也想為王國出一份力，讓我加入吧！"},
			{"who": "賽恩", "text": "歡迎你，卡蓮！"},
		],
		"win": [
			{"who": "卡蓮", "text": "山道打通了，繼續前進吧。"},
		],
	},
	{
		"name": "風之高原",
		"map": [
			"............",
			"...M....M...",
			"............",
			".....M....M.",
			"............",
			"...M....M...",
			"............",
			".F........F.",
		],
		"enemies": [["goblin", Vector2i(9, 1)], ["orc", Vector2i(10, 2)], ["wolf", Vector2i(9, 3)], ["wolf", Vector2i(9, 5)], ["bandit_archer", Vector2i(11, 4)]],
		"intro": [
			{"who": "旁白", "text": "隊伍登上遼闊的風之高原，遠處傳來了馬蹄聲。"},
			{"who": "雷恩", "text": "我是王國騎士雷恩，奉命前來支援！"},
			{"who": "巴洛", "text": "太好了，又多了一個可靠的夥伴！"},
		],
		"win": [
			{"who": "雷恩", "text": "高原上的敵人都清除了，前方就是香料之城。"},
		],
	},
	{
		"name": "香料之城",
		"map": [
			"...MMMMMMMM.",
			"...M......M.",
			"......MM..M.",
			"...M..MM....",
			"...M........",
			"......MM..M.",
			"...M......M.",
			"...MMMMMMMM.",
		],
		"enemies": [["skeleton", Vector2i(8, 2)], ["skeleton", Vector2i(8, 5)], ["goblin", Vector2i(9, 3)], ["orc", Vector2i(10, 4)], ["dark_mage", Vector2i(9, 4)]],
		"intro": [
			{"who": "旁白", "text": "香料之城被暗影軍包圍，城門緊閉。"},
			{"who": "米拉", "text": "我是大法師米拉。城裡的人需要幫助，請讓我與你們同行。"},
			{"who": "賽恩", "text": "有大法師加入，我們更有信心了！"},
		],
		"win": [
			{"who": "米拉", "text": "香料之城重獲自由了。"},
		],
	},
	{
		"name": "田園之村",
		"map": [
			"..F...WW....",
			"......WW.F..",
			"F.....WW....",
			"............",
			"......WW.F..",
			".F....WW....",
			"......WW....",
			"..F......F..",
		],
		"enemies": [["skeleton", Vector2i(8, 2)], ["skeleton", Vector2i(8, 5)], ["wolf", Vector2i(9, 3)], ["orc", Vector2i(10, 2)], ["dark_mage", Vector2i(10, 4)], ["bandit_archer", Vector2i(11, 3)]],
		"intro": [
			{"who": "旁白", "text": "隊伍來到田園之村，村子被暗影軍團團圍住。"},
			{"who": "薇菈", "text": "我是龍騎士薇菈。我在天上看到了這裡的情況，讓我來幫忙！"},
			{"who": "莉雅", "text": "從天上來的援軍，太棒了！"},
		],
		"win": [
			{"who": "薇菈", "text": "村民們都平安了。前面的峽谷看起來很危險。"},
		],
	},
	{
		"name": "熔爐峽谷",
		"map": [
			"MM......MMMM",
			"...F..MM....",
			"......MM..F.",
			"..F.........",
			"......MM....",
			"...F..MM..F.",
			"......MM....",
			"MM......MMMM",
		],
		"enemies": [["orc", Vector2i(9, 2)], ["orc", Vector2i(9, 4)], ["dark_mage", Vector2i(10, 3)], ["dark_mage", Vector2i(9, 5)], ["skeleton", Vector2i(10, 1)], ["wolf", Vector2i(11, 3)]],
		"intro": [
			{"who": "旁白", "text": "熔爐峽谷裡，有一座古老的工坊還在運轉。"},
			{"who": "零號", "text": "偵測到友軍。我是零號，古代工坊的守衛機器人。請求加入戰鬥。"},
			{"who": "賽恩", "text": "歡迎加入，零號！"},
		],
		"win": [
			{"who": "零號", "text": "峽谷已清除。下一個目標：王都。"},
		],
	},
	{
		"name": "野獸之地",
		"map": [
			"..FFF..F.FF.",
			".FF..WW..F..",
			"F...FWW.....",
			"......F..WW.",
			".F.....F....",
			"...WW....FF.",
			"F..WW.F.....",
			"..FF....F...",
		],
		"enemies": [["golem", Vector2i(10, 4)], ["orc", Vector2i(9, 2)], ["orc", Vector2i(9, 5)], ["dark_mage", Vector2i(11, 3)], ["skeleton", Vector2i(8, 1)], ["skeleton", Vector2i(8, 4)], ["bandit_archer", Vector2i(11, 5)]],
		"intro": [
			{"who": "旁白", "text": "再往前，是暗影軍盤踞的野獸之地。穿過這裡，就能抵達王都。"},
			{"who": "賽恩", "text": "大家，最後一段路了！"},
			{"who": "卡蓮", "text": "大家的知識，一定會成為我們的力量。"},
		],
		"win": [
			{"who": "賽恩", "text": "王都就在眼前了！"},
		],
	},
	{
		"name": "暗影王都",
		"map": [
			"...F..MMMMMM",
			"......M....M",
			"..F...M.WW.M",
			"............",
			"......M.WW.M",
			"......M....M",
			"...F..MMMMMM",
			"F....F......",
		],
		"enemies": [["boss", Vector2i(10, 3)], ["golem", Vector2i(8, 3)], ["dark_mage", Vector2i(9, 1)], ["dark_mage", Vector2i(9, 5)], ["orc", Vector2i(7, 2)], ["orc", Vector2i(7, 4)], ["skeleton", Vector2i(10, 2)], ["skeleton", Vector2i(10, 4)]],
		"intro": [
			{"who": "旁白", "text": "暗影王都，王國的最後一道防線。"},
			{"who": "暗影領主", "text": "愚蠢的人類，你們再怎麼努力，也無法徹底擊敗我的軍隊。"},
			{"who": "莉雅", "text": "我們可以！只要答對問題，你們就會消失！"},
			{"who": "賽恩", "text": "為了晨曦王國，最後一戰！"},
		],
		"win": [
			{"who": "暗影領主", "text": "不可能……我竟然輸給了知識……"},
			{"who": "旁白", "text": "暗影軍消失了，晨曦王國終於恢復了和平。"},
			{"who": "賽恩", "text": "謝謝大家，我們做到了！"},
			{"who": "莉雅", "text": "這趟旅程，我們學到了好多。"},
		],
	},
]


# 題庫（康軒版三年級自然，八個單元對應八關）
# stage：這題屬於第幾關的單元（沒有題目的關卡會用其他單元的題目當複習）
# 每題只依據康軒版教案的學習目標／學習內容編寫，不延伸課外概念。
# exp 是答題後顯示的說明；note 是來源備註，供教師核對。
# 正式使用前，請教師對照課本與習作確認。
var quiz_bank := [
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "下列哪一項是生物？", "options": ["小草", "石頭", "空氣", "水"], "answer": 0, "exp": "自然環境中有生物，也有非生物；動物和植物都是生物。", "note": "INa-Ⅱ-1；教案：生物包括動物、植物"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "植物的外部形態主要由哪些部分組成？", "options": ["根、莖、葉、花、果實、種子", "根、莖、葉、翅膀、眼睛、嘴巴", "頭、身體、腳、尾巴", "殼、肉、腳、觸角"], "answer": 0, "exp": "植物的身體分成根、莖、葉、花、果實和種子。", "note": "INb-Ⅱ-6；活動1-2"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "觀察植物的葉子時，下列哪一項是可以拿來比較的特徵？", "options": ["葉脈", "年齡", "體重", "叫聲"], "answer": 0, "exp": "觀察葉子可以比較葉子的形狀、葉緣、葉脈和大小等特徵。", "note": "活動1-2：觀察比較葉子的特徵"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "葉子的邊緣有的圓滑、有的有鋸齒，葉子的邊緣叫做什麼？", "options": ["葉緣", "葉脈", "根", "果實"], "answer": 0, "exp": "葉子的邊緣叫做葉緣，有的圓滑，有的有鋸齒。", "note": "活動1-2：葉子有鋸齒或圓滑"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "葉子裡像網子或長條線的紋路，叫做什麼？", "options": ["葉脈", "葉緣", "花萼", "鬚根"], "answer": 0, "exp": "葉子裡像網子或長條線的紋路叫做葉脈。", "note": "活動1-2：葉子內部像網子或長條線"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "花的基本構造有哪些？", "options": ["花萼、花瓣、雄蕊、雌蕊", "根、莖、葉、果實", "花萼、花瓣、種子、果實", "軸根、鬚根、莖、葉"], "answer": 0, "exp": "花的基本構造由外而內依序有花萼、花瓣、雄蕊和雌蕊，可以幫助植物繁衍後代。", "note": "活動3-1 重點歸納"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "植物開花以後，會結出什麼？", "options": ["果實", "軸根", "葉脈", "花萼"], "answer": 0, "exp": "植物開花後會結果實，果實裡面有種子。", "note": "活動3-2 重點歸納"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "果實裡面有什麼？", "options": ["種子", "根", "花瓣", "葉脈"], "answer": 0, "exp": "植物開花後會結果實，果實裡面有種子。", "note": "活動3-2 重點歸納"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "植物的根有什麼功能？", "options": ["可以吸收水分，也能抓住土壤、固定植物", "可以開出美麗的花", "可以結出果實", "可以讓葉子變色"], "answer": 0, "exp": "根可以吸收水分，也能抓住土壤、固定植物。", "note": "活動2-3：根的功能"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "有一條較粗的主根，長在比較深的土裡，這種根叫做什麼？", "options": ["軸根", "鬚根", "果根", "葉根"], "answer": 0, "exp": "軸根有一條較粗的主根，生長在較深的土中。", "note": "活動2-3：軸根"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "細細小小、長得像鬍鬚的根，叫做什麼？", "options": ["鬚根", "軸根", "果根", "葉根"], "answer": 0, "exp": "鬚根細細小小，長得像鬍鬚，生長在較淺的土壤中。", "note": "活動2-3：鬚根"},
	{"stage": 1, "unit": "三上｜多采多姿的植物", "q": "下列哪一種說法是對的？", "options": ["一年四季都可以看到不同的花", "只有夏天看得到花", "只有春天看得到花", "冬天一定看不到花"], "answer": 0, "exp": "一年四季都可以看到不同的花。", "note": "活動3-1 重點歸納"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "兩塊磁鐵互相靠近時，會發生什麼情形？", "options": ["可能互相吸引，也可能互相排斥", "一定會互相吸引", "一定會互相排斥", "一定不會有任何現象"], "answer": 0, "exp": "磁鐵具有同極相斥、異極相吸的特性。", "note": "活動2-2：磁鐵的相吸、相斥"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "相同的磁極互相靠近時，會發生什麼情形？", "options": ["互相推斥", "互相吸引", "一點變化也沒有", "兩個磁鐵都變成鐵"], "answer": 0, "exp": "磁鐵同極相斥，異極相吸。", "note": "活動2-2"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "不同的磁極互相靠近時，會發生什麼情形？", "options": ["互相吸引", "互相推斥", "一點變化也沒有", "磁力全部消失"], "answer": 0, "exp": "磁鐵同極相斥，異極相吸。", "note": "活動2-2"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "磁鐵有兩種磁極，分別叫做什麼？", "options": ["N極和S極", "A極和B極", "上極和下極", "紅極和藍極"], "answer": 0, "exp": "磁極分為N極和S極。", "note": "活動2-2：磁極分為N極和S極"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "長條形磁鐵的哪個部位磁力比較強？", "options": ["兩端的磁極", "正中間", "每個地方都一樣強", "只有側面最強"], "answer": 0, "exp": "磁鐵兩端磁極的磁力最強。", "note": "活動2-2學習目標"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "要比較兩個磁鐵磁力的強弱，可以怎麼做？", "options": ["比較它們能吸住的迴紋針數量", "比較它們的顏色", "比較它們的名字", "比較它們的香味"], "answer": 0, "exp": "磁力越強，能吸住的迴紋針數量越多。", "note": "活動2-2：比較吸住迴紋針的數量"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "磁鐵的磁力強弱和磁鐵的大小有關嗎？", "options": ["沒有一定的關係，大的磁鐵不一定比較強", "越大的磁鐵，磁力一定越強", "越小的磁鐵，磁力一定越強", "磁鐵不論大小都沒有磁力"], "answer": 0, "exp": "磁鐵磁力強弱與磁鐵大小無關。", "note": "活動2-2學習目標"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "下列哪一個物品會被磁鐵吸住？", "options": ["迴紋針", "橡皮擦", "鉛筆", "色紙"], "answer": 0, "exp": "磁鐵可以吸引鐵製的物品，例如迴紋針。", "note": "活動2-1：磁鐵能吸引鐵製品"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "磁鐵可以隔著物品吸引鐵製品嗎？", "options": ["可以，磁鐵可以隔著物品吸引鐵製品", "不可以，一定要碰到才能吸引", "只能吸引塑膠", "不能吸引任何東西"], "answer": 0, "exp": "磁鐵可以隔著物品吸引鐵製品，生活中有很多應用。", "note": "活動2-3：磁鐵的妙用"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "用力踢球，球會飛出去；用力踩飲料罐，飲料罐會被踩扁。這說明了什麼？", "options": ["物體受力後，可能會改變運動情形或形狀", "物體受力後，一定會變成磁鐵", "物體受力後，一定會變成水", "物體受力後，什麼事都不會發生"], "answer": 0, "exp": "用力踢球，球會飛出去；用力踩飲料罐，飲料罐會被踩扁。", "note": "活動1-1：物體受力後的變化"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "水中的物品會受到水的什麼力？", "options": ["浮力", "磁力", "電力", "風力"], "answer": 0, "exp": "水具有浮力，可以讓船浮在水面上。", "note": "活動3-1：浮力"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "鐵做的東西本來會沉入水中，做成什麼形狀可以讓它浮在水面上？", "options": ["船的形狀", "一顆小鐵球", "一根細細的釘子", "一小塊鐵屑"], "answer": 0, "exp": "改變物體的形狀，會改變浮力的強弱，影響物體的浮沉。", "note": "活動3-1：改變物體形狀會改變浮力"},
	{"stage": 2, "unit": "三上｜生活中的力", "q": "水除了具有浮力，還能傳送什麼？", "options": ["動力", "磁力", "顏色", "重量"], "answer": 0, "exp": "水除了具有浮力，還能傳送動力。", "note": "單元課程目標"},
	{"stage": 3, "unit": "三上｜奇妙的空氣", "q": "空氣在哪裡？", "options": ["我們的四周到處都有空氣", "只有天空才有空氣", "只有水裡才有空氣", "只有房間裡才有空氣"], "answer": 0, "exp": "空氣無所不在，在我們周圍充滿了空氣。", "note": "活動1-1 重點歸納"},
	{"stage": 3, "unit": "三上｜奇妙的空氣", "q": "下列哪一項是空氣的特性？", "options": ["看不見也摸不著，沒有顏色和味道", "是紅色的", "有甜甜的味道", "有固定的形狀"], "answer": 0, "exp": "空氣看不見也摸不著，無色、無味。", "note": "活動1-1、1-2"},
	{"stage": 3, "unit": "三上｜奇妙的空氣", "q": "把裝有紙團的杯子倒過來，垂直壓入水中，再拿出來，杯底的紙團會怎麼樣？", "options": ["沒有溼", "全部溼掉", "變成冰塊", "不見了"], "answer": 0, "exp": "杯底的紙團沒有溼，因為杯子裡有空氣。", "note": "活動1-2：紙團杯實驗"},
	{"stage": 3, "unit": "三上｜奇妙的空氣", "q": "把裝有紙團的杯子倒過來壓入水中，杯底的紙團沒有溼。這說明了什麼？", "options": ["空氣占有空間，把水擋在杯子外面", "空氣是固體", "空氣會發光", "空氣有甜味"], "answer": 0, "exp": "空氣和其他物質一樣，占有空間。", "note": "活動1-2：空氣占有空間"},
	{"stage": 3, "unit": "三上｜奇妙的空氣", "q": "空氣有固定的形狀嗎？", "options": ["沒有固定的形狀", "有，像正方形", "有，像圓形", "有，永遠是三角形"], "answer": 0, "exp": "空氣沒有固定的形狀。", "note": "活動1-2、2-1"},
	{"stage": 3, "unit": "三上｜奇妙的空氣", "q": "空氣流動會形成什麼？", "options": ["風", "雨", "雪", "彩虹"], "answer": 0, "exp": "空氣流動產生風。", "note": "INd-Ⅱ-4；活動2"},
	{"stage": 3, "unit": "三上｜奇妙的空氣", "q": "我們呼吸需要什麼？", "options": ["空氣", "石頭", "磁鐵", "砂糖"], "answer": 0, "exp": "我們的呼吸需要空氣。", "note": "活動3-1：空氣的重要"},
	{"stage": 3, "unit": "三上｜奇妙的空氣", "q": "汙染的空氣會對我們造成什麼影響？", "options": ["會影響健康", "會讓人更健康", "對人完全沒有影響", "會讓植物發出香味"], "answer": 0, "exp": "汙染的空氣會影響健康。", "note": "活動3-2：空氣乾淨健康好"},
	{"stage": 3, "unit": "三上｜奇妙的空氣", "q": "「空氣品質指標」可以幫助我們知道什麼？", "options": ["空氣品質的好壞，並分成不同等級", "今天有幾隻鳥在飛", "磁鐵的磁力有多強", "水杯裡有多少水"], "answer": 0, "exp": "空氣品質指標把空氣品質分成不同的等級。", "note": "活動3-2：空氣品質指標的分級"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "下列哪一組都是廚房中常見的材料？", "options": ["砂糖、食鹽、麵粉", "石頭、磁鐵、鐵釘", "鉛筆、橡皮擦、色紙", "書本、直尺、膠帶"], "answer": 0, "exp": "廚房中常用的材料有砂糖、食鹽、小蘇打粉、檸檬酸粉和麵粉等。", "note": "活動1-1：廚房中常用的材料"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "觀察砂糖、食鹽這些細小的粉末時，可以使用什麼工具把它們看得更清楚？", "options": ["放大鏡", "磁鐵", "溫度計", "量筒"], "answer": 0, "exp": "放大鏡可以幫助我們把細小的東西看得更清楚。", "note": "活動1-1：使用放大鏡觀察"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "砂糖放進水裡攪拌，慢慢不見了，這種現象叫做什麼？", "options": ["溶解", "生長", "發芽", "浮起來"], "answer": 0, "exp": "砂糖在水中慢慢不見的現象叫做溶解。", "note": "活動1-2：材料會溶解在水中嗎"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "砂糖可以一直加進同一杯水裡，一直溶解下去嗎？", "options": ["不行，水能溶解的砂糖是有限的", "可以，一直都溶得完", "不行，因為砂糖會變成食鹽", "可以，水會越來越多"], "answer": 0, "exp": "砂糖的溶解有限度，不是無限的。", "note": "活動1-3：糖的溶解有極限"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "實驗時要量取一定量的水，可以使用什麼器材？", "options": ["量筒", "放大鏡", "磁鐵", "迴紋針"], "answer": 0, "exp": "量筒可以量取一定量的水。", "note": "單元概述：量測定量的水"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "量取水的量時，常用的單位是什麼？", "options": ["毫升", "公斤", "公尺", "度"], "answer": 0, "exp": "量取水的量，常用「毫升」作為單位。", "note": "單元概述：以毫升為單位的測量"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "水溶液依照性質，可以分成哪三種？", "options": ["酸性、中性、鹼性", "高、中、低", "紅、黃、藍", "大、中、小"], "answer": 0, "exp": "水溶液可以分成酸性、中性和鹼性。", "note": "活動2 設計理念"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "紫色高麗菜汁可以幫助我們做什麼？", "options": ["分辨水溶液的酸鹼性", "測量水的重量", "測量水的溫度", "把水變成冰"], "answer": 0, "exp": "紫色高麗菜汁會隨水溶液的酸鹼性改變顏色，可以幫助我們分辨水溶液。", "note": "活動2-2：顏色變變變"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "下列哪一種水溶液是酸性的？", "options": ["醋", "食鹽水", "砂糖水", "小蘇打水"], "answer": 0, "exp": "醋和檸檬酸水是酸性的；小蘇打水是鹼性的。", "note": "活動2-1、2-2"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "小蘇打水是哪一種性質的水溶液？", "options": ["鹼性", "酸性", "中性", "沒有性質"], "answer": 0, "exp": "小蘇打水是鹼性的水溶液。", "note": "活動2-1、2-2"},
	{"stage": 4, "unit": "三上｜廚房裡的科學", "q": "把紫色高麗菜汁分別加入下列水溶液，哪一種的顏色幾乎不會改變？", "options": ["食鹽水", "醋", "檸檬酸水", "小蘇打水"], "answer": 0, "exp": "加入食鹽水、砂糖水，紫色高麗菜汁不會變色。", "note": "活動2-2：重點歸納"},
	{"stage": 5, "unit": "三下｜田園樂", "q": "蔬菜生長需要哪些條件？", "options": ["陽光、空氣、水、土壤", "只需要砂糖", "只需要磁鐵", "只需要冰塊"], "answer": 0, "exp": "生物需要陽光、空氣、水和土壤，才能維持生命和生長。", "note": "INa-Ⅱ-7；活動2"},
	{"stage": 5, "unit": "三下｜田園樂", "q": "下列哪一個順序，是蔬菜生長的過程？", "options": ["種子→發芽→長葉→長高長大→開花→結果→枯死", "發芽→種子→開花→長葉→枯死→結果", "種子→開花→發芽→結果→長葉→枯死", "結果→開花→長葉→發芽→種子→枯死"], "answer": 0, "exp": "蔬菜的一生會經歷種子、發芽、長葉、長高長大、開花、結果，最後枯死。", "note": "活動3：蔬菜的一生"},
	{"stage": 5, "unit": "三下｜田園樂", "q": "我們吃的蔬菜，是植物的哪些部位？", "options": ["可能是根、莖、葉、花、果實或種子", "只有根", "只有花", "都不是植物的部位"], "answer": 0, "exp": "不同的蔬菜，食用的部位不同，可能是植物的根、莖、葉、花、果實或種子。", "note": "活動1：蔬菜是食用植物的哪個部位"},
	{"stage": 5, "unit": "三下｜田園樂", "q": "種菜時，可以用什麼來記錄蔬菜的成長變化？", "options": ["蔬菜觀察記錄表", "溫度計", "磁鐵", "量筒"], "answer": 0, "exp": "種菜時要觀察並記錄蔬菜的生長變化。", "note": "活動2：蔬菜觀察記錄表"},
	{"stage": 5, "unit": "三下｜田園樂", "q": "蔬菜種子播種後，接下來會經歷哪個階段？", "options": ["發芽", "開花", "結果", "枯死"], "answer": 0, "exp": "蔬菜的生長順序是種子、發芽，再繼續長大。", "note": "活動3：蔬菜的一生"},
	{"stage": 5, "unit": "三下｜田園樂", "q": "蔬菜種子發芽後長出來的小植物，叫做什麼？", "options": ["幼苗", "果實", "花萼", "雄蕊"], "answer": 0, "exp": "蔬菜種子發芽後，會長成幼苗。", "note": "活動2-1：種子發芽了"},
	{"stage": 5, "unit": "三下｜田園樂", "q": "用有開口的紙箱蓋住蔬菜幼苗，是想觀察什麼對蔬菜生長的影響？", "options": ["陽光", "磁力", "雨量", "風向"], "answer": 0, "exp": "透過觀察與實驗，可以了解陽光對蔬菜生長的影響。", "note": "活動2：陽光對蔬菜生長的影響"},
	{"stage": 5, "unit": "三下｜田園樂", "q": "蔬菜開花、結果之後，利用什麼來繁衍下一代？", "options": ["種子", "磁鐵", "空氣", "雨量"], "answer": 0, "exp": "生物壽命有限，利用種子繁衍後代，讓生命延續下去。", "note": "INd-Ⅱ-3；活動3"},
	{"stage": 5, "unit": "三下｜田園樂", "q": "種菜之前，可以先做什麼準備？", "options": ["查資料，了解蔬菜的種植方式，並選擇適合當季種植的蔬菜", "把種子丟進水溝", "不用準備，直接等著收成", "把蔬菜種在冰箱裡"], "answer": 0, "exp": "種菜前要先蒐集資料，了解蔬菜的生長條件和種植方式。", "note": "活動1：種菜前的準備"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "下列哪些因素，可能會讓物質產生變化？", "options": ["溫度、空氣和水", "名字、年齡和體重", "聲音、顏色和味道", "數字、文字和圖畫"], "answer": 0, "exp": "物質會受到溫度、空氣和水等因素影響，可能產生變化。", "note": "活動1-1：物質的變化"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "水有哪三種形態？", "options": ["液態、固態、氣態", "酸性、中性、鹼性", "大、中、小", "冷、熱、溫"], "answer": 0, "exp": "水有液態、固態和氣態三種形態。", "note": "INc-Ⅱ-6；活動2"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "冰是水的哪一種形態？", "options": ["固態", "液態", "氣態", "沒有形態"], "answer": 0, "exp": "冰是固態的水。", "note": "活動2-1"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "水蒸氣是水的哪一種形態？", "options": ["氣態", "固態", "液態", "沒有形態"], "answer": 0, "exp": "水蒸氣是氣態的水。", "note": "活動2-1"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "冰受熱，變成液態水的現象，叫做什麼？", "options": ["融化", "蒸發", "溶解", "發芽"], "answer": 0, "exp": "冰受熱，固態冰變成液態水的現象叫做融化。", "note": "活動2-1：融化的定義"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "水變成看不見、散布在空氣中的水蒸氣，這個現象叫做什麼？", "options": ["蒸發", "融化", "溶解", "生長"], "answer": 0, "exp": "水變成水蒸氣的現象叫做蒸發。", "note": "活動2-1：蒸發"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "想讓濕毛巾比較快乾，下列哪一種做法比較好？", "options": ["放在太陽下曬", "放在冰箱裡", "用塑膠袋包起來", "放在陰暗的櫃子裡"], "answer": 0, "exp": "提高溫度、用風吹，都可以讓水蒸發得比較快。", "note": "活動2-1：加快蒸發的方法"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "冰塊放在不同形狀的容器裡，冰塊的形狀會改變嗎？", "options": ["不會，冰是固態，形狀固定不變", "會，冰會跟著容器改變形狀", "會，冰會變成氣體", "不會，因為冰是氣態"], "answer": 0, "exp": "液態水會因容器改變形狀，固態冰的形狀固定不變。", "note": "活動2-1：液態與固態的比較"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "把水倒進不同形狀的容器裡，水會怎麼樣？", "options": ["形狀會跟著容器改變", "形狀固定不變", "立刻變成冰", "立刻變成氣體"], "answer": 0, "exp": "液態水會因容器改變形狀。", "note": "活動2-1：液態與固態的比較"},
	{"stage": 6, "unit": "三下｜溫度變化對物質的影響", "q": "溫度升高時，冰會怎麼樣？", "options": ["會融化，溫度會影響冰融化的快慢", "不會有任何變化", "會變得更硬", "會變成蔬菜"], "answer": 0, "exp": "溫度升高時冰會融化，溫度會影響冰融化的快慢。", "note": "活動2-1：溫度上升了"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "常見動物的身體，主要分成哪幾個部分？", "options": ["頭、軀幹和肢", "根、莖和葉", "花萼、花瓣和雄蕊", "種子、果實和花"], "answer": 0, "exp": "常見動物的身體分為頭、軀幹和肢。", "note": "INb-Ⅱ-5；活動1-2"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "常見的動物可以分成哪些類別？", "options": ["哺乳類、兩生類、魚類、鳥類、爬蟲類等", "蔬菜類、水果類、花草類", "金屬類、塑膠類、木頭類", "酸性、鹼性、中性"], "answer": 0, "exp": "常見的動物可以分為哺乳類、兩生類、魚類、鳥類、爬蟲類及其他種類。", "note": "活動1-2：動物的分類"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "動物的身體構造和功能，有什麼關係？", "options": ["構造和功能是互相配合的", "構造和功能完全沒有關係", "構造越多，功能越少", "沒有構造也能有功能"], "answer": 0, "exp": "動物的身體構造與功能是互相配合的。", "note": "INb-Ⅱ-4；活動1-3"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "不同的動物，外形特徵都一樣嗎？", "options": ["不一樣，不同的動物有不同的外形特徵", "一樣，所有動物都長得一樣", "一樣，所有動物都有翅膀", "一樣，所有動物都有鰭"], "answer": 0, "exp": "不同的動物，具有不同的外形特徵。", "note": "活動1-1：你看過哪些動物"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "兔、蛙和蜥蜴的身體都有什麼？", "options": ["頭、軀幹和四肢", "根、莖和葉", "花瓣和花萼", "果實和種子"], "answer": 0, "exp": "兔、蛙、蜥蜴的身體都有頭、軀幹和四肢。", "note": "活動1-2：動物的身體構造"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "不同的環境，會有什麼樣的生物生存？", "options": ["不同的環境有不同的生物生存", "所有環境的生物都一模一樣", "只有一種環境有生物", "沒有任何環境有生物"], "answer": 0, "exp": "不同的環境有不同的生物生存。", "note": "INc-Ⅱ-8；活動2-1：動物在哪裡生活"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "動物生長需要什麼？", "options": ["食物", "磁鐵", "量筒", "放大鏡"], "answer": 0, "exp": "動物生長需要食物。", "note": "活動2-2：動物生長需要食物"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "動物察覺到環境的改變時，會怎麼樣？", "options": ["會做出身體或行為的反應", "什麼反應都不會有", "會變成植物", "會變成石頭"], "answer": 0, "exp": "動物的感覺器官接受外界刺激，會引起生理和行為反應。", "note": "INe-Ⅱ-10；活動2-3"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "動物的外形顏色和環境相似或相異，有什麼幫助？", "options": ["能幫助牠們生存", "能讓牠們變成植物", "能讓牠們變成石頭", "能讓牠們不需要吃東西"], "answer": 0, "exp": "動物的外形顏色與環境相似或相異，能幫助牠們生存。", "note": "活動3-1：動物如何保護自己"},
	{"stage": 7, "unit": "三下｜我是動物解說員", "q": "動物的外形有些和人類相像，有些不同，但都具有什麼功能？", "options": ["幫助動物適應環境", "幫助動物變成人類", "讓動物長出根", "讓動物發芽"], "answer": 0, "exp": "動物的外形都具有功能，可以幫助動物適應環境。", "note": "活動2、3 綜合活動"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "測量雨量時，雨量的單位是什麼？", "options": ["毫米（mm）", "公斤", "公尺", "度"], "answer": 0, "exp": "雨量的單位是毫米（mm）。", "note": "活動2：測量雨量"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "下列哪一種容器比較適合用來收集雨水、測量雨量？", "options": ["平底直筒的容器", "上寬下窄的碗", "圓錐形的漏斗", "球形的瓶子"], "answer": 0, "exp": "平底直筒的容器比較適合作為雨量器。", "note": "活動2：雨量器"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "收集雨水的時候，適合選在哪裡？", "options": ["空曠、沒有遮蔽物的地方，例如草地上", "屋簷下", "大樹下", "走廊裡"], "answer": 0, "exp": "收集雨水時，要選空曠、沒有遮蔽物的地方，例如草地上。", "note": "活動2 學習目標"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "天氣預報常用哪些資料來表達天氣狀態？", "options": ["雨量、溫度、風向、風速", "體重、身高、年齡、視力", "花的顏色、葉子形狀、果實大小、種子數量", "岩石硬度、土壤顏色、沙子大小、水的重量"], "answer": 0, "exp": "天氣預報常用雨量、溫度、風向、風速等資料來表達天氣狀態。", "note": "INd-Ⅱ-7"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "晴天、多雲、陰天，主要是根據什麼來判斷的？", "options": ["天空中雲的多少（雲況）", "風的顏色", "雨水的味道", "溫度計的大小"], "answer": 0, "exp": "可以根據雲況來說明天氣狀況。", "note": "活動2：雲況與天氣"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "雲況和天氣狀況有什麼關係？", "options": ["有密切的關係，雲是天氣變化的徵兆", "完全沒有關係", "雲只會在晴天出現", "雲會讓溫度計變重"], "answer": 0, "exp": "雲是天氣變化的徵兆，各種雲況和天氣狀況有密切的關係。", "note": "活動2 學習目標"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "觀察天氣時，可以從哪些方面來觀察？", "options": ["雲量、氣溫、風、雨", "體重、身高、視力、年齡", "磁鐵、迴紋針、橡皮擦、鉛筆", "砂糖、食鹽、麵粉、小蘇打"], "answer": 0, "exp": "天氣狀況可以從雲量、氣溫、風和雨來觀察。", "note": "活動1-1、2"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "測量氣溫，要使用什麼？", "options": ["溫度計", "磁鐵", "放大鏡", "迴紋針"], "answer": 0, "exp": "天氣的資料可以使用適當的儀器測得，測量氣溫要用溫度計。", "note": "活動2-1：氣溫的測量"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "一年四季的氣溫和天氣會有什麼不同？", "options": ["氣溫和天氣都會有所不同", "四季都完全一樣", "只有氣溫會變，天氣不會", "只有天氣會變，氣溫不會"], "answer": 0, "exp": "一年四季氣溫會有所變化，天氣也會有所不同。", "note": "INd-Ⅱ-6；活動3-2"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "氣象報告可以讓我們知道什麼？", "options": ["天氣可能會有什麼變化", "明天考試會考幾分", "磁鐵的磁力有多強", "蔬菜有幾片葉子"], "answer": 0, "exp": "氣象報告可以讓我們知道天氣的可能變化。", "note": "INd-Ⅱ-6；活動3-1"},
	{"stage": 8, "unit": "三下｜天氣變變變", "q": "氣象預報說明天可能會下雨，出門時可以帶什麼？", "options": ["雨具", "磁鐵", "量筒", "放大鏡"], "answer": 0, "exp": "知道天氣可能下雨，可以攜帶雨具，也要注意天氣變化。", "note": "活動1、3：天氣與生活"},
]


# ---------- 遊戲狀態 ----------

var units: Array[Dictionary] = []
var phase := Phase.IDLE
var current: Dictionary = {}
var reachable: Array[Vector2i] = []
var attackable: Array[Vector2i] = []
var turn_count := 1
var current_stage := 0
var stage_name := ""
var result_text := ""
var result_win := false
var hover_cell := Vector2i(-1, -1)
var hud: Label

# 對話系統
var dialogue_lines: Array = []
var dialogue_index := 0
var dialogue_done: Callable
var dialogue_box: PanelContainer
var dialogue_name: Label
var dialogue_text: Label
var portrait_id := ""

# 答題系統
var quiz_box: PanelContainer
var quiz_header: Label
var quiz_question: Label
var quiz_feedback: Label
var quiz_continue: Button
var quiz_buttons: Array[Button] = []
var quiz_target: Dictionary = {}
var quiz_current: Dictionary = {}
var quiz_then: Callable
var quiz_order: Array[int] = []
var quiz_queue: Array[int] = []
var quiz_correct := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.position = Vector2(10, GRID_H * TILE + 8)
	hud.add_theme_font_size_override("font_size", 20)
	layer.add_child(hud)
	_build_dialogue_ui(layer)
	_build_quiz_ui(layer)
	_load_stage(0)


func _load_stage(idx: int) -> void:
	current_stage = idx
	var st: Dictionary = stages[idx]
	stage_name = st.name
	map_rows.clear()
	for row in st.map:
		map_rows.append(row)
	units.clear()
	current = {}
	reachable.clear()
	attackable.clear()
	turn_count = 1
	var n: int = roster_count[idx]
	for i in n:
		_add_unit(roster_order[i], "player", spawn_cells[i])
	for e in st.enemies:
		_add_unit(e[0], "enemy", e[1])
	_build_quiz_queue()
	start_dialogue(st.intro, _on_opening_done)


func _add_unit(class_id: String, team: String, pos: Vector2i) -> void:
	var c: Dictionary = classes[class_id]
	units.append({
		"cid": class_id, "who": c.who, "name": c.name,
		"team": team, "pos": pos, "acted": false,
		"hp": c.hp, "max_hp": c.hp,
		"atk": c.atk, "def": c.def, "res": c.res,
		"move": c.move, "min_range": c.min_range, "range": c.range,
		"magic": c.magic, "fly": c.fly, "terrain_cost": c.terrain_cost,
	})


# ---------- 地形工具 ----------

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID_W and c.y < GRID_H


func _tile_at(c: Vector2i) -> String:
	return map_rows[c.y][c.x]


# 該單位進入此格的消耗，-1 代表不能進入
func _tile_cost(c: Vector2i, u: Dictionary) -> int:
	if u.fly:
		return 1
	var ch := _tile_at(c)
	var base: int = terrain[ch].cost
	if base < 0:
		return -1
	if u.terrain_cost.has(ch):
		return u.terrain_cost[ch]
	return base


# ---------- 繪圖：地圖與單位 ----------

func _draw() -> void:
	for x in GRID_W:
		for y in GRID_H:
			_draw_tile(x, y)
	for c in reachable:
		draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE, TILE), Color(0.2, 0.5, 1.0, 0.5))
	for c in attackable:
		draw_rect(Rect2(c.x * TILE, c.y * TILE, TILE, TILE), Color(1.0, 0.2, 0.2, 0.5))
	for u in units:
		_draw_unit(u)
	# 對話時，在左側顯示說話者的大頭像
	if phase == Phase.DIALOGUE and portrait_id != "":
		draw_rect(Rect2(8, 196, 234, 280), Color(0, 0, 0, 0.55))
		_draw_character(portrait_id, Vector2(125, 360), 3.2)


func _draw_tile(x: int, y: int) -> void:
	var ch := _tile_at(Vector2i(x, y))
	var p := Vector2(x * TILE, y * TILE)
	draw_rect(Rect2(p, Vector2(TILE, TILE)), terrain[ch].color)
	match ch:
		"F":
			draw_circle(p + Vector2(20, 24), 12, Color(0.08, 0.25, 0.1))
			draw_circle(p + Vector2(44, 40), 14, Color(0.08, 0.25, 0.1))
		"M":
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(6, 58), p + Vector2(32, 8), p + Vector2(58, 58)
			]), Color(0.5, 0.5, 0.5))
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(24, 24), p + Vector2(32, 8), p + Vector2(40, 24)
			]), Color(0.9, 0.9, 0.95))
		"W":
			draw_line(p + Vector2(10, 22), p + Vector2(30, 22), Color(1, 1, 1, 0.35), 2.0)
			draw_line(p + Vector2(34, 44), p + Vector2(54, 44), Color(1, 1, 1, 0.35), 2.0)
	draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0, 0, 0, 0.4), false, 1.0)


func _draw_unit(u: Dictionary) -> void:
	var p: Vector2i = u.pos
	var tile_c := Vector2(p) * TILE + Vector2(TILE, TILE) / 2
	var team_col := Color(0.25, 0.5, 1.0) if u.team == "player" else Color(1.0, 0.25, 0.25)
	var ring_c := tile_c + Vector2(0, 2)
	draw_circle(ring_c, 28, Color(team_col, 0.35))
	draw_arc(ring_c, 28, 0, TAU, 32, team_col, 3.0)
	_draw_character(u.cid, tile_c + Vector2(0, 3), 0.8)
	if u.acted and u.team == "player":
		draw_circle(ring_c, 28, Color(0, 0, 0, 0.5))
	var bar_pos := Vector2(p) * TILE + Vector2(6, TILE - 9)
	var ratio := float(u.hp) / float(u.max_hp)
	draw_rect(Rect2(bar_pos, Vector2(TILE - 12, 6)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar_pos, Vector2((TILE - 12) * ratio, 6)), Color(0.2, 0.9, 0.2))


# ---------- 繪圖：角色造型（原創）----------

func _pt(c: Vector2, s: float, x: float, y: float) -> Vector2:
	return c + Vector2(x, y) * s


func _poly(c: Vector2, s: float, pts: Array, col: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(_pt(c, s, p[0], p[1]))
	draw_colored_polygon(arr, col)


func _rect(c: Vector2, s: float, x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(_pt(c, s, x, y), Vector2(w, h) * s), col)


func _ball(c: Vector2, s: float, x: float, y: float, r: float, col: Color) -> void:
	draw_circle(_pt(c, s, x, y), r * s, col)


func _line(c: Vector2, s: float, x1: float, y1: float, x2: float, y2: float, w: float, col: Color) -> void:
	draw_line(_pt(c, s, x1, y1), _pt(c, s, x2, y2), col, w * s)


func _draw_bow(c: Vector2, s: float, col: Color) -> void:
	draw_arc(_pt(c, s, 2, 4), 22 * s, -PI / 3, PI / 3, 14, col, 3.0 * s)
	_line(c, s, 13, -15, 13, 23, 1.2, Color(0.92, 0.92, 0.92))


func _draw_robot(c: Vector2, s: float, look: Dictionary) -> void:
	var metal: Color = look.outfit
	var glow: Color = look.trim
	var dark := Color(0.2, 0.22, 0.28)
	_rect(c, s, -10, 24, 8, 9, dark)
	_rect(c, s, 2, 24, 8, 9, dark)
	_rect(c, s, -22, -4, 8, 20, dark)
	_rect(c, s, 14, -4, 8, 20, dark)
	_rect(c, s, -14, -6, 28, 32, metal)
	_rect(c, s, -14, 14, 28, 4, dark)
	_ball(c, s, 0, 6, 5, glow)
	_rect(c, s, -13, -28, 26, 20, metal.lightened(0.15))
	_rect(c, s, -10, -22, 20, 7, dark)
	_rect(c, s, -8, -21, 16, 5, glow)
	_line(c, s, 0, -28, 0, -37, 2, dark)
	_ball(c, s, 0, -38, 3.5, Color(1, 0.3, 0.3))
	_rect(c, s, 20, 4, 14, 9, dark)
	_ball(c, s, 35, 8, 3.5, glow)


func _draw_wolf(c: Vector2, s: float, look: Dictionary) -> void:
	var fur: Color = look.outfit
	var dark := Color(0.12, 0.12, 0.16)
	_poly(c, s, [[-24, 14], [-34, -2], [-22, 6]], fur)
	_rect(c, s, -16, 20, 6, 12, dark)
	_rect(c, s, -4, 20, 6, 12, dark)
	_rect(c, s, 8, 20, 6, 12, dark)
	_poly(c, s, [[-24, 6], [12, 0], [24, 10], [18, 26], [-16, 26], [-26, 16]], fur)
	_ball(c, s, 22, -2, 10, fur)
	_poly(c, s, [[28, -4], [40, 4], [28, 8]], fur.lightened(0.15))
	_poly(c, s, [[14, -10], [16, -22], [22, -10]], fur)
	_poly(c, s, [[22, -10], [28, -20], [30, -8]], fur)
	_ball(c, s, 25, -4, 2, Color(1, 0.2, 0.2))
	_ball(c, s, 40, 4, 2, dark)


func _draw_golem(c: Vector2, s: float, look: Dictionary) -> void:
	var rock: Color = look.outfit
	var dark := rock.darkened(0.4)
	_rect(c, s, -14, 22, 10, 11, dark)
	_rect(c, s, 4, 22, 10, 11, dark)
	_rect(c, s, -31, -6, 12, 28, rock.darkened(0.15))
	_rect(c, s, 19, -6, 12, 28, rock.darkened(0.15))
	_rect(c, s, -19, -8, 38, 34, rock)
	_rect(c, s, -10, -26, 20, 18, rock.lightened(0.1))
	_rect(c, s, -7, -19, 5, 4, Color(1, 0.6, 0.1))
	_rect(c, s, 2, -19, 5, 4, Color(1, 0.6, 0.1))
	_line(c, s, -10, 0, -2, 10, 2, dark)
	_line(c, s, 6, 4, 12, 18, 2, dark)


func _draw_character(id: String, c: Vector2, s: float) -> void:
	var look: Dictionary = looks[id]
	var skin: Color = look.skin
	var hair: Color = look.hair
	var outfit: Color = look.outfit
	var trim: Color = look.trim
	var steel := Color(0.75, 0.78, 0.85)
	var wood := Color(0.5, 0.33, 0.15)
	var dark := Color(0.12, 0.12, 0.16)
	var bone := Color(0.93, 0.92, 0.85)

	if id == "robot":
		_draw_robot(c, s, look)
		return
	if id == "wolf":
		_draw_wolf(c, s, look)
		return
	if id == "golem":
		_draw_golem(c, s, look)
		return

	var hooded := id in ["sorcerer", "dark_mage", "bandit_archer"]
	var helmeted := id in ["knight", "dragoon", "boss"]
	var bald := id in ["goblin", "orc", "skeleton"]

	# 背景層：翅膀、披風
	if id == "dragoon":
		var wing := Color(0.55, 0.08, 0.12)
		_poly(c, s, [[-10, 0], [-38, -18], [-32, 4], [-38, 14], [-12, 16]], wing)
		_poly(c, s, [[10, 0], [38, -18], [32, 4], [38, 14], [12, 16]], wing)
	elif id == "knight":
		_poly(c, s, [[-12, 0], [12, 0], [19, 32], [-19, 32]], trim)
	elif id == "boss":
		_poly(c, s, [[-13, -2], [13, -2], [24, 34], [-24, 34]], Color(0.35, 0.05, 0.25))

	# 腿、身體、手臂
	_rect(c, s, -9, 26, 7, 8, dark)
	_rect(c, s, 2, 26, 7, 8, dark)
	_poly(c, s, [[-12, -2], [12, -2], [15, 27], [-15, 27]], outfit)
	_rect(c, s, -14, 15, 28, 4, trim)
	_line(c, s, -12, 3, -17, 14, 6, outfit)
	_line(c, s, 12, 3, 17, 14, 6, outfit)
	_ball(c, s, -17, 15, 4, skin)
	_ball(c, s, 17, 15, 4, skin)

	# 頭
	if hooded:
		_ball(c, s, 0, -13, 14.5, outfit)
		_ball(c, s, 0, -11, 9.5, skin)
	elif helmeted:
		var helm := steel
		if id == "dragoon":
			helm = Color(0.65, 0.1, 0.15)
		elif id == "boss":
			helm = Color(0.22, 0.12, 0.32)
		_ball(c, s, 0, -14, 13.5, helm)
		_rect(c, s, -8, -15, 16, 11, skin)
	else:
		if not bald:
			_ball(c, s, 0, -15, 12.5, hair)
		_ball(c, s, 0, -12, 11, skin)

	# 眼睛
	var eye := Color(0.1, 0.1, 0.15)
	var eye_r := 1.8
	if id == "dark_mage" or id == "boss":
		eye = Color(1.0, 0.2, 0.2)
		eye_r = 2.2
	elif id == "goblin":
		eye = Color(1.0, 0.9, 0.2)
		eye_r = 2.2
	elif id == "skeleton":
		eye = Color(0.05, 0.05, 0.08)
		eye_r = 3.0
	var ey := -12.0
	if hooded or helmeted:
		ey = -11.0
	_ball(c, s, -4, ey, eye_r, eye)
	_ball(c, s, 4, ey, eye_r, eye)

	# 每個角色獨有的裝備與特徵
	if id == "swordsman":
		_poly(c, s, [[-11, -19], [-7, -29], [-2, -21], [3, -30], [7, -21], [12, -27], [12, -15], [-11, -15]], hair)
		_rect(c, s, -12, 0, 24, 4, trim)
		_line(c, s, 20, 26, 20, -14, 4, steel)
		_rect(c, s, 14, 14, 12, 4, trim)
	elif id == "brawler":
		_poly(c, s, [[-11, -18], [-9, -27], [-3, -20], [2, -28], [7, -20], [11, -26], [11, -18]], hair)
		_rect(c, s, -12, -19, 24, 4, trim)
		_line(c, s, 11, -17, 21, -11, 3, trim)
		_ball(c, s, -20, 12, 8, trim)
		_ball(c, s, 20, 12, 8, trim)
		_ball(c, s, -22, 9, 2.5, Color(1, 1, 1, 0.5))
		_ball(c, s, 18, 9, 2.5, Color(1, 1, 1, 0.5))
	elif id == "archer":
		_poly(c, s, [[-10, -18], [10, -18], [7, -27], [-7, -24]], outfit)
		_line(c, s, 8, -24, 14, -34, 2.5, Color(1.0, 0.35, 0.35))
		_ball(c, s, -14, -8, 5, hair)
		_ball(c, s, -16, -2, 4, hair)
		_draw_bow(c, s, wood)
	elif id == "archmage":
		_poly(c, s, [[-8, -6], [8, -6], [3, 10], [0, 14], [-3, 10]], hair)
		_poly(c, s, [[-19, -18], [19, -18], [14, -23], [-14, -23]], outfit)
		_poly(c, s, [[-11, -22], [11, -22], [4, -36], [-4, -44]], outfit)
		_rect(c, s, -11, -25, 22, 3, trim)
		_line(c, s, 20, 32, 20, -26, 3, wood)
		_ball(c, s, 20, -29, 6, Color(0.5, 0.85, 1.0))
		_ball(c, s, 18, -31, 2, Color(1, 1, 1, 0.8))
	elif id == "sorcerer" or id == "dark_mage":
		var orb := Color(0.3, 0.9, 0.8)
		if id == "dark_mage":
			orb = Color(1.0, 0.25, 0.25)
		_poly(c, s, [[-8, -24], [8, -24], [0, -35]], outfit)
		_rect(c, s, -12, -2, 24, 3, trim)
		_line(c, s, 20, 32, 20, -18, 3, wood)
		_ball(c, s, 20, -22, 5.5, orb)
		_ball(c, s, 18.5, -24, 1.8, Color(1, 1, 1, 0.8))
	elif id == "knight":
		_poly(c, s, [[-2, -27], [3, -27], [12, -36], [-7, -31]], trim)
		_poly(c, s, [[-27, 0], [-12, 0], [-12, 17], [-20, 26], [-27, 17]], steel)
		_line(c, s, -20, 2, -20, 22, 2, trim)
		_line(c, s, -26, 9, -13, 9, 2, trim)
		_line(c, s, 21, 34, 21, -26, 3, wood)
		_poly(c, s, [[18, -26], [24, -26], [21, -38]], steel)
	elif id == "dragoon":
		_poly(c, s, [[-11, -21], [-18, -35], [-6, -25]], bone)
		_poly(c, s, [[11, -21], [18, -35], [6, -25]], bone)
		_rect(c, s, -4, -2, 8, 20, trim)
		_line(c, s, 21, 34, 21, -30, 3, steel)
		_poly(c, s, [[18, -30], [24, -30], [21, -42]], Color(0.95, 0.3, 0.2))
	elif id == "bandit_archer":
		_rect(c, s, -8, -8, 16, 7, Color(0.5, 0.12, 0.12))
		_draw_bow(c, s, wood)
	elif id == "goblin":
		_poly(c, s, [[-10, -15], [-25, -22], [-10, -8]], skin)
		_poly(c, s, [[10, -15], [25, -22], [10, -8]], skin)
		_line(c, s, 20, 28, 20, -6, 4, wood)
		_ball(c, s, 20, -8, 7, wood)
	elif id == "orc":
		_rect(c, s, -8, -17, 16, 3, dark)
		_poly(c, s, [[-6, -6], [-3, -6], [-5, 0]], bone)
		_poly(c, s, [[3, -6], [6, -6], [5, 0]], bone)
		_line(c, s, 20, 30, 20, -12, 3.5, wood)
		_poly(c, s, [[20, -12], [32, -18], [32, -2], [20, -6]], steel)
	elif id == "skeleton":
		_line(c, s, 0, 0, 0, 26, 1.5, bone)
		_line(c, s, -9, 6, 9, 6, 1.5, bone)
		_line(c, s, -9, 12, 9, 12, 1.5, bone)
		_line(c, s, -9, 18, 9, 18, 1.5, bone)
		_rect(c, s, -5, -5, 10, 2.5, dark)
		_line(c, s, 20, 26, 20, -12, 3, Color(0.6, 0.55, 0.5))
	elif id == "boss":
		var gold := Color(0.95, 0.8, 0.3)
		_poly(c, s, [[-11, -24], [-14, -38], [-6, -26]], gold)
		_poly(c, s, [[-3, -26], [0, -40], [3, -26]], gold)
		_poly(c, s, [[6, -26], [14, -38], [11, -24]], gold)
		_ball(c, s, -14, 2, 6, gold)
		_ball(c, s, 14, 2, 6, gold)
		_line(c, s, 23, 34, 23, -30, 5, Color(0.55, 0.12, 0.6))
		_rect(c, s, 15, 14, 16, 4, gold)


# ---------- 狀態列 ----------

func _refresh() -> void:
	queue_redraw()
	var line1 := ""
	match phase:
		Phase.IDLE:
			line1 = "第 %d 關　%s　第 %d 回合　點選角色　[Enter] 結束回合" % [current_stage + 1, stage_name, turn_count]
		Phase.MOVING:
			line1 = "選擇移動位置　[右鍵] 取消"
		Phase.ATTACKING:
			line1 = "點擊紅色格攻擊敵人　[空白鍵] 待機"
		Phase.ENEMY_TURN:
			line1 = "敵方回合…"
		Phase.QUIZ:
			line1 = "答題中…"
		Phase.GAME_OVER:
			if result_win and current_stage < stages.size() - 1:
				line1 = "%s　按 [Enter] 前往下一關　[R] 重玩本關" % result_text
			elif result_win:
				line1 = "%s　按 [R] 從第一關重新開始" % result_text
			else:
				line1 = "%s　按 [R] 重新挑戰本關" % result_text
	hud.text = line1 + "\n" + _hover_info()


func _hover_info() -> String:
	if not _in_bounds(hover_cell):
		return ""
	var t: Dictionary = terrain[_tile_at(hover_cell)]
	var s := "地形：%s" % t.name
	if t.cost < 0:
		s += "（無法通行）"
	else:
		s += "（消耗 %d　防禦 +%d）" % [t.cost, t.def]
	var u := unit_at(hover_cell)
	if not u.is_empty():
		s += "\n%s（%s）　HP %d/%d　攻 %d　防 %d　魔防 %d　移動 %d　射程 %d-%d" % [
			u.who, u.name, u.hp, u.max_hp, u.atk, u.def, u.res, u.move, u.min_range, u.range]
	return s


# ---------- 輸入 ----------

func _input(event: InputEvent) -> void:
	if phase == Phase.QUIZ:
		return

	if phase == Phase.DIALOGUE:
		var advance := false
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			advance = true
		elif event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			advance = true
		if advance:
			_advance_dialogue()
		return

	if event is InputEventMouseMotion:
		var c := Vector2i((get_global_mouse_position() / TILE).floor())
		if c != hover_cell:
			hover_cell = c
			_refresh()
		return

	if event is InputEventKey and event.pressed:
		if phase == Phase.GAME_OVER:
			if event.keycode == KEY_ENTER and result_win and current_stage < stages.size() - 1:
				_load_stage(current_stage + 1)
			elif event.keycode == KEY_R:
				var all_clear: bool = result_win and current_stage == stages.size() - 1
				_load_stage(0 if all_clear else current_stage)
		elif event.keycode == KEY_SPACE and phase == Phase.ATTACKING:
			_finish_action()
		elif event.keycode == KEY_ENTER and phase == Phase.IDLE:
			_end_player_turn()
		return

	if phase == Phase.ENEMY_TURN or phase == Phase.GAME_OVER:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and phase == Phase.MOVING:
			_cancel_selection()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var cell := Vector2i((get_global_mouse_position() / TILE).floor())
			if not _in_bounds(cell):
				return
			_on_cell_clicked(cell)


func _on_cell_clicked(cell: Vector2i) -> void:
	match phase:
		Phase.IDLE:
			var u := unit_at(cell)
			if not u.is_empty() and u.team == "player" and not u.acted:
				current = u
				reachable = get_reachable(u)
				phase = Phase.MOVING
		Phase.MOVING:
			if cell in reachable:
				current.pos = cell
				reachable.clear()
				attackable = get_attackable(current)
				if attackable.is_empty():
					_finish_action()
					return
				phase = Phase.ATTACKING
			else:
				_cancel_selection()
				return
		Phase.ATTACKING:
			if cell in attackable:
				var target := unit_at(cell)
				_attack(current, target)
				if target.get("pending", false):
					start_quiz(target, _finish_action)
					return
				_finish_action()
				return
	_refresh()


func _cancel_selection() -> void:
	current = {}
	reachable.clear()
	attackable.clear()
	phase = Phase.IDLE
	_refresh()


# ---------- 行動與戰鬥 ----------

func _attack(attacker: Dictionary, target: Dictionary) -> void:
	var bonus: int = terrain[_tile_at(target.pos)].def
	var guard: int = target.res if attacker.magic else target.def
	var dmg: int = max(1, attacker.atk - guard - bonus)
	target.hp -= dmg
	if target.team == "enemy" and target.hp <= 0:
		# 敵人被打倒後不會馬上消失，要答題才能徹底擊敗
		target.hp = 0
		target["pending"] = true
	else:
		_remove_dead()


func _remove_dead() -> void:
	for i in range(units.size() - 1, -1, -1):
		if units[i].hp <= 0 and not units[i].get("pending", false):
			units.remove_at(i)


func _finish_action() -> void:
	if not current.is_empty():
		current.acted = true
	current = {}
	reachable.clear()
	attackable.clear()
	phase = Phase.IDLE
	if _check_game_over():
		return
	var all_done := true
	for u in units:
		if u.team == "player" and not u.acted:
			all_done = false
	if all_done:
		_end_player_turn()
	else:
		_refresh()


func _check_game_over() -> bool:
	var players := 0
	var enemies := 0
	for u in units:
		if u.team == "player":
			players += 1
		else:
			enemies += 1
	var st: Dictionary = stages[current_stage]
	var lines: Array
	if enemies == 0:
		result_win = true
		if current_stage == stages.size() - 1:
			result_text = "全關通關！"
		else:
			result_text = "第 %d 關完成！" % (current_stage + 1)
		lines = st.win
	elif players == 0:
		result_win = false
		result_text = "全軍覆沒…"
		lines = [{"who": "賽恩", "text": "可惡……全軍撤退！我們一定會再回來的！"}]
	else:
		return false
	start_dialogue(lines, _on_ending_done)
	return true


# ---------- 回合與敵方 AI ----------

func _end_player_turn() -> void:
	phase = Phase.ENEMY_TURN
	_refresh()
	_run_enemy_turn()


func _run_enemy_turn() -> void:
	for e in units.duplicate():
		if e.team != "enemy" or e.hp <= 0:
			continue
		await get_tree().create_timer(0.4).timeout
		var target := _nearest_player(e)
		if target.is_empty():
			break
		# 移動：能打到人的格子優先（再偏好有防禦加成的地形），否則往目標靠近
		var dist_to_target := _dijkstra(target.pos, 9999, false, e)
		var best: Vector2i = e.pos
		var best_score := 999999
		for c in get_reachable(e):
			var score: int = dist_to_target.get(c, 9999)
			if not targets_from(e, c).is_empty():
				score -= 1000
				score -= int(terrain[_tile_at(c)].def) * 2
			if score < best_score:
				best_score = score
				best = c
		e.pos = best
		queue_redraw()
		await get_tree().create_timer(0.3).timeout
		# 攻擊：射程內血量最低的我方單位
		var victims := get_attackable(e)
		if not victims.is_empty():
			var weakest := unit_at(victims[0])
			for c in victims:
				var v := unit_at(c)
				if v.hp < weakest.hp:
					weakest = v
			_attack(e, weakest)
			queue_redraw()
			await get_tree().create_timer(0.3).timeout
		if _check_game_over():
			return

	for u in units:
		u.acted = false
	turn_count += 1
	phase = Phase.IDLE
	_refresh()


func _nearest_player(from: Dictionary) -> Dictionary:
	var dist := _dijkstra(from.pos, 9999, false, from)
	var best: Dictionary = {}
	var best_d := 99999
	for u in units:
		if u.team == "player":
			var d: int = dist.get(u.pos, 9999)
			if d < best_d:
				best_d = d
				best = u
	return best


# ---------- 工具函式 ----------

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func unit_at(cell: Vector2i) -> Dictionary:
	for u in units:
		if u.pos == cell:
			return u
	return {}


# 假設單位站在 pos，射程內（含最小射程限制）的敵對單位所在格
func targets_from(u: Dictionary, pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for other in units:
		if other.team == u.team:
			continue
		var d := _manhattan(pos, other.pos)
		if d >= u.min_range and d <= u.range:
			result.append(other.pos)
	return result


func get_attackable(u: Dictionary) -> Array[Vector2i]:
	return targets_from(u, u.pos)


# 帶成本的最短路徑：回傳 {格子: 最小消耗}
func _dijkstra(start: Vector2i, limit: int, block_units: bool, u: Dictionary) -> Dictionary:
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = cur + d
			if not _in_bounds(n):
				continue
			var cost := _tile_cost(n, u)
			if cost < 0:
				continue
			if block_units and not unit_at(n).is_empty():
				continue
			var nd: int = dist[cur] + cost
			if nd > limit:
				continue
			if not dist.has(n) or nd < dist[n]:
				dist[n] = nd
				queue.append(n)
	return dist


# 移動範圍：移動力內能停留的格子（含原地）
func get_reachable(u: Dictionary) -> Array[Vector2i]:
	var dist := _dijkstra(u.pos, u.move, true, u)
	var result: Array[Vector2i] = []
	for c in dist.keys():
		result.append(c)
	return result


# ---------- 對話系統 ----------

func _build_dialogue_ui(layer: CanvasLayer) -> void:
	dialogue_box = PanelContainer.new()
	dialogue_box.position = Vector2(0, 490)
	dialogue_box.custom_minimum_size = Vector2(1152, 150)
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_box.visible = false
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_name = Label.new()
	dialogue_name.add_theme_font_size_override("font_size", 24)
	dialogue_name.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	dialogue_text = Label.new()
	dialogue_text.add_theme_font_size_override("font_size", 26)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	dialogue_text.custom_minimum_size = Vector2(1100, 0)
	vbox.add_child(dialogue_name)
	vbox.add_child(dialogue_text)
	dialogue_box.add_child(vbox)
	layer.add_child(dialogue_box)


func start_dialogue(lines: Array, on_done: Callable) -> void:
	dialogue_lines = lines
	dialogue_index = 0
	dialogue_done = on_done
	phase = Phase.DIALOGUE
	dialogue_box.visible = true
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	var line: Dictionary = dialogue_lines[dialogue_index]
	dialogue_name.text = line.who
	dialogue_text.text = line.text + "　▼"
	portrait_id = speaker_look.get(line.who, "")
	queue_redraw()


func _advance_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		dialogue_box.visible = false
		portrait_id = ""
		dialogue_done.call()
	else:
		_show_dialogue_line()


func _on_opening_done() -> void:
	phase = Phase.IDLE
	_refresh()


func _on_ending_done() -> void:
	phase = Phase.GAME_OVER
	_refresh()


# ---------- 答題系統 ----------

func _build_quiz_ui(layer: CanvasLayer) -> void:
	quiz_box = PanelContainer.new()
	quiz_box.position = Vector2(126, 60)
	quiz_box.custom_minimum_size = Vector2(900, 0)
	quiz_box.visible = false
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	quiz_header = Label.new()
	quiz_header.add_theme_font_size_override("font_size", 20)
	quiz_header.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	quiz_header.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	quiz_header.custom_minimum_size = Vector2(860, 0)
	quiz_question = Label.new()
	quiz_question.add_theme_font_size_override("font_size", 28)
	quiz_question.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	quiz_question.custom_minimum_size = Vector2(860, 0)
	vbox.add_child(quiz_header)
	vbox.add_child(quiz_question)
	for i in 4:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 24)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_quiz_answer.bind(i))
		quiz_buttons.append(b)
		vbox.add_child(b)
	quiz_feedback = Label.new()
	quiz_feedback.add_theme_font_size_override("font_size", 24)
	quiz_feedback.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	quiz_feedback.custom_minimum_size = Vector2(860, 0)
	vbox.add_child(quiz_feedback)
	quiz_continue = Button.new()
	quiz_continue.text = "繼續"
	quiz_continue.add_theme_font_size_override("font_size", 24)
	quiz_continue.visible = false
	quiz_continue.pressed.connect(_on_quiz_continue)
	vbox.add_child(quiz_continue)
	margin.add_child(vbox)
	quiz_box.add_child(margin)
	layer.add_child(quiz_box)


# 每一關重新排題目順序：本關單元的題目優先，其餘題目當作複習
func _build_quiz_queue() -> void:
	var own: Array[int] = []
	var others: Array[int] = []
	for i in quiz_bank.size():
		if quiz_bank[i].stage == current_stage + 1:
			own.append(i)
		else:
			others.append(i)
	own.shuffle()
	others.shuffle()
	quiz_queue.clear()
	for i in others:
		quiz_queue.append(i)
	for i in own:
		quiz_queue.append(i)


func start_quiz(enemy: Dictionary, then: Callable) -> void:
	quiz_target = enemy
	quiz_then = then
	if quiz_queue.is_empty():
		_build_quiz_queue()
	quiz_current = quiz_bank[quiz_queue.pop_back()]
	quiz_order.clear()
	for i in quiz_current.options.size():
		quiz_order.append(i)
	quiz_order.shuffle()
	phase = Phase.QUIZ
	quiz_header.text = "%s被打倒了！回答問題，才能徹底擊敗它！（%s）" % [enemy.who, quiz_current.unit]
	quiz_question.text = quiz_current.q
	var marks := ["①", "②", "③", "④"]
	for i in quiz_buttons.size():
		quiz_buttons[i].text = "%s　%s" % [marks[i], quiz_current.options[quiz_order[i]]]
		quiz_buttons[i].disabled = false
	quiz_feedback.text = ""
	quiz_continue.visible = false
	quiz_box.visible = true
	_refresh()


func _on_quiz_answer(choice: int) -> void:
	quiz_correct = quiz_order[choice] == quiz_current.answer
	for b in quiz_buttons:
		b.disabled = true
	if quiz_correct:
		quiz_feedback.text = "答對了！%s被徹底擊敗了！" % quiz_target.who
	else:
		var right: String = quiz_current.options[quiz_current.answer]
		quiz_feedback.text = "答錯了……正確答案是「%s」。%s恢復了一些力氣，又站了起來！" % [right, quiz_target.who]
	var explain: String = quiz_current.get("exp", "")
	if explain != "":
		quiz_feedback.text += "\n說明：" + explain
	quiz_continue.visible = true


func _on_quiz_continue() -> void:
	quiz_box.visible = false
	quiz_target["pending"] = false
	if quiz_correct:
		quiz_target.hp = 0
		_remove_dead()
	else:
		# 答錯：敵人恢復 30% 生命（至少 1 點）
		quiz_target.hp = max(1, int(ceil(quiz_target.max_hp * 0.3)))
	quiz_target = {}
	phase = Phase.IDLE
	quiz_then.call()
