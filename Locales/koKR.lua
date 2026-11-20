-- 한국어. Strings come from the retail Dialogue UI locale where it has the same text, the rest are written for this port.
if not (GetLocale() == "koKR") then return end;

local _, addon = ...;
local L = addon.L;

-- Blizzard's own global strings are used where they exist (they follow the client language). The text below is the fallback.

-- Footer buttons
L["Accept"] = ACCEPT or "동의";
L["Restart Quest"] = "다시 시작";
L["Continue"] = CONTINUE or "계속";
L["Complete Quest"] = COMPLETE or "퀘스트 완료";
L["Incomplete"] = INCOMPLETE or "미완성";
L["Decline"] = DECLINE or "거절";
L["Cancel"] = CANCEL or "취소";
L["Goodbye"] = GOODBYE or "잘가요.";

-- Settings window
L["UI"] = "UI";
L["Control"] = "입력설정";
L["Gameplay"] = "게임플레이";
L["Minimap"] = "미니맵";
L["Other Addons"] = "기타 애드온";

-- Settings: Other Addons tab
L["Tooltip"] = "툴팁";
L["Auction House"] = "경매장";
L["Auction House Desc"] = "설치된 다른 애드온의 경매장 가격을 아이템 툴팁에 추가합니다. 아래에서 사용할 애드온을 선택하세요.";
L["Auction House Auctionator Desc"] = "Auctionator: Auctionator가 자체 툴팁에 보여 주는 대로 아이템의 경매 가격, 중간 가격, 마력 추출 가치를 표시합니다. 표시 줄은 Auctionator의 툴팁 설정을 따릅니다.";
L["Auction House RetailAH Desc"] = "Retail Auction House (mod-retail-ah): 서버의 경매장 봇 구매자가 아이템에 지불하는 금액(묶음이면 묶음 전체)과 한 번의 마력 추출로 얻는 재료의 평균 가치를 표시합니다. 둘 중 더 나은 쪽은 녹색입니다.\n\n귀속된 아이템에는 아무것도 표시되지 않으며, 마법부여 기술이 부족하면 마력 추출 줄이 회색으로 표시됩니다. 서버에서 mod-retail-ah 모듈이 실행 중이어야 합니다.";
L["Journal Gear Desc"] = "내 전문화에 더 좋은 아이템의 툴팁에 \"장비 목록에 있음\" 줄을 추가합니다. Journal: Gear (JournalGearBIS) 애드온을 사용합니다.";
L["Addon Not Installed"] = "|cffff8040%s이(가) 설치되지 않았거나 로드되지 않아 이 지원은 작동하지 않습니다.|r 설치한 뒤 인터페이스를 다시 불러오세요 (/reload).";
L["AH Bot Buys"] = "경매장 봇 구매가";
L["AH Bot Disenchant"] = "마력 추출 (경매장 봇)";
L["AH Bot Disenchant Skill"] = "마력 추출 |cff808080(마법부여 %d)|r";
L["AH Bot BiS Bonus"] = "BiS 보너스";

-- Settings: Compatibility
L["Compatibility"] = "호환성";
L["Disable DUI In Instance"] = "던전/공격대 진입 시 WoW 기본 UI 사용";
L["Disable DUI In Instance Desc"] = "던전/공격대에서는 WoW 기본 대화 UI가 자동으로 사용됩니다.";

-- Settings: Minimap tab and minimap button
L["Show Minimap Button"] = "미니맵 버튼 표시";
L["Show Minimap Button Desc"] = "이 설정을 여는 버튼을 미니맵에 표시합니다. 드래그하여 미니맵 주위로 옮길 수 있습니다.";
L["Minimap Button Tooltip"] = "클릭하여 설정을 엽니다.";
L["Minimap Button Drag"] = "드래그하여 이동";

