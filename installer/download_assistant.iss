; מסייע ההורדה של אוצריא — Otzaria-Download-Assistant-windows.exe
;
; הכלי הזה אינו מתקין את אוצריא ואינו מתקין שום דבר: הוא אינו כותב לרישום,
; אינו יוצר קיצורי דרך ואין לו מסיר. כל תפקידו להוריד את הקבצים הדרושים
; מ-release של אוצריא ב-GitHub, לאמת אותם, ולהכין מהם התקנה — במחשב הזה או
; בתיקייה שאפשר להעתיק למחשב מנותק.
;
; שתי אבני היסוד:
;   * מניפסט ה-release (tool/release/generate_release_manifest.dart) הוא מקור
;     האמת היחיד. שום שם נכס אינו מקודד כאן: הרכיבים, הגדלים וה-hash מגיעים
;     ממנו. תג ה-release נקבע פעם אחת בתחילת הריצה ונשמר עד סופה.
;   * הרכבת נכס מפוצל לקובץ אחד היא שרשור בתים טהור דרך TFileStream, בלי
;     PowerShell ובלי כלים חיצוניים. נמדד: 2.4GB ב-6.5 שניות.

; תג ה-release שממנו נבנה הכלי. ה-workflow מעביר אותו ב-‎/DAssistantReleaseTag‎.
; בלעדיו (בנייה מקומית) הכלי נופל חזרה ל-‎/releases/latest‎ בלבד.
#ifndef AssistantReleaseTag
  #define AssistantReleaseTag ""
#endif

; החלק ‎X.Y.Z‎ של התג, לתצוגה במאפייני הקובץ. בלי תג מוטבע אין מה להציג.
#define TagVersionPart AssistantReleaseTag
#if Pos("+", TagVersionPart) > 0
  #define TagVersionPart Copy(TagVersionPart, 1, Pos("+", TagVersionPart) - 1)
#endif

[Setup]
AppId={{9A6B5F2E-7C31-4E18-9D44-1F0B8C3A5D72}
AppName=אוצריא — מסייע הורדה
; גרסת הכלי עצמו. היא אינה גרסת אוצריא: תג אוצריא מוטבע ב-AssistantReleaseTag
; בזמן הבנייה, ולכן tool/version/update_version אינו נוגע בקובץ הזה.
AppVersion=1.0
AppPublisher=sivan22
AppPublisherURL=https://github.com/otzaria/otzaria
; אינו מתקין: בלי תיקיית התקנה, בלי מסיר, בלי רישום ובלי קיצורי דרך.
CreateAppDir=no
Uninstallable=no
CreateUninstallRegKey=no
DisableWelcomePage=yes
DisableProgramGroupPage=yes
DisableReadyPage=no
PrivilegesRequired=lowest
OutputDir=.\
; שם הנכס חייב להישאר ASCII: GitHub מוחק תווים שאינם ‎[A-Za-z0-9._-]‎ משם נכס
; שמועלה. הזיהוי העברי מגיע ממאפייני הקובץ שלמטה.
OutputBaseFilename=Otzaria-Download-Assistant-windows
VersionInfoProductName=מסייע הורדה לאוצריא
VersionInfoDescription=מוריד את קובצי אוצריא ומכין מהם התקנה. אינו מתקין את אוצריא.
VersionInfoCompany=sivan22
#if TagVersionPart != ""
VersionInfoProductTextVersion={#TagVersionPart}
#endif
SetupIconFile=white_sketch128x128.ico
WizardImageFile=wizard_large.bmp,wizard_large@2x.bmp,wizard_large@3x.bmp
; Inno טוען BMP בלי אלפא: אייקון שקוף שנשמר כך מקבל רקע שחור. הקבצים האלה
; נשטחו מראש על לבן, ולכן הם נפרדים מאלה של המתקינים.
WizardSmallImageFile=wizard_small_white.bmp,wizard_small_white@2x.bmp,wizard_small_white@3x.bmp
WizardStyle=modern
Compression=lzma
SolidCompression=yes
SetupLogging=yes
; ההרכבה קוראת וכותבת קבצים של גיגה-בתים — אין טעם לאפשר 32-bit בלבד.
ArchitecturesAllowed=x64compatible or arm64

[Languages]
Name: "hebrew"; MessagesFile: "compiler:Languages\Hebrew.isl"

; ברירות המחדל של Inno מנוסחות כמתקין ("מתקין את...", "תוכנת ההתקנה"), והכלי
; הזה אינו מתקין דבר. כל מחרוזת כזאת שמופיעה במסך כלשהו מוחלפת כאן.
[Messages]
SetupAppTitle=אוצריא — מסייע הורדה
SetupWindowTitle=אוצריא — מסייע הורדה
SetupLdrStartupMessage=הכלי יוריד את קובצי אוצריא ויכין מהם התקנה. להמשיך?
ButtonInstall=&התחל
WizardReady=הכול מוכן
ReadyLabel1=הכול מוכן להורדה.
ReadyLabel2a=לחץ "התחל" כדי להוריד את הקבצים ולהכין מהם התקנה, או "הקודם" כדי לשנות את הבחירה.
ReadyLabel2b=לחץ "התחל" כדי להוריד את הקבצים ולהכין מהם התקנה.
WizardPreparing=רגע לפני ההתחלה
PreparingDesc=המסייע נערך להורדה.
WizardInstalling=הורדה והכנה
InstallingLabel=הקבצים יורדים מאתר אוצריא ונבדקים. אפשר לעצור בכל רגע.
StatusCreateDirs=מכין את התיקייה...
StatusExtractFiles=מעתיק קבצים...
StatusSavingUninstall=שומר נתונים...
StatusRunProgram=מסיים...
FinishedHeadingLabel=הפעולה הסתיימה
FinishedLabel=הפעולה הסתיימה.
FinishedLabelNoIcons=הפעולה הסתיימה.
ClickFinish=לחץ "סיים" לסגירת המסייע.
SetupAborted=הפעולה לא הושלמה.%n%nאפשר להפעיל את המסייע שוב; מה שכבר ירד יישמר.
ExitSetupTitle=יציאה מהמסייע
ExitSetupMessage=ההורדה לא הושלמה. קבצים שכבר ירדו יישמרו, והפעלה חוזרת תמשיך מהמקום שבו הפסקת.%n%nלצאת עכשיו?

[Code]
function SetEndOfFile(hFile: THandle): BOOL;
  external 'SetEndOfFile@kernel32.dll stdcall';

const
  { מגבלת GitHub לנכס בודד. נכס גדול ממנה מתפרסם כחלקים. }
  GithubAssetLimit = 2147483648;
  { Windows מסרב להריץ קובץ הפעלה בגודל 4 GiB ומעלה (ERROR_BAD_EXE_FORMAT). }
  MaxRunnableExeSize = 4294967296;
  CopyChunkSize = 4194304;
  ManifestSchemaVersion = 1;

  ModeThisComputer = 0;
  ModeOtherComputer = 1;

  { תוצאה של כמה קבצים מקבלת תיקייה משלה, כדי שלא תתערבב במה שכבר נמצא שם. }
  OutputSubFolderName = 'אוצריא להתקנה';

type
  TInt64Array = array of Int64;

var
  { --- מה שנקרא מה-release --- }
  PinnedTag: String;
  ReleaseVersion: String;
  ManifestLoaded: Boolean;
  LoadErrorHeb: String;
  LoadErrorTech: String;

  CompId, CompName, CompDesc, CompType, CompPlatform, CompArch,
    CompDependsOn: TArrayOfString;
  CompRequired, CompSelected: array of Boolean;
  CompDownloadSize: TInt64Array;
  CompAssetStart, CompAssetCount: array of Integer;

  AssetKind, AssetRepo, AssetTag, AssetName, AssetSha: TArrayOfString;
  AssetSize: TInt64Array;
  AssetPartStart, AssetPartCount: array of Integer;

  PartName, PartSha: TArrayOfString;
  PartSize: TInt64Array;

  { --- הצעות מוכנות, נגזרות מהמניפסט --- }
  PresetLabel, PresetDesc, PresetMembers: TArrayOfString;

  { --- מצב האשף --- }
  ModePage: TInputOptionWizardPage;
  ArchPage: TInputOptionWizardPage;
  PresetPage: TInputOptionWizardPage;
  CustomPage: TInputOptionWizardPage;
  FolderPage: TInputDirWizardPage;
  DownloadPage: TDownloadWizardPage;
  WorkPage: TOutputProgressWizardPage;
  CustomIndex: array of Integer;
  CustomPresetIndex: Integer;
  ResultText: String;
  RunAfterExe: String;
  RevealPath: String;
  RevealIsFile: Boolean;
  RevealCheck: TNewCheckBox;

  { --- תור ההורדה של הריצה הנוכחית --- }
  QueueUrl, QueueFile, QueueSha, QueueLabel: TArrayOfString;
  QueueSize: TInt64Array;
  ProgressCaption: String;
  ProgressDone, ProgressTotal: Int64;

{ ============================ עזרי טקסט ============================ }

function EndsWithText(const S, Suffix: String): Boolean;
begin
  Result := (Length(Suffix) <= Length(S)) and
    (Lowercase(Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix))) =
      Lowercase(Suffix));