-- Settings: UI tab
L["Theme"] = "테마";
L["Theme Desc"] = "UI의 테마 색상을 선택 합니다.";
L["Theme Brown"] = "갈색";
L["Theme Dark"] = "검정색";
L["Frame Size"] = "프레임 크기";
L["Frame Size Desc"] = "UI 크기를 설정 합니다.\n\n기본값: 중간";
L["Size Extra Small"] = "최소";
L["Size Small"] = "소";
L["Size Medium"] = "중";
L["Size Large"] = "대";
L["Open Animation"] = "열기 애니메이션";
L["Open Animation Desc"] = "대화창이 열리는 데 걸리는 시간입니다. 0초는 즉시 표시합니다.\n\n기본값: 0.25초";
L["Font Size"] = "글자 크기";
L["Font Size Desc"] = "UI의 글자 크기를 설정합니다..\n\n기본값: 12";
L["Font"] = "글꼴";
L["Font Desc"] = "UI에 사용할 글꼴을 선택합니다.\n\n기본 글꼴: Friz Quadrata";
L["Default Font"] = "기본 글꼴";
L["System Font"] = "시스템";
L["Font Missing"] = "선택한 글꼴을 사용할 수 없어 기본 글꼴을 사용합니다.";
L["Font No Shared Media"] = "SharedMedia 또는 LibSharedMedia-3.0으로 글꼴을 추가하는 애드온을 설치하면 더 많은 글꼴을 선택할 수 있습니다.";
L["Frame Orientation"] = "위치";
L["Frame Orientation Desc"] = "UI를 화면 왼쪽 또는 오른쪽에 배치합니다.\n\n사용자 지정을 선택하면 이 창이 열려 있는 동안 UI를 원하는 곳으로 드래그할 수 있습니다.\n\n기본값: 오른쪽";
L["Orientation Left"] = "왼쪽";
L["Orientation Right"] = "오른쪽";
L["Orientation Custom"] = "사용자 지정";
L["Move Position"] = "이동";
L["Reset Position"] = "위치 재설정";
L["Move Position Desc"] = "UI를 표시하여 새 위치로 드래그할 수 있게 합니다.";
L["Reset Position Desc"] = "UI 위치를 초기화합니다.";
L["Readables Position"] = "위치";
L["Readables Position Desc"] = "읽을 수 있는 문서(책, 편지, 명판)를 화면 왼쪽에 배치합니다.\n\n사용자 지정을 선택하면 이 창이 열려 있는 동안 원하는 곳으로 드래그할 수 있습니다.\n\n기본값: 기본값";
L["Position Default"] = "기본값";
L["Readables Move Position Desc"] = "예시 문서를 표시하여 새 위치로 드래그할 수 있게 합니다.";
L["Readables Reset Position Desc"] = "문서의 위치를 초기화합니다.";
L["Hide UI"] = "UI 숨기기";
L["Hide UI Desc"] = "NPC와 상호작용할 때 게임 UI를 페이드 아웃 합니다.";
L["Readables Hide UI Desc"] = "책, 편지, 명판을 읽는 동안 게임 UI를 페이드 아웃 합니다.";
L["Show NPC Name On Page"] = "NPC 이름 표시";
L["Show NPC Name On Page Desc"] = "페이지에 NPC 이름을 표시합니다.";
L["Show Quest Type"] = "퀘스트 유형 표시";
L["Show Quest Type Desc"] = "퀘스트 제목 위에 퀘스트 유형(퀘스트, 일일, 주간, 던전 등)을 표시합니다.";
L["Show Copy Text Button"] = "텍스트 복사 버튼 표시";
L["Show Copy Text Button Desc"] = "대화 UI 오른쪽 위에 텍스트 복사 버튼을 표시합니다.\n\nNPC와 아이템 ID(그리고 이미 퀘스트 목록에 있는 퀘스트의 ID) 같은 게임 데이터도 포함됩니다.";
L["Copy Text"] = "문자 복사";
L["Drag To Move"] = "마우스 왼쪽 버튼을 클릭하고 드래그하여 창을 이동합니다.";
L["Edit Mode Title"] = "Dialogue UI";
L["Edit Mode Body"] = "이 창을 원하는 위치로 드래그하세요. 설정 창을 닫으면 숨겨집니다.";

-- Quest types and tags
L["Quest"] = "퀘스트";
L["Readables"] = "읽기 가능한 오브젝트";
L["BookUI Frame Size Desc"] = "책 UI의 크기를 설정합니다.\n\n기본값: 작게";
L["BookUI Keep UI Open"] = "창 닫지 않기";
L["BookUI Keep UI Open Desc"] = "대상에서 멀어져도 창이 자동으로 닫히지 않습니다.\n\nEsc 키를 누르거나 마우스 오른쪽 클릭으로 창을 닫을 수 있습니다.";
L["BookUI Show Location"] = "위치 표시";
L["BookUI Show Location Desc"] = "제목에 오브젝트 위치 표시\n\n게임 내 오브젝트에만 적용되며, 가방 속 아이템에는 적용되지 않습니다.";
L["BookUI Show Item Description"] = "아이템 설명 표시";
L["BookUI Show Item Description Desc"] = "툴팁 설명이 있는 경우, UI 상단에 표시합니다.";
L["BookUI Darken Screen"] = "화면 어둡게";
L["BookUI Darken Screen Desc"] = "콘텐츠 집중을 돕기 위해 UI 아래쪽 화면을 어둡게 처리합니다.";

-- Settings: Control tab (retail enUS where it exists)
L["Input Device"] = "입력 장치";
L["Input Device Desc"] = "단축키 아이콘과 UI 레이아웃에 영향을 미칩니다.";
L["Input Device KBM"] = "키보드 & 마우스";
L["Use Custom Bindings"] = "사용자 지정 키 사용";
L["Use Custom Bindings Desc"] = "이 옵션을 켜면 사용자 키 바인딩을 적용합니다s.";
L["Primary Control Key Desc"] = "이 버튼를 눌러 퀘스트 수락과 같은 첫 번째 사용 가능한 옵션을 선택합니다.";
L["Right Click To Close UI"] = "마우스 오른쪽 버튼을 클릭하여 UI 닫기";
L["Right Click To Close UI Desc"] = "대화 UI를 마우스 오른쪽 버튼으로 클릭하여 닫습니다.";
L["Press Button To Scroll Down"] = "버튼을 눌러 아래로 스크롤합니다";
L["Press Button To Scroll Down Desc"] = "콘텐츠가 뷰포트보다 높은 경우 확인 버튼을 누르면 퀘스트를 수락하는 대신 페이지가 아래로 스크롤됩니다.";
L["Press Escape To Decline Quest"] = "ESC 키를 눌러 퀘스트 거절";
L["Press Escape To Decline Quest Desc"] = "NPC의 다른 대화가 있는 퀘스트를 볼 때 ESC 키를 누르면 UI가 닫히지 않고 이전 페이지로 돌아갑니다.";
L["Press Tab To Select Reward"] = "보상을 선택하려면 Tab 키를 누르세요";
L["Press Tab To Select Reward Desc"] = "퀘스트를 완료할 때 Tab 키를 눌러 선택 가능한 보상을 순서대로 선택합니다. Shift+Tab은 뒤로 이동합니다.";
L["Keybinding Hint"] = "클릭한 다음 사용할 키를 누르세요.\n오른쪽 클릭: 기본 키로 되돌리기.\nEsc: 취소.";
L["Bound To"] = "할당 대상: ";
L["Not Bound"] = NOT_BOUND or "지정되지 않음";
L["Action Confirm"] = "확인";
L["Action Settings"] = "설정 열기/닫기 단축키";
L["Action Option1"] = "옵션 1";
L["Action Option2"] = "옵션 2";
L["Action Option3"] = "옵션 3";
L["Action Option4"] = "옵션 4";
L["Action Option5"] = "옵션 5";
L["Action Option6"] = "옵션 6";
L["Action Option7"] = "옵션 7";
L["Action Option8"] = "옵션 8";
L["Action Option9"] = "옵션 9";
L["Action Option Desc"] = "이 키를 누르면 목록(퀘스트 및 대화 선택지)의 %d번째 항목을 선택합니다.";
L["Action Settings Desc"] = "대화가 표시되는 동안 이 키를 누르면 설정 창을 열거나 닫습니다.";