end;

{ גודל בעברית קריאה. אין "בתים" ואין קיצורים לועזיים בעמודים הרגילים. }
function HumanSize(Bytes: Int64): String;
var
  Tenths: Int64;
begin
  if Bytes >= Int64(1073741824) then
  begin
    Tenths := (Bytes * 10) div Int64(1073741824);
    Result := IntToStr(Tenths div 10) + '.' + IntToStr(Tenths mod 10) +
      ' ג׳יגה';
  end
  else if Bytes >= 1048576 then
    Result := IntToStr(Bytes div 1048576) + ' מגה'
  else
    Result := IntToStr((Bytes + 1023) div 1024) + ' קילו';
end;

function IsExecutableName(const Name: String): Boolean;
begin
  Result := EndsWithText(Name, '.exe');
end;

{ ====================== קורא JSON מינימלי ======================

  פועל על מחרוזת הבתים כפי שירדה. כל תווי המבנה של JSON הם ASCII וכל בית
  של רצף UTF-8 רב-בתי הוא 80 ומעלה, ולכן סריקה בבתים בטוחה; רק הערכים
  שחולצו עוברים Utf8Decode. }

{ מיקום 0 הוא "לא נמצא" מכל העזרים כאן, ולכן הוא מתורגם למיקום שמעבר לסוף
  ולא לגישה מחוץ לתחום. }
function JSkipWs(const S: AnsiString; P: Integer): Integer;
begin
  if P < 1 then
  begin
    Result := Length(S) + 1;
    exit;
  end;
  while (P <= Length(S)) and (S[P] <= ' ') do
    P := P + 1;
  Result := P;
end;

{ P על מרכאות הפתיחה; מחזיר את המיקום שאחרי מרכאות הסגירה. }
function JSkipString(const S: AnsiString; P: Integer): Integer;
begin
  if P < 1 then
  begin
    Result := Length(S) + 1;
    exit;
  end;
  P := P + 1;
  while P <= Length(S) do
  begin
    if S[P] = '\' then
      P := P + 2
    else if S[P] = '"' then
    begin
      Result := P + 1;
      exit;
    end
    else
      P := P + 1;
  end;
  Result := P;
end;

function JSkipValue(const S: AnsiString; P: Integer): Integer;
var
  Depth: Integer;
begin
  P := JSkipWs(S, P);
  if P > Length(S) then
  begin
    Result := P;
    exit;
  end;
  if S[P] = '"' then
  begin
    Result := JSkipString(S, P);
    exit;
  end;
  if (S[P] = '{') or (S[P] = '[') then
  begin
    Depth := 0;
    while P <= Length(S) do
    begin
      if S[P] = '"' then
        P := JSkipString(S, P)
      else
      begin
        if (S[P] = '{') or (S[P] = '[') then
          Depth := Depth + 1
        else if (S[P] = '}') or (S[P] = ']') then
        begin
          Depth := Depth - 1;
          if Depth = 0 then
          begin
            Result := P + 1;
            exit;
          end;
        end;
        P := P + 1;
      end;
    end;
    Result := P;
    exit;
  end;
  while (P <= Length(S)) and (S[P] > ' ') and (S[P] <> ',') and
        (S[P] <> '}') and (S[P] <> ']') do
    P := P + 1;
  Result := P;
end;

{ ערך גולמי של מחרוזת JSON ש-P מצביע על מרכאות הפתיחה שלה. }
function JRawString(const S: AnsiString; P: Integer): AnsiString;
var
  C: AnsiChar;
begin
  Result := '';
  if P < 1 then
    exit;
  P := P + 1;
  while P <= Length(S) do
  begin
    C := S[P];
    if C = '"' then
      exit;
    if C = '\' then
    begin
      P := P + 1;
      if P > Length(S) then
        exit;
      C := S[P];
      if C = 'n' then
        Result := Result + #10
      else if C = 't' then
        Result := Result + #9
      else if C = 'r' then
        Result := Result + #13
      else if C = 'u' then
      begin
        { \uXXXX אינו מופיע בפלט של הגנרטור; נשמר כסימן שאלה ולא נבלע. }
        Result := Result + '?';
        P := P + 4;
      end
      else
        Result := Result + C;
    end
    else
      Result := Result + C;
    P := P + 1;
  end;
end;

{ ObjPos על '{'. מחזיר את מיקום הערך של Key, או 0. }
function JFind(const S: AnsiString; ObjPos: Integer; const Key: AnsiString): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := JSkipWs(S, ObjPos);
  if (P > Length(S)) or (S[P] <> '{') then
    exit;
  P := P + 1;
  while True do
  begin
    P := JSkipWs(S, P);
    if (P > Length(S)) or (S[P] = '}') then
      exit;
    if S[P] <> '"' then
      exit;
    if JRawString(S, P) = Key then
    begin
      P := JSkipWs(S, JSkipString(S, P));
      if (P > Length(S)) or (S[P] <> ':') then
        exit;
      Result := JSkipWs(S, P + 1);
      exit;
    end;
    P := JSkipWs(S, JSkipString(S, P));
    if (P > Length(S)) or (S[P] <> ':') then
      exit;
    P := JSkipValue(S, P + 1);
    P := JSkipWs(S, P);
    if (P <= Length(S)) and (S[P] = ',') then
      P := P + 1
    else
      exit;
  end;
end;

function JArrFirst(const S: AnsiString; ArrPos: Integer): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := JSkipWs(S, ArrPos);
  if (P > Length(S)) or (S[P] <> '[') then
    exit;
  P := JSkipWs(S, P + 1);
  if (P <= Length(S)) and (S[P] <> ']') then
    Result := P;
end;

function JArrNext(const S: AnsiString; ElemPos: Integer): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := JSkipWs(S, JSkipValue(S, ElemPos));
  if (P > Length(S)) or (S[P] <> ',') then
    exit;
  P := JSkipWs(S, P + 1);
  if (P <= Length(S)) and (S[P] <> ']') then
    Result := P;
end;

function JStr(const S: AnsiString; ObjPos: Integer; const Key: AnsiString): String;
var
  P: Integer;
begin
  Result := '';
  P := JFind(S, ObjPos, Key);
  if (P > 0) and (P <= Length(S)) and (S[P] = '"') then
    Result := Utf8Decode(JRawString(S, P));
end;

function JInt(const S: AnsiString; ObjPos: Integer; const Key: AnsiString): Int64;
var
  P, E: Integer;
begin
  Result := -1;
  P := JFind(S, ObjPos, Key);
  if P = 0 then
    exit;
  E := JSkipValue(S, P);
  Result := StrToInt64Def(Trim(Copy(S, P, E - P)), -1);
end;

function JBool(const S: AnsiString; ObjPos: Integer; const Key: AnsiString): Boolean;
var
  P, E: Integer;
begin
  Result := False;
  P := JFind(S, ObjPos, Key);
  if P = 0 then
    exit;
  E := JSkipValue(S, P);
  Result := Trim(Copy(S, P, E - P)) = 'true';
end;

{ ========================= כתובות ומטמון ========================= }

{ כתובת נכס נבנית תמיד מ-repository + releaseTag + שם קובץ, לעולם לא
  מכתובת חופשית. רק מאגרים בארגון Otzaria ב-github.com. }
function IsOtzariaRepository(const Repository: String): Boolean;
begin
  Result := (((Length(Repository) > 8) and (Copy(Repository, 1, 8) = 'Otzaria/')) or
    ((Length(Repository) > 9) and (Copy(Repository, 1, 9) = 'palmoni5/'))) and
    (Pos('/', Copy(Repository, Pos('/', Repository) + 1, Length(Repository))) = 0) and
    (Pos('..', Repository) = 0);
end;

function AssetUrl(const Repository, Tag, Name: String): String;
begin
  Result := '';
  if not IsOtzariaRepository(Repository) then
    exit;
  Result := 'https://github.com/' + Repository + '/releases/download/' + Tag +
    '/' + Name;
end;

function ReleaseApiUrl(const Path: String): String;
begin
  Result := 'https://api.github.com/repos/palmoni5/otzaria/releases/' + Path;
end;

{ החלק ה-X.Y.Z של תג. סיומת ‎+build‎ אינה משתתפת בהשוואה: שני תגים של אותה
  גרסה הם אותה גרסה, וסדר מספרי ה-run אינו סדר גרסאות. }
function VersionPart(const Tag: String): String;
var
  P: Integer;
begin
  Result := Trim(Tag);
  P := Pos('+', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1);
  if (Result <> '') and ((Result[1] = 'v') or (Result[1] = 'V')) then
    Result := Copy(Result, 2, Length(Result));
end;

{ 1 אם A גדול מ-B, ‎-1‎ אם קטן, 0 אם שווה. }
function CompareVersionText(const A, B: String): Integer;
var
  PA, PB: TArrayOfString;
  I, N, NA, NB: Integer;
  VA, VB: Int64;
begin
  Result := 0;
  PA := StringSplitEx(VersionPart(A), ['.'], #0, stExcludeEmpty);
  PB := StringSplitEx(VersionPart(B), ['.'], #0, stExcludeEmpty);
  NA := GetArrayLength(PA);
  NB := GetArrayLength(PB);
  if NA > NB then
    N := NA
  else
    N := NB;
  for I := 0 to N - 1 do
  begin
    if I < NA then
      VA := StrToInt64Def(PA[I], 0)
    else
      VA := 0;
    if I < NB then
      VB := StrToInt64Def(PB[I], 0)
    else
      VB := 0;
    if VA > VB then
    begin
      Result := 1;
      exit;
    end;
    if VA < VB then
    begin
      Result := -1;
      exit;
    end;
  end;
end;

function CacheDir(): String;
begin
  Result := ExpandConstant('{localappdata}\Otzaria\DownloadAssistant\cache');
end;

function CachePath(const Name: String): String;
begin
  Result := CacheDir() + '\' + Name;
end;

{ התיקייה שממנה הופעל המסייע — ברירת המחדל לשמירה. }
function AssistantDir(): String;
begin
  Result := RemoveBackslashUnlessRoot(
    ExtractFileDir(ExpandConstant('{srcexe}')));
end;

function FallbackOutputBase(): String;
begin
  Result := ExpandConstant('{userdocs}\אוצריא-להתקנה');
end;

{ כתיבה ממשית ולא ניחוש מהנתיב: דיסק-און-קי לקריאה בלבד, שיתוף רשת ותיקייה
  מוגנת נראים תקינים עד לניסיון הכתיבה הראשון. }
function DirIsWritable(const Dir: String): Boolean;
var
  Probe: String;
begin
  Result := False;
  if Dir = '' then
    exit;
  if not ForceDirectories(Dir) then
    exit;
  Probe := AddBackslash(Dir) + 'otzaria_write_test.tmp';
  DeleteFile(Probe);
  if not SaveStringToFile(Probe, 'otzaria', False) then
    exit;
  Result := FileExists(Probe);
  DeleteFile(Probe);
end;

{ קובץ במטמון נחשב מוכן רק כששני הגודל וה-sha256 תואמים למניפסט. }
function CachedFileIsGood(const Name: String; Size: Int64; const Sha: String): Boolean;
var
  Actual: Int64;
begin
  Result := False;
  if not FileExists(CachePath(Name)) then
    exit;
  if not FileSize64(CachePath(Name), Actual) then
    exit;
  if Actual <> Size then
    exit;
  Result := Lowercase(GetSHA256OfFile(CachePath(Name))) = Lowercase(Sha);
end;

{ מעביר קובץ שירד אל המטמון: קודם כשם זמני, ורק אחרי אימות גודל ו-sha256
  הוא מקבל את שמו הסופי. קובץ חלקי לעולם לא ייחשב כמי שהורד. }
function PromoteToCache(const TempPath, Name: String; Size: Int64;
  const Sha: String): Boolean;
var
  Staged: String;
  Actual: Int64;
begin
  Result := False;
  ForceDirectories(CacheDir());
  Staged := CachePath(Name) + '.tmp';
  DeleteFile(Staged);
  if not RenameFile(TempPath, Staged) then
    if not FileCopy(TempPath, Staged, False) then
      exit;
  if FileSize64(Staged, Actual) and (Actual = Size) and
     (Lowercase(GetSHA256OfFile(Staged)) = Lowercase(Sha)) then
  begin
    DeleteFile(CachePath(Name));
    Result := RenameFile(Staged, CachePath(Name));
  end;
  if not Result then
    DeleteFile(Staged);
end;

{ ========================= קריאת המניפסט ========================= }

function ParseManifest(const Raw: AnsiString): Boolean;
var
  CompPos, AssetPos, PartPos, ArrPos: Integer;
  NC, NA, NP: Integer;
  Schema: Int64;
  Deps, Dep: String;
  DepPos: Integer;
begin
  Result := False;
  Schema := JInt(Raw, 1, 'schemaVersion');
  if Schema <> ManifestSchemaVersion then
  begin
    LoadErrorTech := 'schemaVersion=' + IntToStr(Schema);
    exit;
  end;
  PinnedTag := JStr(Raw, 1, 'releaseTag');
  ReleaseVersion := JStr(Raw, 1, 'releaseVersion');
  if (PinnedTag = '') or (ReleaseVersion = '') then
  begin
    LoadErrorTech := 'missing releaseTag/releaseVersion';
    exit;
  end;

  ArrPos := JFind(Raw, 1, 'components');
  if ArrPos = 0 then
  begin
    LoadErrorTech := 'no components';
    exit;
  end;

  NC := 0;
  NA := 0;
  NP := 0;
  CompPos := JArrFirst(Raw, ArrPos);
  while CompPos > 0 do
  begin
    SetArrayLength(CompId, NC + 1);
    SetArrayLength(CompName, NC + 1);
    SetArrayLength(CompDesc, NC + 1);
    SetArrayLength(CompType, NC + 1);
    SetArrayLength(CompPlatform, NC + 1);
    SetArrayLength(CompArch, NC + 1);
    SetArrayLength(CompDependsOn, NC + 1);
    SetArrayLength(CompRequired, NC + 1);
    SetArrayLength(CompSelected, NC + 1);
    SetArrayLength(CompDownloadSize, NC + 1);
    SetArrayLength(CompAssetStart, NC + 1);
    SetArrayLength(CompAssetCount, NC + 1);

    CompId[NC] := JStr(Raw, CompPos, 'id');
    CompName[NC] := JStr(Raw, CompPos, 'name');
    CompDesc[NC] := JStr(Raw, CompPos, 'description');
    CompType[NC] := JStr(Raw, CompPos, 'type');
    CompPlatform[NC] := JStr(Raw, CompPos, 'platform');
    CompArch[NC] := JStr(Raw, CompPos, 'architecture');
    CompRequired[NC] := JBool(Raw, CompPos, 'required');
    CompDownloadSize[NC] := JInt(Raw, CompPos, 'downloadSize');
    CompSelected[NC] := False;

    Deps := '';
    DepPos := JArrFirst(Raw, JFind(Raw, CompPos, 'dependsOn'));
    while DepPos > 0 do
    begin
      if Raw[DepPos] = '"' then
      begin
        Dep := Utf8Decode(JRawString(Raw, DepPos));
        Deps := Deps + Dep + ',';
      end;
      DepPos := JArrNext(Raw, DepPos);
    end;
    CompDependsOn[NC] := Deps;

    CompAssetStart[NC] := NA;
    AssetPos := JArrFirst(Raw, JFind(Raw, CompPos, 'assets'));
    while AssetPos > 0 do
    begin
      SetArrayLength(AssetKind, NA + 1);
      SetArrayLength(AssetRepo, NA + 1);
      SetArrayLength(AssetTag, NA + 1);
      SetArrayLength(AssetName, NA + 1);
      SetArrayLength(AssetSha, NA + 1);
      SetArrayLength(AssetSize, NA + 1);
      SetArrayLength(AssetPartStart, NA + 1);
      SetArrayLength(AssetPartCount, NA + 1);

      AssetKind[NA] := JStr(Raw, AssetPos, 'kind');
      AssetRepo[NA] := JStr(Raw, AssetPos, 'repository');
      AssetTag[NA] := JStr(Raw, AssetPos, 'releaseTag');
      AssetName[NA] := JStr(Raw, AssetPos, 'name');
      AssetSha[NA] := JStr(Raw, AssetPos, 'sha256');
      AssetSize[NA] := JInt(Raw, AssetPos, 'size');
      AssetPartStart[NA] := NP;

      PartPos := JArrFirst(Raw, JFind(Raw, AssetPos, 'parts'));
      while PartPos > 0 do
      begin
        SetArrayLength(PartName, NP + 1);
        SetArrayLength(PartSha, NP + 1);
        SetArrayLength(PartSize, NP + 1);
        PartName[NP] := JStr(Raw, PartPos, 'name');
        PartSha[NP] := JStr(Raw, PartPos, 'sha256');
        PartSize[NP] := JInt(Raw, PartPos, 'size');
        NP := NP + 1;
        PartPos := JArrNext(Raw, PartPos);
      end;
      AssetPartCount[NA] := NP - AssetPartStart[NA];

      if (AssetName[NA] = '') or (Length(AssetSha[NA]) <> 64) or
         (AssetSize[NA] <= 0) or (AssetUrl(AssetRepo[NA], AssetTag[NA],
           AssetName[NA]) = '') then
      begin
        LoadErrorTech := 'bad asset in component ' + CompId[NC];
        exit;
      end;
      if (AssetKind[NA] = 'split') and (AssetPartCount[NA] = 0) then
      begin
        LoadErrorTech := 'split asset without parts: ' + AssetName[NA];
        exit;
      end;

      NA := NA + 1;
      AssetPos := JArrNext(Raw, AssetPos);
    end;
    CompAssetCount[NC] := NA - CompAssetStart[NC];

    if (CompId[NC] = '') or (CompName[NC] = '') or (CompAssetCount[NC] = 0) then
    begin
      LoadErrorTech := 'component without id/name/assets';
      exit;
    end;

    NC := NC + 1;
    CompPos := JArrNext(Raw, CompPos);
  end;

  Result := NC > 0;
  if not Result then
    LoadErrorTech := 'manifest has no components';
end;

{ JSON של release, או '' בכישלון הורדה/קריאה. }
function FetchReleaseJson(const Url, FileName: String): AnsiString;
var
  Raw: AnsiString;
begin
  Result := '';
  try
    DownloadTemporaryFile(Url, FileName, '', nil);
  except
    LoadErrorTech := GetExceptionMessage;
    exit;
  end;
  if LoadStringFromFile(ExpandConstant('{tmp}\') + FileName, Raw) then
    Result := Raw
  else
    LoadErrorTech := 'cannot read ' + FileName;
end;

{ תג ה-release נקבע כאן פעם אחת ונשמר לכל הריצה: release שמתעדכן באמצע
  הורדה היה מערבב קבצים משתי גרסאות.

  ברירת המחדל היא התג שממנו נבנה הכלי — release כזה בוודאי נושא מניפסט.
  ‎/releases/latest‎ מדלג על prerelease, ולכן הוא משמש רק כשהוא מצביע על
  גרסה גבוהה יותר; כשהוא נכשל או שווה/נמוך, התג המוטבע נשאר. }
function LoadReleaseManifest(): Boolean;
var
  ApiRaw, ManifestRaw: AnsiString;
  ManifestPath, ManifestAsset, Url: String;
  EmbeddedTag, LatestTag: String;
  AssetsPos, ElemPos: Integer;
  Name: String;
begin
  Result := False;
  LoadErrorHeb := 'לא ניתן לקרוא את רשימת הקבצים של אוצריא.';

  EmbeddedTag := Trim('{#AssistantReleaseTag}');
  ApiRaw := FetchReleaseJson(ReleaseApiUrl('latest'), 'release.json');
  if ApiRaw <> '' then
    LatestTag := JStr(ApiRaw, 1, 'tag_name')
  else
    LatestTag := '';

  if EmbeddedTag = '' then
    PinnedTag := LatestTag
  else if (LatestTag <> '') and
          (CompareVersionText(LatestTag, EmbeddedTag) > 0) then
    PinnedTag := LatestTag
  else
    PinnedTag := EmbeddedTag;

  Log('DownloadAssistant: embedded=' + EmbeddedTag + ' latest=' + LatestTag +
    ' pinned=' + PinnedTag);
  if PinnedTag = '' then
  begin
    LoadErrorHeb := 'לא ניתן להתחבר לאתר ההורדות של אוצריא.';
    if LoadErrorTech = '' then
      LoadErrorTech := 'release has no tag_name';
    exit;
  end;

  if PinnedTag <> LatestTag then
  begin
    ApiRaw := FetchReleaseJson(ReleaseApiUrl('tags/' + PinnedTag),
      'release_pinned.json');
    if ApiRaw = '' then
    begin
      LoadErrorHeb := 'לא ניתן להתחבר לאתר ההורדות של אוצריא.';
      exit;
    end;
  end;

  ManifestAsset := '';
  AssetsPos := JFind(ApiRaw, 1, 'assets');
  ElemPos := JArrFirst(ApiRaw, AssetsPos);
  while ElemPos > 0 do
  begin
    Name := JStr(ApiRaw, ElemPos, 'name');
    if EndsWithText(Name, 'release-manifest.json') then
    begin
      ManifestAsset := Name;
      Break;
    end;
    ElemPos := JArrNext(ApiRaw, ElemPos);
  end;
  if ManifestAsset = '' then
  begin
    LoadErrorTech := 'release ' + PinnedTag + ' has no release-manifest asset';
    exit;
  end;

  Url := AssetUrl('palmoni5/otzaria', PinnedTag, ManifestAsset);
  try
    DownloadTemporaryFile(Url, 'manifest.json', '', nil);
  except
    LoadErrorTech := GetExceptionMessage;
    exit;
  end;
  ManifestPath := ExpandConstant('{tmp}\manifest.json');
  if not LoadStringFromFile(ManifestPath, ManifestRaw) then
  begin
    LoadErrorTech := 'cannot read manifest.json';
    exit;
  end;
  Result := ParseManifest(ManifestRaw);
end;

{ ====================== הצעות מוכנות מהמניפסט ======================

  ההצעות נגזרות מ-type ומ-required של הרכיבים, לא משמות קבצים: רכיב חדש
  במניפסט נוחת בהצעה הנכונה בלי שינוי קוד כאן. הצעה שיצאה ריקה, או שיצאה
  זהה להצעה שכבר נוספה, אינה מוצגת — בדיוק כמו רכיב שאינו במניפסט. }

function TargetArch(): String;
begin
  if ModePage.SelectedValueIndex = ModeThisComputer then
  begin
    if IsArm64 then
      Result := 'arm64'
    else
      Result := 'x64';
  end
  else if ArchPage.SelectedValueIndex = 1 then
    Result := 'arm64'
  else
    Result := 'x64';
end;

{ רכיב רלוונטי למחשב היעד: פלטפורמה וארכיטקטורה תואמות, או לא מוגדרות. }
function ComponentFitsTarget(Index: Integer): Boolean;
begin
  Result := False;
  if (CompPlatform[Index] <> '') and (CompPlatform[Index] <> 'any') and
     (CompPlatform[Index] <> 'windows') then
    exit;
  if (CompArch[Index] <> '') and (CompArch[Index] <> 'any') and
     (CompArch[Index] <> TargetArch()) then
    exit;
  Result := True;
end;

function IndexOfComponent(const Id: String): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to GetArrayLength(CompId) - 1 do
    if CompId[I] = Id then
    begin
      Result := I;
      exit;
    end;
end;

function MembersContain(const Members, Id: String): Boolean;
begin
  Result := Pos(',' + Id + ',', ',' + Members) > 0;
end;

{ סוגר את הרכיבים שהרכיב תלוי בהם — ההתקנה לא שלמה בלעדיהם. }
function WithDependencies(const Members: String): String;
var
  Changed: Boolean;
  I, J, Idx: Integer;
  Parts: TArrayOfString;
begin
  Result := Members;
  Changed := True;
  while Changed do
  begin
    Changed := False;
    for I := 0 to GetArrayLength(CompId) - 1 do
    begin
      if not MembersContain(Result, CompId[I]) then
        Continue;
      Parts := StringSplitEx(CompDependsOn[I], [','], #0, stExcludeEmpty);
      for J := 0 to GetArrayLength(Parts) - 1 do
      begin
        Idx := IndexOfComponent(Parts[J]);
        if (Idx >= 0) and ComponentFitsTarget(Idx) and
           not MembersContain(Result, Parts[J]) then
        begin
          Result := Result + Parts[J] + ',';
          Changed := True;
        end;
      end;
    end;
  end;
end;

function MembersSize(const Members: String): Int64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to GetArrayLength(CompId) - 1 do
    if MembersContain(Members, CompId[I]) then
      Result := Result + CompDownloadSize[I];
end;

{ צורה קנונית: כל מזהה פעם אחת, בסדר הרכיבים שבמניפסט. בלעדיה שתי הצעות
  שמכילות בדיוק את אותם רכיבים נראות שונות ושתיהן מוצגות. }
function CanonicalMembers(const Members: String): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to GetArrayLength(CompId) - 1 do
    if MembersContain(Members, CompId[I]) then
      Result := Result + CompId[I] + ',';
end;

procedure AddPreset(const Caption, Description, Members: String);
var
  N, I: Integer;
  Closed: String;
begin
  if Members = '' then
    exit;
  Closed := CanonicalMembers(WithDependencies(Members));
  if Closed = '' then
    exit;
  for I := 0 to GetArrayLength(PresetMembers) - 1 do
    if PresetMembers[I] = Closed then
      exit;
  N := GetArrayLength(PresetLabel);
  SetArrayLength(PresetLabel, N + 1);
  SetArrayLength(PresetDesc, N + 1);
  SetArrayLength(PresetMembers, N + 1);
  PresetLabel[N] := Caption + ' — ' + HumanSize(MembersSize(Closed));
  PresetDesc[N] := Description;
  PresetMembers[N] := Closed;
end;

function CollectByTypes(const Types: String; RequiredOnly: Boolean): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to GetArrayLength(CompId) - 1 do
  begin
    if not ComponentFitsTarget(I) then
      Continue;
    if RequiredOnly and not CompRequired[I] then
      Continue;
    if (Types <> '') and not MembersContain(Types, CompType[I]) then
      Continue;
    Result := Result + CompId[I] + ',';
  end;
end;

procedure BuildPresets();
var
  Bundle, I: Integer;
  Members: String;
begin
  SetArrayLength(PresetLabel, 0);
  SetArrayLength(PresetDesc, 0);
  SetArrayLength(PresetMembers, 0);

  { מלאה: חבילה אחת שכוללת הכול אם קיימת כזו, אחרת התוכנה עם הספרייה. }
  Bundle := -1;
  for I := 0 to GetArrayLength(CompId) - 1 do
    if ComponentFitsTarget(I) and (CompType[I] = 'application-bundle') and
       ((Bundle < 0) or (CompDownloadSize[I] > CompDownloadSize[Bundle])) then
      Bundle := I;
  if Bundle >= 0 then
    Members := CompId[Bundle] + ','
  else
    Members := CollectByTypes('application,library,dependency,', False);
  AddPreset('התקנה מלאה ומומלצת',
    'התוכנה יחד עם ספריית הספרים — הבחירה המתאימה לרוב המשתמשים.', Members);

  AddPreset('התקנה בסיסית (תוכנה בלבד)',
    'התוכנה בלבד. את הספרים אפשר להוריד אחר כך מתוך התוכנה.',
    CollectByTypes('application,', False) + CollectByTypes('', True));

  AddPreset('עדכון התוכנה בלבד',
    'קובץ ההתקנה של הגרסה החדשה, לעדכון התקנה קיימת.',
    CollectByTypes('application,', False));

  { "בחירה אישית" אינה נגזרת מהמניפסט והיא תמיד האפשרות האחרונה. }
  CustomPresetIndex := GetArrayLength(PresetLabel);
end;

{ ============================== עמודים ============================== }

procedure ApplyPreset(Index: Integer);
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(CompId) - 1 do
    CompSelected[I] := (Index >= 0) and (Index < GetArrayLength(PresetMembers)) and
      MembersContain(PresetMembers[Index], CompId[I]);
end;

procedure RefreshPresetPage();
var
  I: Integer;
begin
  BuildPresets();
  PresetPage.CheckListBox.Items.Clear;
  for I := 0 to GetArrayLength(PresetLabel) - 1 do
  begin
    PresetPage.Add(PresetLabel[I]);
    PresetPage.CheckListBox.ItemSubItem[I] := PresetDesc[I];
  end;
  PresetPage.Add('בחירה אישית');
  PresetPage.CheckListBox.ItemSubItem[CustomPresetIndex] :=
    'אני רוצה לבחור בעצמי מה להוריד.';
  if PresetPage.SelectedValueIndex < 0 then
    PresetPage.SelectedValueIndex := 0;
end;

procedure RefreshCustomPage();
var
  I, N: Integer;
  Extra: String;
begin
  CustomPage.CheckListBox.Items.Clear;
  SetArrayLength(CustomIndex, 0);
  N := 0;
  for I := 0 to GetArrayLength(CompId) - 1 do
  begin
    if not ComponentFitsTarget(I) then
      Continue;
    if CompRequired[I] then
      Extra := ' (נדרש)'
    else
      Extra := '';
    CustomPage.Add(CompName[I] + ' — ' + HumanSize(CompDownloadSize[I]) + Extra);
    CustomPage.CheckListBox.ItemSubItem[N] := CompDesc[I];
    CustomPage.Values[N] := CompSelected[I] or CompRequired[I];
    SetArrayLength(CustomIndex, N + 1);
    CustomIndex[N] := I;
    N := N + 1;
  end;
end;

{ התקדמות כוללת: הקבצים יורדים אחד-אחד כדי שכל קובץ שהושלם ייכנס למטמון
  מיד, ולכן הסכום הכולל נשמר כאן ולא בעמוד עצמו. }
function OnDownloadProgress(const Url, FileName: String;
  const Progress, ProgressMax: Int64): Boolean;
begin
  DownloadPage.SetText(ProgressCaption,
    'סך הכול: ' + HumanSize(ProgressDone + Progress) + ' מתוך ' +
    HumanSize(ProgressTotal));
  Result := True;
end;

procedure InitializeWizard();
var
  DefaultBase, FolderNote: String;
begin
  ModePage := CreateInputOptionPage(wpWelcome,
    'אוצריא — מסייע הורדה',
    'כלי זה אינו מתקין את אוצריא.',
    'הכלי מאפשר להוריד את הקבצים הדרושים ולהכין התקנה עבור מחשב זה או עבור ' +
    'מחשב אחר.' + #13#10#13#10 + 'מה ברצונך לעשות?',
    True, False);
  ModePage.Add('הורדה והתקנה במחשב הזה');
  ModePage.Add('הכנת התקנה למחשב אחר');
  ModePage.SelectedValueIndex := ModeOtherComputer;

  ArchPage := CreateInputOptionPage(ModePage.ID,
    'המחשב שאליו מכינים',
    'איזה סוג מחשב הוא היעד?',
    'אם אינך יודע, בחר באפשרות הראשונה — היא מתאימה כמעט לכל המחשבים.',
    True, False);
  ArchPage.Add('מחשב רגיל');
  ArchPage.Add('מחשב עם מעבד מסוג ARM');
  ArchPage.SelectedValueIndex := 0;

  PresetPage := CreateInputOptionPage(ArchPage.ID,
    'מה להוריד',
    'בחר את היקף ההורדה.',
    'אפשר לשנות את הבחירה בהמשך.',
    True, False);

  CustomPage := CreateInputOptionPage(PresetPage.ID,
    'בחירה אישית',
    'סמן את הרכיבים שברצונך להוריד.',
    'ליד כל רכיב מופיע גודל ההורדה שלו.',
    False, True);

  DefaultBase := AssistantDir();
  FolderNote := '';
  if not DirIsWritable(DefaultBase) then
  begin
    DefaultBase := FallbackOutputBase();
    FolderNote := #13#10#13#10 + 'אי אפשר לשמור בתיקייה שממנה הופעל המסייע ' +
      '(למשל דיסק-און-קי לקריאה בלבד), ולכן הוצעה כאן תיקייה אחרת.';
  end;

  FolderPage := CreateInputDirPage(CustomPage.ID,
    'לאן לשמור',
    'כברירת מחדל התוצאה נשמרת ליד המסייע עצמו.',
    'אפשר לבחור תיקייה אחרת. בסיום אפשר יהיה להעתיק את התוצאה לדיסק-און-קי ' +
    'ולהעביר אותה למחשב המנותק.' + FolderNote,
    False, '');
  FolderPage.Add('');
  FolderPage.Values[0] := DefaultBase;

  DownloadPage := CreateDownloadPage('הורדת הקבצים',
    'הקבצים יורדים מאתר אוצריא. אפשר לעצור בכל רגע — מה שכבר ירד יישמר.',
    @OnDownloadProgress);
  WorkPage := CreateOutputProgressPage('הכנת ההתקנה',
    'רגע, מכינים את הקבצים.');
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if PageID = ArchPage.ID then
    Result := ModePage.SelectedValueIndex = ModeThisComputer
  else if PageID = CustomPage.ID then
    Result := PresetPage.SelectedValueIndex <> CustomPresetIndex
  else if PageID = FolderPage.ID then
    Result := ModePage.SelectedValueIndex = ModeThisComputer;
end;

{ ====================== בניית תור ההורדה ====================== }

procedure QueueAdd(const Url, FileName, Sha, Caption: String; Size: Int64);
var
  N: Integer;
begin
  N := GetArrayLength(QueueUrl);
  SetArrayLength(QueueUrl, N + 1);
  SetArrayLength(QueueFile, N + 1);
  SetArrayLength(QueueSha, N + 1);
  SetArrayLength(QueueLabel, N + 1);
  SetArrayLength(QueueSize, N + 1);
  QueueUrl[N] := Url;
  QueueFile[N] := FileName;
  QueueSha[N] := Sha;
  QueueLabel[N] := Caption;
  QueueSize[N] := Size;
end;

{ נכס מפוצל מורכב לקובץ אחד רק כשהתוצאה היא קובץ הפעלה שאפשר להריץ.
  ארכיון אינו מורכב: המתקין שצורך אותו מצפה לחלקים לצדו. }
function ShouldAssembleSingleFile(AssetIndex: Integer): Boolean;
begin
  Result := IsExecutableName(AssetName[AssetIndex]) and
    (AssetSize[AssetIndex] < MaxRunnableExeSize);
end;

{ כמה קבצים ייווצרו ביעד, לפי אותם כללים שמריץ PrepareOutput. }
function ProducedFileCount(): Integer;
var
  C, A: Integer;
begin
  Result := 0;
  for C := 0 to GetArrayLength(CompId) - 1 do
  begin
    if not CompSelected[C] then
      Continue;
    for A := CompAssetStart[C] to CompAssetStart[C] + CompAssetCount[C] - 1 do
      if (AssetKind[A] = 'split') and not ShouldAssembleSingleFile(A) then
        Result := Result + AssetPartCount[A]
      else
        Result := Result + 1;
  end;
end;

function OutputBaseDir(): String;
begin
  if ModePage.SelectedValueIndex = ModeThisComputer then
    Result := CacheDir()
  else
    Result := RemoveBackslashUnlessRoot(FolderPage.Values[0]);
end;

{ קובץ בודד יושב ישירות בתיקייה שנבחרה; כמה קבצים שחייבים להישאר יחד מקבלים
  תיקייה משלהם. }
function OutputDir(): String;
begin
  Result := OutputBaseDir();
  if (ModePage.SelectedValueIndex <> ModeThisComputer) and
     (ProducedFileCount() > 1) then
    Result := Result + '\' + OutputSubFolderName;
end;

{ הקובץ שכבר מורכב ביעד, אם הוא שלם ומאומת. }
function AssembledIsReady(AssetIndex: Integer): Boolean;
var
  Path: String;
  Size: Int64;
begin
  Path := OutputDir() + '\' + AssetName[AssetIndex];
  Result := FileExists(Path) and FileSize64(Path, Size) and
    (Size = AssetSize[AssetIndex]) and
    (Lowercase(GetSHA256OfFile(Path)) = Lowercase(AssetSha[AssetIndex]));
end;

{ כמה חלקים כבר נבלעו לתוך קובץ ההרכבה החלקי. חלק נמחק רק אחרי שהוספתו
  הושלמה, ולכן גודל הקובץ החלקי מזהה בדיוק היכן נעצרנו. }
function ConsumedPartCount(AssetIndex: Integer; var Prefix: Int64): Integer;
var
  TmpPath: String;
  Size, Acc: Int64;
  I: Integer;
begin
  Result := 0;
  Prefix := 0;
  TmpPath := OutputDir() + '\' + AssetName[AssetIndex] + '.tmp';
  if not FileExists(TmpPath) then
    exit;
  if not FileSize64(TmpPath, Size) then
    exit;
  Acc := 0;
  for I := 0 to AssetPartCount[AssetIndex] - 1 do
  begin
    if Acc + PartSize[AssetPartStart[AssetIndex] + I] > Size then
      Break;
    Acc := Acc + PartSize[AssetPartStart[AssetIndex] + I];
    Result := Result + 1;
    Prefix := Acc;
  end;
end;

{ בונה את תור ההורדה: מה שכבר במטמון ומאומת אינו נכנס אליו. }
function BuildQueue(): Boolean;
var
  C, A, P, First, Consumed: Integer;
  Prefix: Int64;
  Url: String;
begin
  SetArrayLength(QueueUrl, 0);
  SetArrayLength(QueueFile, 0);
  SetArrayLength(QueueSha, 0);
  SetArrayLength(QueueLabel, 0);
  SetArrayLength(QueueSize, 0);
  Result := True;

  WorkPage.SetText('בודק קבצים שכבר הורדו', '');
  WorkPage.Show;
  try
    for C := 0 to GetArrayLength(CompId) - 1 do
    begin
      if not CompSelected[C] then
        Continue;
      for A := CompAssetStart[C] to CompAssetStart[C] + CompAssetCount[C] - 1 do
      begin
        WorkPage.SetText('בודק קבצים שכבר הורדו', CompName[C]);
        if AssetKind[A] = 'split' then
        begin
          if ShouldAssembleSingleFile(A) and AssembledIsReady(A) then
            Continue;
          if ShouldAssembleSingleFile(A) then
            Consumed := ConsumedPartCount(A, Prefix)
          else
            Consumed := 0;
          First := AssetPartStart[A];
          for P := First + Consumed to First + AssetPartCount[A] - 1 do
          begin
            if CachedFileIsGood(PartName[P], PartSize[P], PartSha[P]) then
              Continue;
            Url := AssetUrl(AssetRepo[A], AssetTag[A], PartName[P]);
            if Url = '' then
            begin
              Result := False;
              LoadErrorTech := 'refusing non-Otzaria url for ' + PartName[P];
              exit;
            end;
            QueueAdd(Url, PartName[P], PartSha[P], CompName[C], PartSize[P]);
          end;
        end
        else
        begin
          if CachedFileIsGood(AssetName[A], AssetSize[A], AssetSha[A]) then
            Continue;
          Url := AssetUrl(AssetRepo[A], AssetTag[A], AssetName[A]);
          if Url = '' then
          begin
            Result := False;
            LoadErrorTech := 'refusing non-Otzaria url for ' + AssetName[A];
            exit;
          end;
          QueueAdd(Url, AssetName[A], AssetSha[A], CompName[C], AssetSize[A]);
        end;
      end;
    end;
  finally
    WorkPage.Hide;
  end;
end;

{ ============================== הורדה ============================== }

function RunDownloads(): Boolean;
var
  I: Integer;
begin
  Result := True;
  if GetArrayLength(QueueUrl) = 0 then
    exit;

  ProgressTotal := 0;
  ProgressDone := 0;
  for I := 0 to GetArrayLength(QueueUrl) - 1 do
    ProgressTotal := ProgressTotal + QueueSize[I];

  DownloadPage.ShowBaseNameInsteadOfUrl := True;
  DownloadPage.Show;
  try
    for I := 0 to GetArrayLength(QueueUrl) - 1 do
    begin
      ProgressCaption := 'מוריד: ' + QueueLabel[I] + ' (' + IntToStr(I + 1) +
        ' מתוך ' + IntToStr(GetArrayLength(QueueUrl)) + ')';
      DownloadPage.SetText(ProgressCaption, '');
      DownloadPage.Clear;
      { ה-hash מהמניפסט מועבר תמיד — קובץ שאינו תואם נדחה כאן ולא נשמר. }
      DownloadPage.Add(QueueUrl[I], QueueFile[I], QueueSha[I]);
      try
        DownloadPage.Download;
      except
        if DownloadPage.AbortedByUser then
          LoadErrorHeb := 'ההורדה הופסקה.'
        else
        begin
          LoadErrorHeb := 'לא ניתן להכין את ההתקנה משום שאחד הקבצים הדרושים ' +
            'אינו זמין.';
          LoadErrorTech := QueueFile[I] + ': ' + GetExceptionMessage;
        end;
        Result := False;
        exit;
      end;
      ProgressDone := ProgressDone + QueueSize[I];
      if not PromoteToCache(ExpandConstant('{tmp}\') + QueueFile[I],
        QueueFile[I], QueueSize[I], QueueSha[I]) then
      begin
        LoadErrorHeb := 'אחד הקבצים שהורדו נמצא פגום ולא נשמר.';
        LoadErrorTech := 'verification failed for ' + QueueFile[I];
        Result := False;
        exit;
      end;
    end;
  finally
    DownloadPage.Hide;
  end;
end;

{ ============================== הרכבה ============================== }

{ משרשר Src לסוף Dest. שרשור בתים טהור — התוצאה זהה בית-בית למקור. }
function AppendFileTo(const Dest, Src: String): Boolean;
var
  Output, Input: TFileStream;
begin
  Result := False;
  try
    if FileExists(Dest) then
      Output := TFileStream.Create(Dest, fmOpenWrite)
    else
      Output := TFileStream.Create(Dest, fmCreate);
    try
      Output.Seek(Int64(0), soFromEnd);
      Input := TFileStream.Create(Src, fmOpenRead or fmShareDenyWrite);
      try
        Output.CopyFrom(Input, Int64(0), CopyChunkSize);
      finally
        Input.Free;
      end;
    finally
      Output.Free;
    end;
    Result := True;
  except
    LoadErrorTech := 'append failed: ' + GetExceptionMessage;
  end;
end;

{ מקצץ קובץ חלקי חזרה לגבול חלק בין חלקים. Size של TStream הוא 32 סיביות
  ולכן הקיצוץ נעשה דרך Seek של 64 סיביות ו-SetEndOfFile. }
function TruncateFileTo(const Path: String; NewSize: Int64): Boolean;
var
  F: TFileStream;
begin
  Result := False;
  try
    F := TFileStream.Create(Path, fmOpenWrite);
    try
      F.Seek(NewSize, soFromBeginning);
      Result := SetEndOfFile(F.Handle);
    finally
      F.Free;
    end;
  except
    LoadErrorTech := 'truncate failed: ' + GetExceptionMessage;
  end;
end;

{ מרכיב נכס מפוצל לקובץ אחד. שיא צריכת הדיסק הוא הקובץ המורכב ועוד חלק
  אחד: כל חלק נמחק מיד אחרי שנוסף. }
function AssembleAsset(AssetIndex: Integer; const Caption: String): Boolean;
var
  TmpPath, FinalPath, PartPath: String;
  Consumed, I, First: Integer;
  Prefix, Actual: Int64;
begin
  Result := False;
  FinalPath := OutputDir() + '\' + AssetName[AssetIndex];
  TmpPath := FinalPath + '.tmp';
  First := AssetPartStart[AssetIndex];
  Consumed := ConsumedPartCount(AssetIndex, Prefix);
  if FileExists(TmpPath) and not TruncateFileTo(TmpPath, Prefix) then
    exit;

  WorkPage.SetProgress(Consumed, AssetPartCount[AssetIndex]);
  for I := Consumed to AssetPartCount[AssetIndex] - 1 do
  begin
    PartPath := CachePath(PartName[First + I]);
    WorkPage.SetText('מחבר את הקבצים: ' + Caption,
      'חלק ' + IntToStr(I + 1) + ' מתוך ' + IntToStr(AssetPartCount[AssetIndex]));
    if not CachedFileIsGood(PartName[First + I], PartSize[First + I],
      PartSha[First + I]) then
    begin
      LoadErrorHeb := 'לא ניתן להכין את ההתקנה משום שאחד הקבצים הדרושים ' +
        'אינו זמין.';
      LoadErrorTech := 'part failed verification: ' + PartName[First + I];
      exit;
    end;
    if not AppendFileTo(TmpPath, PartPath) then
    begin
      LoadErrorHeb := 'לא ניתן היה לכתוב את הקובץ המאוחד. ייתכן שאין מספיק ' +
        'מקום פנוי.';
      exit;
    end;
    DeleteFile(PartPath);
    WorkPage.SetProgress(I + 1, AssetPartCount[AssetIndex]);
  end;

  WorkPage.SetText('בודק את הקובץ המאוחד: ' + Caption, '');
  if not FileSize64(TmpPath, Actual) or (Actual <> AssetSize[AssetIndex]) or
     (Lowercase(GetSHA256OfFile(TmpPath)) <> Lowercase(AssetSha[AssetIndex])) then
  begin
    LoadErrorHeb := 'הקובץ המאוחד נמצא פגום ולכן לא נשמר.';
    LoadErrorTech := 'assembled file failed verification: ' +
      AssetName[AssetIndex];
    DeleteFile(TmpPath);
    exit;
  end;
  DeleteFile(FinalPath);
  Result := RenameFile(TmpPath, FinalPath);
  if not Result then
    LoadErrorTech := 'rename failed: ' + TmpPath;
end;

function CopyToOutput(const Name: String): Boolean;
begin
  Result := True;
  if CompareText(OutputDir(), CacheDir()) = 0 then
    exit;
  Result := FileCopy(CachePath(Name), OutputDir() + '\' + Name, False);
  if not Result then
    LoadErrorTech := 'copy failed: ' + Name;
end;

{ ==================== הרכבה והכנת תיקיית היעד ==================== }

function PrepareOutput(): Boolean;
var
  C, A, P: Integer;
  Notes, PartsNote, SingleName: String;
  Produced: Integer;
begin
  Result := False;
  ForceDirectories(OutputDir());
  Notes := '';
  SingleName := '';
  Produced := 0;
  RunAfterExe := '';
  RevealPath := '';

  WorkPage.Show;
  try
    for C := 0 to GetArrayLength(CompId) - 1 do
    begin
      if not CompSelected[C] then
        Continue;
      for A := CompAssetStart[C] to CompAssetStart[C] + CompAssetCount[C] - 1 do
      begin
        if AssetKind[A] = 'split' then
        begin
          if ShouldAssembleSingleFile(A) then
          begin
            if not AssembledIsReady(A) then
              if not AssembleAsset(A, CompName[C]) then
                exit;
            Notes := Notes + '• ' + AssetName[A] + #13#10;
            SingleName := AssetName[A];
            Produced := Produced + 1;
          end
          else
          begin
            { קובץ מאוחד שאי אפשר להריץ, או ארכיון שהמתקין צורך כחלקים —
              החלקים נשארים כפי שהם ליד המתקין. }
            PartsNote := '';
            for P := AssetPartStart[A] to AssetPartStart[A] + AssetPartCount[A] - 1 do
            begin
              WorkPage.SetText('מעתיק את הקבצים: ' + CompName[C], PartName[P]);
              if not CopyToOutput(PartName[P]) then
              begin
                LoadErrorHeb := 'לא ניתן היה להעתיק את הקבצים לתיקייה שנבחרה.';
                exit;
              end;
              PartsNote := PartsNote + '• ' + PartName[P] + #13#10;
              SingleName := PartName[P];
              Produced := Produced + 1;
            end;
            Notes := Notes + PartsNote;
          end;
        end
        else
        begin
          WorkPage.SetText('מעתיק את הקבצים: ' + CompName[C], AssetName[A]);
          if not CopyToOutput(AssetName[A]) then
          begin
            LoadErrorHeb := 'לא ניתן היה להעתיק את הקבצים לתיקייה שנבחרה.';
            exit;
          end;
          Notes := Notes + '• ' + AssetName[A] + #13#10;
          SingleName := AssetName[A];
          Produced := Produced + 1;
        end;
        if IsExecutableName(AssetName[A]) and (RunAfterExe = '') then
          RunAfterExe := OutputDir() + '\' + AssetName[A];
      end;
    end;
  finally
    WorkPage.Hide;
  end;

  { הניסוח נגזר ממה שנוצר בפועל, ולא מהרכיב שנבחר. }
  if ModePage.SelectedValueIndex = ModeThisComputer then
    ResultText := 'הקבצים ירדו ואומתו.' + #13#10#13#10 +
      'כעת ייפתח מתקין אוצריא. המשך בו כרגיל.'
  else if Produced = 1 then
  begin
    RevealPath := OutputDir() + '\' + SingleName;
    RevealIsFile := True;
    ResultText := 'הקובץ מוכן:' + #13#10 + SingleName + #13#10#13#10 +
      'הוא נמצא בתיקייה:' + #13#10 + OutputDir() + #13#10#13#10 +
      'העתק את הקובץ הזה לדיסק-און-קי ומשם למחשב המנותק.';
    if IsExecutableName(SingleName) then
      ResultText := ResultText + ' שם הפעל אותו — אין צורך בחיבור לאינטרנט ' +
        'ואין צורך בתוכנות נוספות.';
  end
  else
  begin
    RevealPath := OutputDir();
    RevealIsFile := False;
    ResultText := 'ההתקנה מוכנה בתיקייה:' + #13#10 + OutputDir() + #13#10#13#10 +
      'העתק את כל התיקייה הזאת לדיסק-און-קי, ובמחשב המנותק הפעל מתוכה את ' +
      'קובץ ההתקנה. הקבצים חייבים להישאר יחד באותה תיקייה. אין צורך בחיבור ' +
      'לאינטרנט ואין צורך בתוכנות נוספות.'
      + #13#10#13#10 + 'הקבצים שהוכנו:' + #13#10 + Notes;
  end;
  Result := True;
end;

{ ============================== זרימה ============================== }

procedure ShowFailure();
begin
  if LoadErrorTech <> '' then
    Log('DownloadAssistant: ' + LoadErrorTech);
  if MsgBox(LoadErrorHeb + #13#10#13#10 + 'להציג פרטים טכניים?',
    mbError, MB_YESNO) = IDYES then
    MsgBox(LoadErrorTech, mbInformation, MB_OK);
end;

function InitializeSetup(): Boolean;
var
  ErrorCode: Integer;
begin
  Result := True;
  ManifestLoaded := LoadReleaseManifest();
  if ManifestLoaded then
    exit;
  Log('DownloadAssistant: ' + LoadErrorTech);
  { אין נתונים מאומתים, ולכן לא מורידים כלום. האפשרות היחידה שמוצעת היא
    לפתוח את עמוד ההורדות ולהוריד ידנית. }
  if MsgBox(LoadErrorHeb + #13#10#13#10 +
    'אפשר לפתוח את עמוד ההורדות של אוצריא בדפדפן ולהוריד משם ידנית ' +
    '(אפשרות מוגבלת: המסייע לא יוכל לבדוק את הקבצים או לחבר אותם).'
    + #13#10#13#10 + 'לפתוח את עמוד ההורדות?', mbError, MB_YESNO) = IDYES then
    ShellExecAsOriginalUser('open',
      'https://github.com/palmoni5/otzaria/releases/latest', '', '',
      SW_SHOWNORMAL, ewNoWait, ErrorCode);
  Result := False;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = PresetPage.ID then
    RefreshPresetPage
  else if CurPageID = CustomPage.ID then
    RefreshCustomPage
  else if CurPageID = wpFinished then
  begin
    { ברירת המחדל של התווית נמוכה מדי — טקסט הסיום ארוך ממשפט אחד. }
    WizardForm.FinishedLabel.AutoSize := False;
    WizardForm.FinishedLabel.WordWrap := True;
    WizardForm.FinishedLabel.Height := WizardForm.FinishedPage.ClientHeight -
      WizardForm.FinishedLabel.Top;
    WizardForm.FinishedLabel.Caption := ResultText;
    if RevealPath <> '' then
    begin
      if not Assigned(RevealCheck) then
      begin
        RevealCheck := TNewCheckBox.Create(WizardForm);
        RevealCheck.Parent := WizardForm.FinishedPage;
        RevealCheck.Left := WizardForm.FinishedLabel.Left;
        RevealCheck.Width := WizardForm.FinishedLabel.Width;
        RevealCheck.Height := ScaleY(17);
        RevealCheck.Checked := True;
      end;
      RevealCheck.Top := WizardForm.FinishedPage.ClientHeight -
        RevealCheck.Height;
      WizardForm.FinishedLabel.Height := RevealCheck.Top - ScaleY(8) -
        WizardForm.FinishedLabel.Top;
      if RevealIsFile then
        RevealCheck.Caption := 'הצג את הקובץ שהוכן'
      else
        RevealCheck.Caption := 'הצג את התיקייה שהוכנה';
    end;
  end;
end;

{ פתיחת הסיירת היא נוחות בלבד: אם היא נכשלת, התוצאה כבר מוכנה ואין מה לומר. }
procedure DeinitializeSetup();
var
  ErrorCode: Integer;
begin
  if (RevealPath = '') or not Assigned(RevealCheck) or
     not RevealCheck.Checked then
    exit;
  if not ExecAsOriginalUser(ExpandConstant('{win}\explorer.exe'),
    '/select,"' + RevealPath + '"', '', SW_SHOWNORMAL, ewNoWait, ErrorCode) then
    Log('DownloadAssistant: explorer /select failed: ' + IntToStr(ErrorCode));
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  I: Integer;
  Selected: Boolean;
  Free, Total, Needed: Int64;
begin
  Result := True;

  if CurPageID = PresetPage.ID then
  begin
    if PresetPage.SelectedValueIndex <> CustomPresetIndex then
      ApplyPreset(PresetPage.SelectedValueIndex);
    exit;
  end;

  if CurPageID = CustomPage.ID then
  begin
    Selected := False;
    for I := 0 to GetArrayLength(CustomIndex) - 1 do
    begin
      CompSelected[CustomIndex[I]] := CustomPage.Values[I];
      if CustomPage.Values[I] then
        Selected := True;
    end;
    if not Selected then
    begin
      MsgBox('יש לבחור לפחות רכיב אחד להורדה.', mbError, MB_OK);
      Result := False;
    end;
    exit;
  end;

  if CurPageID = FolderPage.ID then
  begin
    if DirIsWritable(FolderPage.Values[0]) then
      exit;
    if DirIsWritable(FallbackOutputBase()) then
    begin
      MsgBox('לא ניתן לשמור בתיקייה שנבחרה. במקומה מוצעת התיקייה:' + #13#10 +
        FallbackOutputBase() + #13#10#13#10 +
        'אפשר להמשיך איתה או לבחור תיקייה אחרת.', mbInformation, MB_OK);
      FolderPage.Values[0] := FallbackOutputBase();
    end
    else
      MsgBox('לא ניתן לשמור בתיקייה שנבחרה. נסה תיקייה אחרת.', mbError, MB_OK);
    Result := False;
    exit;
  end;

  if CurPageID <> wpReady then
    exit;

  Needed := 0;
  for I := 0 to GetArrayLength(CompId) - 1 do
    if CompSelected[I] then
      Needed := Needed + CompDownloadSize[I] * 2;
  if GetSpaceOnDisk64(OutputBaseDir(), Free, Total) and (Free < Needed) then
    if MsgBox('נראה שאין מספיק מקום פנוי. דרושים בערך ' + HumanSize(Needed) +
      '.' + #13#10#13#10 + 'להמשיך בכל זאת?', mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
      exit;
    end;

  LoadErrorHeb := '';
  LoadErrorTech := '';
  if not BuildQueue() or not RunDownloads() or not PrepareOutput() then
  begin
    if LoadErrorHeb = '' then
      LoadErrorHeb := 'לא ניתן להכין את ההתקנה.';
    ShowFailure();
    Result := False;
    exit;
  end;

  if (ModePage.SelectedValueIndex = ModeThisComputer) and (RunAfterExe <> '') then
    if not ShellExec('', RunAfterExe, '', ExtractFileDir(RunAfterExe),
      SW_SHOWNORMAL, ewNoWait, I) then
      ResultText := ResultText + #13#10#13#10 +
        'לא ניתן היה להפעיל את המתקין. אפשר להפעיל אותו ידנית מתוך:'
        + #13#10 + OutputDir();
end;