L["Quest Frequency Daily"] = "일일";
L["Quest Frequency Weekly"] = "주간";
L["Quest Type Repeatable"] = "반복 가능";
L["Quest Difficulty VeryHard"] = "매우 어려움";
L["Quest Difficulty Hard"] = "어려움";
L["Quest Difficulty Easy"] = "쉬움";
L["Quest Difficulty Trivial"] = "낮은 레벨";
L["Quest Difficulty Option"] = "퀘스트 난이도";
L["Instant Quest Text"] = "퀘스트 텍스트 즉시 표시";
L["Instant Quest Text Desc"] = "퀘스트 텍스트를 서서히 나타내지 않고 한 번에 표시합니다. Blizzard의 퀘스트 텍스트 옵션과 같은 게임 설정을 사용합니다.";
L["Mark Highest Sell Price"] = "최고 판매 가격 표시";
L["Mark Highest Sell Price Desc"] = "보상을 선택할 때 판매 가격이 가장 높은 품목을 보여줍니다.";
L["Show Replace Calculations"] = "교체 계산 표시";
L["Show Replace Calculations Desc"] = "아이템 툴팁의 \"교체\" 아래에 능력치 차이를 표시합니다. 끄면 착용 중인 아이템 이름이 있는 교체 줄만 표시됩니다.";
L["Use Blizzard Tooltip"] = "블리자드 툴팁 사용";
L["Use Blizzard Tooltip Desc"] = "퀘스트 보상 버튼에는 특별 툴팁 대신 블리자드 툴팁을 사용하세요.";
L["Show EXP Bar"] = "경험치 바";
L["Show EXP Bar Desc"] = "대화가 열려 있는 동안 화면 하단에 경험치 바를 표시합니다.";
L["Always Show EXP Bar"] = "경험치 바 항상 표시";
L["Always Show EXP Bar Desc"] = "대화가 열려 있지 않을 때도 경험치 바를 화면에 유지하여 기본 경험치 바로 사용할 수 있게 합니다.";
L["Format Unit Level"] = "레벨 %d";
L["Format Player XP"] = "경험치: %d/%d (%d%%)";
L["Format Gained XP"] = "경험치 %d";
L["To Next Level Label"] = "다음 레벨까지";
L["Use Separate Tooltip for Comparison"] = "비교용 별도 툴팁 사용";
L["Use Separate Tooltip for Comparison Desc"] = "교체될 착용 아이템을 보상 툴팁 옆의 별도 툴팁에 표시하고, 아래쪽에 능력치 차이를 보여줍니다. 반지, 장신구, 무기는 착용 중인 아이템마다 툴팁이 하나씩 표시됩니다.";
L["Use Separate Tooltip Blizzard Active"] = "\"%s\" 옵션이 켜져 있는 동안에는 사용할 수 없습니다. 이 옵션을 사용하려면 해당 옵션을 끄세요.";
L["Show Transmog Status"] = "미수집 외형 표시";
L["Show Transmog Status Desc"] = "아직 수집하지 않은 형상변환 외형의 보상 아이템을 표시하고 툴팁에 한 줄을 추가합니다.\n\n|cffff8040서버에 형상변환 시스템 모듈(mod-transmog)이 설치되어 있어야 합니다.|r 없으면 아무것도 표시되지 않습니다.\n\n애드온이 .transmog sync 명령을 한 번 실행하고 그 출력은 채팅창에서 숨깁니다.";
L["Use Transmog Plus"] = "Mod Transmog Plus 사용 중";
L["Use Transmog Plus Desc"] = "서버가 원본 mod-transmog 대신 mod-transmog-plus를 사용한다면 선택하세요. 그러면 서버가 아이템마다 응답하며, 같은 모델의 아이템 중 하나라도 수집했다면 외형을 수집한 것으로 처리합니다.\n\n원본 mod-transmog라면 선택하지 마세요.";
L["Transmog Not Collected"] = "외형 미수집";
L["Transmog Module Missing"] = "|cffff8040서버의 %s 모듈이 감지되지 않아 이 설정은 비활성화되었습니다.|r";
L["Click To Copy To Clipboard"] = "클릭하여 클립보드에 복사";
L["Show Upgrade Arrow"] = "업그레이드 화살표 표시 (Pawn 필요)";
L["Show Upgrade Arrow Desc"] = "Pawn 애드온 기준으로 캐릭터에게 업그레이드인 보상 아이템에 녹색 화살표 %s를 표시합니다. 아이템이 해당 칸에 장착한 아이템보다 Pawn 점수 체계 중 하나 이상에서 더 높은 점수를 받는 경우입니다.\n\n장착 중인 것과 다른 종류의 방어구(예: 가죽 대신 천)는 표시되지 않습니다.";
L["Show Upgrade Arrow Pawn Missing"] = "Pawn 애드온이 필요합니다 (찾을 수 없음).\n\n다운로드: |cff0000ee%s|r\n\n복사 아이콘을 클릭하고 Ctrl+C를 누른 뒤 링크를 브라우저에 붙여넣으세요.";
L["Quest Difficulty Option Desc"] = "NPC가 퀘스트 목록을 보여줄 때 퀘스트 난이도를 표시하는 방식을 선택합니다.";
L["QuestDifficultyStyle Off"] = "끔";
L["QuestDifficultyStyle Off Desc"] = "퀘스트 레벨과 난이도가 숨겨집니다.";
L["QuestDifficultyStyle Level"] = "레벨";
L["QuestDifficultyStyle Level Desc"] = "퀘스트 제목 왼쪽에 퀘스트 레벨을 표시합니다.";
L["QuestDifficultyStyle Name"] = "이름";
L["QuestDifficultyStyle Both"] = "둘 다";
L["QuestDifficultyStyle Both Desc"] = "퀘스트 제목 왼쪽에 퀘스트 레벨을 표시하고, 퀘스트 레벨이 권장 범위를 벗어나면 퀘스트 버튼 오른쪽에 난이도 이름을 표시합니다.";
L["QuestDifficultyStyle Name Desc"] = "퀘스트 레벨이 권장 범위를 벗어나면 퀘스트 버튼 오른쪽에 난이도 이름을 표시합니다.\n(퀘스트 레벨이 캐릭터 레벨보다 3 높거나 낮은 경우)";
L["Quest Type Trivial"] = "저레벨";
L["Quest Type Dungeon"] = "던전";
L["Quest Type Raid"] = "레이드";
L["Quest Type Heroic"] = "영웅";
L["Quest Type Elite"] = "정예";
L["Quest Type Group"] = "파티";
L["Quest Type PvP"] = "PvP";

-- Quest text
L["Quest Objectives"] = "목표";
L["Format Suggested Players"] = QUEST_SUGGESTED_GROUP_NUM or "추천 플레이어 [%d]";
L["Quest Accepted Alert"] = ERR_QUEST_ACCEPTED_S or "퀘스트 수락: %s";

-- Rewards
L["Reward"] = "보상";
L["Rewards"] = "보상들";
L["Reward Choose"] = REWARD_CHOOSE or "보상을 선택하세요:";
L["Reward Choices"] = REWARD_CHOICES or "다음 보상 중 하나를 선택할 수 있습니다:";
L["Reward Items"] = REWARD_ITEMS or "추가로 다음을 받게 됩니다:";
L["Requirements"] = "요구 사항들";
L["Money"] = MONEY or "돈";
L["Honor Points"] = "명예";
L["Arena Points"] = "투기장 점수";
L["Talent Points"] = "특성 포인트";
L["Experience"] = "경험치";
L["Title"] = "칭호";
L["Format Talent Point Row"] = "+%d 특성 포인트";
L["Format Talent Points Row"] = "+%d 특성 포인트";

-- Reward tooltip
L["Show Comparison"] = "비교 표시";
L["Hide Comparison"] = "비교 숨기기";
L["Sell Price"] = SELL_PRICE or "판매 가격";
L["Format Item Level"] = ITEM_LEVEL or "아이템 레벨 %d";
L["Format You Have"] = "- 보유: |cffffffff%d|r";
L["Format In Bank"] = " (은행에 |cffffffff%d|r)";
L["Format Replace Item"] = "교체 %s";
L["Equipped Item"] = "장착한 아이템";
L["Currently Equipped"] = "현재 착용 중";
L["Different Item Type"] = "장착한 아이템과 종류가 다릅니다.";
L["Identical Stats"] = "능력치 동일";
L["Format Reward Title"] = "「%s」 칭호를 받게 됩니다.";
L["Format Reward Honor"] = "명예 점수 %d점을 받습니다.";
L["Format Reward Talent Point"] = "특성 포인트 %d점을 받습니다.";
L["Format Reward Talent Points"] = "특성 포인트 %d점을 받습니다.";
L["Format Reward Arena"] = "투기장 점수 %d점을 받습니다.";
L["Format Reward Experience"] = "경험치 %d을(를) 얻습니다%s.";
L["Format Of Your Level"] = " (현재 레벨의 %d%%)";

-- Quest Item Display
L["Quest Item Display"] = "퀘스트 아이템 표시";
L["Quest Item Display Desc"] = "퀘스트 항목의 설명을 자동으로 표시하고 가방을 열지 않고도 사용할 수 있도록 합니다.";
L["Quest Item Display Hide Seen"] = "표시된 아이템 무시";
L["Quest Item Display Hide Seen Desc"] = "캐릭터가 발견한 아이템은 무시합니다.";
L["Quest Item Display Await World Map"] = " 월드맵을 기다립니다.";
L["Quest Item Display Await World Map Desc"] = "월드맵를 열면 퀘스트 항목 표시를 일시적으로 숨기고 자동 닫기 타이머를 일시 중지합니다.";
L["Quest Item Display Reset Position Desc"] = "창의 위치를 재설정합니다.";
L["Valuable Reward Popup"] = "가치 있는 보상 팝업 (Pawn 필요)";
L["Valuable Reward Popup Sample"] = "가치 있는 보상 팝업";
L["Valuable Reward Popup Desc"] = "퀘스트로 Pawn 애드온 기준 캐릭터에게 업그레이드인 아이템을 받으면, 바로 장착할 수 있는 버튼을 표시합니다.\n\n전투 중에는 버튼이 비활성화됩니다.";
L["Item Equipped"] = "착용 중";
L["Press Key To Use Item"] = "버튼을 눌러 실행";
L["Press Key To Use Item Desc Generic"] = "비전투 중에 확인 버튼(현재: %s)을 누르면 아이템을 사용합니다.";
L["Press Key To Use Item Desc PC"] = "비전투 중에 스페이스바를 누르면 아이템을 사용합니다.";
L["Click To Read"] = "왼쪽 클릭하여 읽기";
L["Begins A Quest"] = "퀘스트 시작";

-- Supported addons
L["Format Reward Title Row"] = "칭호: %s";
L["On Your Gear List"] = "장비 목록에 있음";
L["Format Exchange It For"] = "교환 대상: %s";
