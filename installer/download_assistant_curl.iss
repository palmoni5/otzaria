{ הורדה דרך curl.exe של Windows: קבצים חלקיים קבועים במטמון שממשיכים מהם, וקובץ גדול
  בכמה טווחים במקביל. כישלון שאינו ניתוק חולף חוזר לעמוד ההורדה של Inno. }

type
  { JOBOBJECT_EXTENDED_LIMIT_INFORMATION: ‏112 בתים ב-32 ביט, LimitFlags בבית 16. }
  TCurlJobLimits = record
    Head: array[0..3] of LongWord;
    LimitFlags: LongWord;
    Rest: array[0..30] of LongWord;
  end;

{ כמו UiCreateProcess, אבל עם תיקיית עבודה: הנתיבים בפקודה יחסיים אליה. }
function CurlCreateProcess(App, CommandLine: String; ProcessAttr, ThreadAttr: Longint;
  Inherit: BOOL; Flags: LongWord; Env: Longint; Dir: String;
  var Startup: TUiStartupInfo; var Info: TUiProcessInfo): BOOL;
  external 'CreateProcessW@kernel32.dll stdcall';
function CurlWaitForSingleObject(hHandle: THandle; dwMilliseconds: LongWord): LongWord;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function CurlGetExitCodeProcess(hProcess: THandle; var lpExitCode: LongWord): BOOL;
  external 'GetExitCodeProcess@kernel32.dll stdcall';
function CurlTerminateProcess(hProcess: THandle; uExitCode: LongWord): BOOL;
  external 'TerminateProcess@kernel32.dll stdcall';
function CurlResumeThread(hThread: THandle): LongWord;
  external 'ResumeThread@kernel32.dll stdcall';
function CurlCreateJobObject(lpJobAttributes, lpName: Longint): THandle;
  external 'CreateJobObjectW@kernel32.dll stdcall';
function CurlSetInformationJobObject(hJob: THandle; JobObjectInfoClass: Integer;
  var lpJobObjectInfo: TCurlJobLimits; cbJobObjectInfoLength: LongWord): BOOL;
  external 'SetInformationJobObject@kernel32.dll stdcall';
function CurlAssignProcessToJobObject(hJob, hProcess: THandle): BOOL;
  external 'AssignProcessToJobObject@kernel32.dll stdcall';
function CurlCreateFile(lpFileName: String; dwDesiredAccess, dwShareMode: LongWord;
  lpSecurityAttributes: Longint; dwCreationDisposition, dwFlagsAndAttributes: LongWord;
  hTemplateFile: Longint): Longint;
  external 'CreateFileW@kernel32.dll stdcall';

const
  CurlDone = 0;
  CurlFailed = 1;
  CurlFallback = 2;
  { פנימי: השרת ענה 200 על בקשת טווח — ממשיכים בחיבור אחד. }
  CurlSingle = 3;
  CurlStoppedByUser = 4;
  { כל קובץ גדול יורד בחיבורים מקבילים, כל אחד על טווח בתים אחר שלו. }
  SegmentsPerFile = 4;
  { מתחת לזה חיבור אחד מספיק, והבדיקה המקדימה וההרכבה אינן משתלמות. }
  SegmentMinSize = 67108864;
  { ניסיונות רצופים של קטע שלא הוסיפו אף בית. ניסיון שהתקדם מאפס את המונה. }
  CurlStallLimit = 5;
  { CURLE_RANGE_ERROR: השרת ענה 200 על בקשת ‎--continue-at‎. }
  CurlRangeIgnored = 33;
  CurlKilledByUs = 1001;
  SegPending = 0;
  SegRunning = 1;
  SegDone = 2;

var
  CurlExe: String;
  { 0 — טרם נבדק, 1 — זמין, ‎-1‎ — כבוי עד הריצה הבאה (חוזרים ל-Inno). }
  CurlState: Integer;
  { curl קיבל תשובה סופית בריצה הזאת: מכאן כישלון חיבור הוא ניתוק, לא פרוקסי חסר. }
  CurlProven: Boolean;
  CurlJob: THandle;
  CurlLockHandle: Longint;
  { curl הוסיף בתים לפריט הנוכחי בריצה הזאת. }
  CurlGained: Boolean;
  { הקטעים של הקובץ הנוכחי. איבר 0 הוא תמיד הקובץ החלקי השלם עצמו. }
  SegState, SegStrikes, SegTries: array of Integer;
  SegStart, SegEnd, SegBefore, SegBest, SegWakeAt, SegStartedAt: TInt64Array;
  SegFile: TArrayOfString;
  SegProc: array of THandle;
  SegMore: array of Boolean;
  { בתים שירדו ברשת במשימה, מצטבר; SegNet — מה שכבר נספר מהניסיון הנוכחי של כל קטע. }
  CurlNetBytes: Int64;
  SegNet: TInt64Array;
  { חיבור הקטעים שעוד צפוי לפריט, כחלק מ-JoinCopyLeft שבהערכת הזמן. }
  CurlJoinPending: Int64;
  { אחרי המתנה בין ניסיונות: זמן הנתונים האחרונים, כדי שהמתנה ארוכה תוצג כתקיעה. }
  CurlActivityKeep: Int64;

{ "נסה שוב" מתחיל ריצה חדשה: כיבוי בגלל ניתוק אחד אינו נשאר לכל הסשן. }
procedure CurlResetRun();
begin
  if CurlState < 0 then
    CurlState := 0;
  CurlProven := False;
  CurlNetBytes := 0;
  CurlJoinPending := 0;
end;

{ קשור ל-sha256 שבמניפסט: שם הנכס חוזר בין גרסאות, ושארית של גרסה אחרת אינה המשך. }
function CurlBase(I: Integer): String;
begin
  Result := CachePath(QueueFile[I]) + '.' + Copy(Lowercase(QueueSha[I]), 1, 12);
end;

function CurlWholePath(I: Integer): String;
begin
  Result := CurlBase(I) + '.partial';
end;

{ מספר הקטעים בשם: חלוקה אחרת של אותו קובץ אינה המשך של הקבצים האלה. }
function CurlSegPath(I, K: Integer): String;
begin
  if K = 0 then
    Result := CurlWholePath(I)
  else
    Result := CurlBase(I) + '.seg' + IntToStr(K) + 'of' + IntToStr(SegmentsPerFile) +
      '.partial';
end;

{ תחילת קטע K ברשת הקבועה של SegmentsPerFile קטעים; K = SegmentsPerFile — סוף הקובץ. }
function CurlGridStart(I, K: Integer): Int64;
begin
  if K >= SegmentsPerFile then
    Result := QueueSize[I]
  else
    Result := (QueueSize[I] div SegmentsPerFile) * K;
end;

function CurlSize(const Path: String): Int64;
begin
  if not FileSize64(Path, Result) then
    Result := 0;
end;

function CurlTruncate(const Path: String; NewSize: Int64): Boolean;
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
    Log('DownloadAssistant: truncate failed: ' + GetExceptionMessage);
  end;
end;

{ כל ניקוי מחייב נעילה של שם הנכס, גם כשה-SHA של הקבצים שונה. }
procedure CurlDropPartials(const Name, KeepPrefix: String);
var
  Rec: TFindRec;
begin
  if not FindFirst(CachePath(Name) + '.*.partial*', Rec) then
    exit;
  try
    repeat
      if not EndsWithText(Rec.Name, '.lock') and ((KeepPrefix = '') or
        (CompareText(Copy(Rec.Name, 1, Length(KeepPrefix)), KeepPrefix) <> 0)) then
      begin
        Log('DownloadAssistant: discarding ' + Rec.Name);
        DeleteFile(CacheDir() + '\' + Rec.Name);
      end;
    until not FindNext(Rec);
  finally
    FindClose(Rec);
  end;
end;

{ Sysnative — ה-curl של 64 ביט מתוך Setup של 32 ביט; אחרת זה של SysWOW64. }
function CurlReady(): Boolean;
var
  Code: Integer;
  Output: TExecOutput;
begin
  if CurlState = 0 then
  begin
    CurlState := -1;
    CurlExe := ExpandConstant('{win}\Sysnative\curl.exe');
    if not FileExists(CurlExe) then
      CurlExe := ExpandConstant('{sys}\curl.exe');
    if not FileExists(CurlExe) then
      Log('DownloadAssistant: curl.exe not found, using the Inno downloader')
    else if ExecAndCaptureOutput(CurlExe, '--version', '', SW_HIDE,
      ewWaitUntilTerminated, Code, Output) and (Code = 0) and
      (GetArrayLength(Output.StdOut) > 0) then
    begin
      CurlState := 1;
      Log('DownloadAssistant: using ' + CurlExe + ': ' + Output.StdOut[0]);
    end
    else
      Log('DownloadAssistant: ' + CurlExe + ' --version failed (' +
        IntToStr(Code) + '), using the Inno downloader');
  end;
  Result := CurlState = 1;
end;

{ בלי ‎--retry‎: ניסיון חוזר של curl מקצץ את מה שירד בו. ‎--suppress-connect-headers‎:
  תשובת ה-CONNECT של פרוקסי אינה נקראת כתשובת השרת. }
function CurlArgs(const Url, Extra, Output: String): String;
begin
  Result := '"' + CurlExe + '" --fail --location --silent --show-error' +
    ' --connect-timeout 30 --speed-limit 1024 --speed-time 60' +
    ' --ssl-revoke-best-effort --suppress-connect-headers ' + Extra + ' --stderr "' +
    ExtractFileName(Output) + '.log" --output "' + ExtractFileName(Output) + '" "' +
    Url + '"';
end;

{ כל תהליך curl נכנס ל-Job שנסגר עם המסייע, כך שגם קריסה אינה משאירה אותו רץ. }
procedure CurlJoinJob(Process: THandle);
var
  Limits: TCurlJobLimits;
  K: Integer;
begin
  if CurlJob = 0 then
  begin
    CurlJob := CurlCreateJobObject(0, 0);
    for K := 0 to 3 do
      Limits.Head[K] := 0;
    for K := 0 to 30 do
      Limits.Rest[K] := 0;
    { JobObjectExtendedLimitInformation, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE }
    Limits.LimitFlags := $2000;
    if CurlJob <> 0 then
      if not CurlSetInformationJobObject(CurlJob, 9, Limits, 112) then
        Log('DownloadAssistant: curl job limits failed: ' + SysErrorMessage(DLLGetLastError));
  end;
  if CurlJob <> 0 then
    if CurlAssignProcessToJobObject(CurlJob, Process) then
      exit;
  Log('DownloadAssistant: curl not in a job: ' + SysErrorMessage(DLLGetLastError));
end;

{ 0 — curl לא עלה. CREATE_SUSPENDED + CREATE_NO_WINDOW: נכנס ל-Job לפני שהוא רץ. }
function CurlSpawn(const Args: String): THandle;
var
  Startup: TUiStartupInfo;
  Info: TUiProcessInfo;
begin
  Result := 0;
  Startup.Size := SizeOf(Startup);
  if not CurlCreateProcess(CurlExe, Args, 0, 0, False, $08000004, 0, CacheDir(),
    Startup, Info) then
  begin
    Log('DownloadAssistant: cannot start curl: ' + SysErrorMessage(DLLGetLastError));
    exit;
  end;
  CurlJoinJob(Info.Process);
  CurlResumeThread(Info.Thread);
  UiCloseHandle(Info.Thread);
  Result := Info.Process;
end;

function CurlExitCode(var Proc: THandle): LongWord;
begin
  if not CurlGetExitCodeProcess(Proc, Result) then
    Result := CurlKilledByUs;
  UiCloseHandle(Proc);
  Proc := 0;
end;

procedure CurlKill(var Proc: THandle);
begin
  if Proc = 0 then
    exit;
  CurlTerminateProcess(Proc, CurlKilledByUs);
  CurlWaitForSingleObject(Proc, 5000);
  UiCloseHandle(Proc);
  Proc := 0;
end;

{ שורת השגיאה של curl (‎--stderr‎), והקובץ נמחק. }
function CurlTakeError(const Output: String): String;
var
  Raw: AnsiString;
begin
  Result := '';
  if LoadStringFromFile(Output + '.log', Raw) then
    Result := Trim(String(Raw));
  DeleteFile(Output + '.log');
end;

{ קוד ה-HTTP מתוך "The requested URL returned error: 503" של ‎--fail‎, או 0. }
function CurlHttpStatus(const ErrText: String): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := Pos('error: ', ErrText);
  if P > 0 then
    Result := StrToIntDef(Copy(ErrText, P + 7, 3), 0);
end;

{ ניתוק ולא תקלה: שם שלא נפתר, חיבור שנכשל או נתקע, גוף שנקטע, 5xx/408/429. }
function CurlIsTransient(Code: LongWord; const ErrText: String): Boolean;
var
  Status: Integer;
begin
  case Code of
    6, 7, 16, 18, 28, 35, 52, 55, 56, 92: Result := True;
    22:
      begin
        Status := CurlHttpStatus(ErrText);
        Result := (Status >= 500) or (Status = 408) or (Status = 429);
      end;
  else
    Result := False;
  end;
end;

{ הסטטוס וה-Content-Range של התשובה האחרונה (אחרי הפניות) ב-‎--dump-header‎.
  Complete — הגיעה תשובה סופית שאינה הפניה. }
procedure CurlReadHeaders(const Path: String; var Status: Integer;
  var ContentRange: String; var Complete: Boolean);
var
  Raw: AnsiString;
  Lines: TArrayOfString;
  Line: String;
  I: Integer;
begin
  Status := 0;
  ContentRange := '';
  Complete := False;
  if not LoadStringFromFile(Path, Raw) then
    exit;
  Lines := StringSplit(String(Raw), [#10], stAll);
  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    Line := Trim(Lines[I]);
    if Copy(Line, 1, 5) = 'HTTP/' then
    begin
      Status := StrToIntDef(Copy(Line, Pos(' ', Line) + 1, 3), 0);
      ContentRange := '';
      Complete := False;
    end
    else if CompareText(Copy(Line, 1, 14), 'content-range:') = 0 then
      ContentRange := Trim(Copy(Line, 15, Length(Line)))
    else if (Line = '') and (Status > 0) and (I < GetArrayLength(Lines) - 1) then
      Complete := (Status < 300) or (Status >= 400);
  end;
end;

{ המתנה שהחלון וכפתור העצירה ממשיכים לפעול בה. }
procedure CurlPause(Ms: Integer);
var
  Deadline: Int64;
begin
  Deadline := NowMs() + Ms;
  while (NowMs() < Deadline) and not StopRequested do
  begin
    Sleep(50);
    DownloadPage.SetProgress(DownloadPage.ProgressBar.Position,
      DownloadPage.ProgressBar.Max);
  end;
end;

function CurlStopped(I: Integer): Integer;
begin
  Log('DownloadAssistant: curl download of ' + QueueFile[I] + ' stopped by the user');
  LoadErrorMsg := CustomMessage('ErrorStopped');
  Result := CurlStoppedByUser;
end;

{ ============================ בדיקת Range ============================ }

{ בקשה לבית אחד. 1 — 206 עם Content-Range של הגודל הצפוי; 0 — השרת אינו מכבד Range,
  ופיצול היה מוריד את הקובץ כולו בכל קטע; ‎-1‎ — אין תשובה. ‎--max-filesize‎ עוצר 200. }
function CurlProbeRange(I: Integer): Integer;
var
  Probe, ContentRange, ErrText: String;
  Proc: THandle;
  Status: Integer;
  Code: LongWord;
  Complete: Boolean;
begin
  Result := -1;
  Probe := CurlBase(I) + '.probe.partial';
  DeleteFile(Probe);
  DeleteFile(Probe + '.hdr');
  Proc := CurlSpawn(CurlArgs(QueueUrl[I], '--range 0-0 --max-filesize 1024 --max-time 60' +
    ' --dump-header "' + ExtractFileName(Probe) + '.hdr"', Probe));
  if Proc = 0 then
    exit;
  while CurlWaitForSingleObject(Proc, 50) <> 0 do
  begin
    if StopRequested or DownloadPage.AbortedByUser then
    begin
      StopRequested := True;
      CurlKill(Proc);
      exit;
    end;
    DownloadPage.SetProgress(DownloadPage.ProgressBar.Position,
      DownloadPage.ProgressBar.Max);
  end;
  Code := CurlExitCode(Proc);
  ErrText := CurlTakeError(Probe);
  CurlReadHeaders(Probe + '.hdr', Status, ContentRange, Complete);
  DeleteFile(Probe);
  DeleteFile(Probe + '.hdr');
  Log('DownloadAssistant: range probe ' + QueueFile[I] + ': exit ' + IntToStr(Code) +
    ', HTTP ' + IntToStr(Status) + ', Content-Range "' + ContentRange + '" ' + ErrText);
  { הפניה בלבד אינה הוכחה: היעד שלה עשוי להיות נגיש רק דרך הפרוקסי של המערכת. }
  if Complete then
    CurlProven := True;
  if Complete and (Status = 206) and
     (ContentRange = 'bytes 0-0/' + IntToStr(QueueSize[I])) then
    Result := 1
  else if Complete and ((Status = 200) or (Status = 206)) then
    Result := 0;
end;

{ ============================ הקטעים ============================ }

function CurlSegLen(K: Integer): Int64;
begin
  Result := SegEnd[K] - SegStart[K] + 1;
end;

{ הבתים שכבר יש לקטע, כולל ‎.more‎ של הניסיון הנוכחי, עד אורך הקטע. }
function CurlSegHave(K: Integer): Int64;
begin
  Result := CurlSize(SegFile[K]);
  if SegMore[K] then
    Result := Result + CurlSize(SegFile[K] + '.more');
  if Result > CurlSegLen(K) then
    Result := CurlSegLen(K);
end;

{ מוסיף את Src לסוף Dest ומוחק אותו: CurlDone, CurlFailed, או CurlStoppedByUser
  (רק עם AllowStop) — אז Dest מקוצץ חזרה ו-Src נשאר שלם. }
function CurlAppend(const Dest, Src: String; AllowStop: Boolean): Integer;
var
  Output, Input: TFileStream;
  Start, Want, Copied, Slice, Got, SliceStart: Int64;
begin
  Result := CurlFailed;
  Want := CurlSize(Src);
  try
    Output := TFileStream.Create(Dest, fmOpenWrite);
    try
      Start := Output.Seek(Int64(0), soFromEnd);
      Input := TFileStream.Create(Src, fmOpenRead or fmShareDenyWrite);
      try
        Copied := 0;
        while Copied < Want do
        begin
          if AllowStop and StopRequested then
          begin
            Output.Seek(Start, soFromBeginning);
            SetEndOfFile(Output.Handle);
            Result := CurlStoppedByUser;
            exit;
          end;
          Slice := Want - Copied;
          if Slice > AppendSliceSize then
            Slice := AppendSliceSize;
          SliceStart := NowMs();
          Got := Output.CopyFrom(Input, Slice, CopyChunkSize);
          CopyMsMeasured := CopyMsMeasured + NowMs() - SliceStart;
          CopyBytesMeasured := CopyBytesMeasured + Got;
          if Got <> Slice then
            Break;
          Copied := Copied + Slice;
          DownloadPage.SetProgress(DownloadPage.ProgressBar.Position,
            DownloadPage.ProgressBar.Max);
        end;
      finally
        Input.Free;
      end;
      if Copied = Want then
        Result := CurlDone;
    finally
      Output.Free;
    end;
  except
    Log('DownloadAssistant: append failed: ' + GetExceptionMessage);
  end;
  if Result = CurlDone then
    DeleteFile(Src)
  else if Result = CurlFailed then
    Log('DownloadAssistant: append of ' + ExtractFileName(Src) + ' failed');
end;

function CurlItemHave(): Int64;
var
  K: Integer;
begin
  Result := 0;
  for K := 0 to GetArrayLength(SegFile) - 1 do
    Result := Result + CurlSegHave(K);
end;

function CurlMaxStrikes(): Integer;
var
  K: Integer;
begin
  Result := 0;
  for K := 0 to GetArrayLength(SegStrikes) - 1 do
    if SegStrikes[K] > Result then
      Result := SegStrikes[K];
end;

procedure CurlSetJoinPending(Bytes: Int64);
begin
  if Bytes < 0 then
    Bytes := 0;
  JoinCopyLeft := JoinCopyLeft - CurlJoinPending + Bytes;
  CurlJoinPending := Bytes;
end;

{ מוסיף ל-CurlNetBytes את מה שקטע K הוריד מאז הספירה הקודמת. בתים שנמחקו
  (33/416, .more שנזרק) אינם מורדים: המהירות סופרת רק בתים מהרשת. }
procedure CurlCountNet(K: Integer);
var
  Got: Int64;
begin
  Got := CurlSegHave(K) - SegBefore[K];
  if Got > SegNet[K] then
    CurlNetBytes := CurlNetBytes + Got - SegNet[K];
  SegNet[K] := Got;
end;

{ הפס והזמן הנותר לפי הבתים שעל הדיסק; המהירות — לפי הבתים מהרשת בלבד. }
procedure CurlShowProgress(I: Integer);
var
  K: Integer;
  Done, Before: Int64;
begin
  Before := CurlNetBytes;
  for K := 0 to GetArrayLength(SegFile) - 1 do
    if SegState[K] = SegRunning then
      CurlCountNet(K);
  if CurlNetBytes > Before then
  begin
    CurlProven := True;
    CurlGained := True;
    CurlActivityKeep := -1;
    AddSpeedSample(CurlNetBytes);
  end
  else if EstRebase and not EstPaused then
  begin
    { בסיס כבר בבדיקה הראשונה: בלעדיו חיבור שאינו מביא בתים לא היה מוצג כתקיעה. }
    AddSpeedSample(CurlNetBytes);
    EstNewData := False;
    if CurlActivityKeep >= 0 then
      EstActivityMs := CurlActivityKeep;
    CurlActivityKeep := -1;
  end;
  Done := CurlItemHave();
  CurrentProgress := Done;
  { הפס המקורי מוסתר, אבל ממנו נקבעת ההתקדמות בשורת המשימות: לכן הוא על כל התור. }
  DownloadPage.SetProgress((ProgressDone + Done) div 1024, ProgressTotal div 1024);
  if Done < QueueSize[I] then
    ShowDownloadStatus();
end;

procedure CurlSetCaption(I: Integer; Retry: Boolean);
var
  Offset: Int64;
  Count: String;
begin
  Offset := CurlItemHave();
  Count := IntToStr(GetArrayLength(QueueUrl));
  if (Offset > 0) and not Retry then
    ProgressCaption := FmtMessage(CustomMessage('DownloadingItemResumed'), [
      QueueLabel[I], IntToStr(I + 1), Count, HumanSize(Offset)])
  else if Offset > 0 then
    ProgressCaption := FmtMessage(CustomMessage('DownloadingItemContinued'), [
      QueueLabel[I], HumanSize(Offset)])
  else if not Retry then
    ProgressCaption := FmtMessage(CustomMessage('DownloadingItem'), [
      QueueLabel[I], IntToStr(I + 1), Count])
  else
    ProgressCaption := FmtMessage(CustomMessage('DownloadingItemAgain'), [
      QueueLabel[I], IntToStr(CurlMaxStrikes() + 1), IntToStr(CurlStallLimit)]);
  DownloadPage.SetText(ProgressCaption, DownloadStatus);
end;

{ ניסיון של קטע, מהבתים שכבר יש לו. בקטע יחיד ‎--continue-at -‎; בכמה קטעים curl
  אינו מצרף ‎--range‎ ל-‎--continue-at‎, ולכן ההמשך נכתב ל-‎.more‎ ומצורף אחר כך. }
function CurlStartSegment(I, K: Integer): Boolean;
var
  Have: Int64;
  Output, Extra: String;
begin
  Have := CurlSize(SegFile[K]);
  SegBefore[K] := Have;
  SegNet[K] := 0;
  SegMore[K] := (GetArrayLength(SegFile) > 1) and (Have > 0);
  if GetArrayLength(SegFile) = 1 then
  begin
    Output := SegFile[K];
    Extra := '--continue-at -';
  end
  else
  begin
    if SegMore[K] then
      Output := SegFile[K] + '.more'
    else
      Output := SegFile[K];
    DeleteFile(Output + '.hdr');
    { ‎--max-filesize‎ עוצר תשובת 200 (הקובץ כולו) לפני הגוף, לפי Content-Length. }
    Extra := '--range ' + IntToStr(SegStart[K] + Have) + '-' + IntToStr(SegEnd[K]) +
      ' --max-filesize ' + IntToStr(SegEnd[K] - SegStart[K] - Have + 1) +
      ' --dump-header "' + ExtractFileName(Output) + '.hdr"';
  end;
  if SegMore[K] then
    DeleteFile(Output);
  DeleteFile(Output + '.log');
  Log('DownloadAssistant: curl ' + ExtractFileName(SegFile[K]) + ' from byte ' +
    IntToStr(SegStart[K] + Have));
  SegStartedAt[K] := NowMs();
  SegProc[K] := CurlSpawn(CurlArgs(QueueUrl[I], Extra, Output));
  Result := SegProc[K] <> 0;
  if Result then
    SegState[K] := SegRunning;
end;

{ False רק כשהשרת ענה 2xx שאינו בדיוק הטווח שביקשנו (התעלם מ-Range). שגיאת HTTP
  אינה כזו — היא עוברת לכללים של קוד 22. Known — הגיעה תשובה סופית. }
function CurlSegReplyOk(I, K: Integer; var Known: Boolean): Boolean;
var
  Output, ContentRange: String;
  Status: Integer;
begin
  Result := True;
  Known := GetArrayLength(SegFile) = 1;
  if Known then
    exit;
  Output := SegFile[K];
  if SegMore[K] then
    Output := Output + '.more';
  CurlReadHeaders(Output + '.hdr', Status, ContentRange, Known);
  if not Known or (Status < 200) or (Status >= 300) then
    exit;
  Result := (Status = 206) and (ContentRange = 'bytes ' +
    IntToStr(SegStart[K] + SegBefore[K]) + '-' + IntToStr(SegEnd[K]) + '/' +
    IntToStr(QueueSize[I]));
  if not Result then
    Log('DownloadAssistant: ' + ExtractFileName(SegFile[K]) + ' got HTTP ' +
      IntToStr(Status) + ' "' + ContentRange + '" for a range request');
end;

{ אחרי שה-curl של קטע יצא או נהרג: גוף שאינו הטווח שביקשנו נזרק, והמשך תקין
  מצורף לקטע. False — הצירוף נכשל. }
function CurlSettle(I, K: Integer; var Known, ReplyOk: Boolean): Boolean;
var
  Output: String;
begin
  Result := True;
  Output := SegFile[K];
  if SegMore[K] then
    Output := Output + '.more';
  ReplyOk := CurlSegReplyOk(I, K, Known);
  if GetArrayLength(SegFile) > 1 then
  begin
    DeleteFile(Output + '.hdr');
    if not ReplyOk or (SegMore[K] and (not Known or (CurlSize(Output) = 0))) then
      DeleteFile(Output)
    else if SegMore[K] then
      Result := CurlAppend(SegFile[K], Output, False) = CurlDone;
  end;
  SegMore[K] := False;
end;

{ curl של קטע יצא. CurlDone — ממשיכים (הקטע הושלם או ינסה שוב); אחרת התוצאה
  של הפריט כולו. }
function CurlFinishSegment(I, K: Integer): Integer;
var
  Code: LongWord;
  ErrText, Output: String;
  Known, ReplyOk, Transient: Boolean;
  Size: Int64;
begin
  Result := CurlDone;
  Code := CurlExitCode(SegProc[K]);
  CurlCountNet(K);
  Output := SegFile[K];
  if SegMore[K] then
    Output := Output + '.more';
  ErrText := CurlTakeError(Output);
  if not CurlSettle(I, K, Known, ReplyOk) then
  begin
    LoadErrorMsg := CustomMessage('ErrorDownloadDamaged');
    LoadErrorTech := 'cannot append ' + ExtractFileName(Output);
    Result := CurlFailed;
    exit;
  end;
  Size := CurlSize(SegFile[K]);
  Log('DownloadAssistant: curl ' + ExtractFileName(SegFile[K]) + ' exit ' + IntToStr(Code) +
    ', ' + IntToStr(Size - SegBefore[K]) + ' new bytes in ' +
    IntToStr(NowMs() - SegStartedAt[K]) + ' ms ' + ErrText);
  SegState[K] := SegPending;
  if Known and not ReplyOk then
  begin
    Result := CurlSingle;
    exit;
  end;
  { קודים 22 ו-33 הם תשובה סופית של השרת, גם בלי בתים. }
  if Size > SegBefore[K] then
    CurlGained := True;
  if (Size > SegBefore[K]) or (Code = 22) or (Code = CurlRangeIgnored) then
    CurlProven := True;
  SegTries[K] := SegTries[K] + 1;
  { סף לפי השיא ולא לפי תחילת הניסיון: שרת שמתעלם מ-Range מתחיל כל פעם מאפס. }
  if Size > SegBest[K] then
  begin
    SegBest[K] := Size;
    SegStrikes[K] := 0;
  end
  else
    SegStrikes[K] := SegStrikes[K] + 1;
  SegWakeAt[K] := 0;

  if Size >= CurlSegLen(K) then
  begin
    if Size = CurlSegLen(K) then
      SegState[K] := SegDone
    else
    begin
      Log('DownloadAssistant: ' + ExtractFileName(SegFile[K]) + ' is too long, deleting');
      DeleteFile(SegFile[K]);
    end;
    exit;
  end;
  Transient := CurlIsTransient(Code, ErrText);
  if (Code = CurlRangeIgnored) or ((Code = 22) and (CurlHttpStatus(ErrText) = 416)) then
  begin
    Log('DownloadAssistant: server did not resume ' + QueueFile[I] + ', starting from 0');
    DeleteFile(SegFile[K]);
  end
  else if (Code <> 0) and (not Transient or (not CurlProven and (SegTries[K] > 1))) then
  begin
    Log('DownloadAssistant: curl failed on ' + QueueFile[I] +
      ', falling back to the Inno downloader');
    if not CurlProven then
      CurlState := -1;
    Result := CurlFallback;
    exit;
  end;
  if SegStrikes[K] >= CurlStallLimit then
  begin
    { curl לא הביא לפריט הזה אף בית בריצה הזאת — ייתכן שרק Inno מגיע אליו. }
    if not CurlGained then
    begin
      Log('DownloadAssistant: curl got nothing for ' + QueueFile[I] +
        ', falling back to the Inno downloader');
      Result := CurlFallback;
      exit;
    end;
    LoadErrorMsg := CustomMessage('ErrorDownloadIncomplete');
    LoadErrorTech := QueueFile[I] + ': curl exit ' + IntToStr(Code) + ' ' + ErrText;
    Result := CurlFailed;
    exit;
  end;
  if (Code <> 0) and (Code <> CurlRangeIgnored) then
  begin
    if SegStrikes[K] = 0 then
      SegWakeAt[K] := NowMs() + 1000
    else
      SegWakeAt[K] := NowMs() + 2000 * SegStrikes[K];
  end;
end;

{ עצירה: מה שכבר ירד בכל קטע נשמר לפי אותם כללים כמו ביציאה רגילה. }
procedure CurlKillSegments(I: Integer);
var
  K: Integer;
  Known, ReplyOk: Boolean;
begin
  for K := 0 to GetArrayLength(SegProc) - 1 do
    if SegState[K] = SegRunning then
    begin
      CurlKill(SegProc[K]);
      CurlCountNet(K);
      if SegMore[K] then
        CurlTakeError(SegFile[K] + '.more')
      else
        CurlTakeError(SegFile[K]);
      CurlSettle(I, K, Known, ReplyOk);
      SegState[K] := SegPending;
    end;
end;

{ מוריד את כל הקטעים במקביל עד שכולם שלמים. קטע שנקטע ממשיך לבד, והאחרים
  ממשיכים בינתיים. עצירה הורגת את כולם ומשאירה את הקבצים. }
function CurlRunSegments(I: Integer): Integer;
var
  K, N: Integer;
  Open, Retry, Running: Boolean;
  LastShown: Int64;
begin
  Result := CurlDone;
  N := GetArrayLength(SegFile);
  LastShown := 0;
  Retry := False;
  VerifyStartTick := 0;
  CurlActivityKeep := -1;
  CurlSetCaption(I, False);
  SpeedResume();
  try
    while True do
    begin
      if StopRequested or DownloadPage.AbortedByUser then
      begin
        StopRequested := True;
        Result := CurlStoppedByUser;
        exit;
      end;
      Open := False;
      for K := 0 to N - 1 do
      begin
        if (SegState[K] = SegRunning) and (CurlWaitForSingleObject(SegProc[K], 0) = 0) then
        begin
          Result := CurlFinishSegment(I, K);
          if Result <> CurlDone then
            exit;
          Retry := Retry or (SegState[K] <> SegDone);
        end;
        if (SegState[K] = SegPending) and (NowMs() >= SegWakeAt[K]) then
        begin
          if CurlSize(SegFile[K]) >= CurlSegLen(K) then
            SegState[K] := SegDone
          else
          begin
            if Retry then
              CurlSetCaption(I, True);
            if not CurlStartSegment(I, K) then
            begin
              CurlState := -1;
              Result := CurlFallback;
              exit;
            end;
          end;
        end;
        if SegState[K] <> SegDone then
          Open := True;
      end;
      if not Open then
        exit;
      { כל הקטעים ממתינים לניסיון הבא: אין רשת, והזמן הזה אינו נמדד כמהירות. }
      Running := False;
      for K := 0 to N - 1 do
        if SegState[K] = SegRunning then
          Running := True;
      if not Running and not EstPaused then
      begin
        if CurlActivityKeep < 0 then
          CurlActivityKeep := EstActivityMs;
        SpeedPause();
      end
      else if Running and EstPaused then
        SpeedResume();
      if NowMs() - LastShown >= 250 then
      begin
        CurlShowProgress(I);
        LastShown := NowMs();
      end;
      Sleep(50);
      DownloadPage.SetProgress(DownloadPage.ProgressBar.Position,
        DownloadPage.ProgressBar.Max);
    end;
  finally
    CurlKillSegments(I);
    SpeedPause();
  end;
end;

{ קטע K שלם על הדיסק (ברשת הקבועה). }
function CurlGridSegComplete(I, K: Integer): Boolean;
begin
  Result := (K < SegmentsPerFile) and FileExists(CurlSegPath(I, K)) and
    (CurlSize(CurlSegPath(I, K)) = CurlGridStart(I, K + 1) - CurlGridStart(I, K));
end;

function CurlGridSegExists(I: Integer): Boolean;
var
  K: Integer;
begin
  Result := False;
  for K := 1 to SegmentsPerFile - 1 do
    if FileExists(CurlSegPath(I, K)) then
      Result := True;
end;

{ קובץ השלם שנקטע באמצע צירוף של קטע שלם מקוצץ חזרה לגבול הקטע, כדי שהקטע ישמש
  ולא יירד שוב. אחר כך קטעים שלמים שמתחילים בדיוק בסוף הקובץ השלם מצורפים אליו. }
function CurlAbsorb(I: Integer): Boolean;
var
  K: Integer;
  Whole: Int64;
begin
  Result := True;
  Whole := CurlSize(CurlWholePath(I));
  for K := 1 to SegmentsPerFile - 1 do
    if (Whole > CurlGridStart(I, K)) and (Whole < CurlGridStart(I, K + 1)) and
       CurlGridSegComplete(I, K) then
    begin
      Log('DownloadAssistant: ' + QueueFile[I] + ' was cut while joining, back to byte ' +
        IntToStr(CurlGridStart(I, K)));
      Result := CurlTruncate(CurlWholePath(I), CurlGridStart(I, K));
      if not Result then
        exit;
      Whole := CurlGridStart(I, K);
    end;
  for K := 1 to SegmentsPerFile - 1 do
    if (Whole = CurlGridStart(I, K)) and CurlGridSegComplete(I, K) then
    begin
      Result := CurlAppend(CurlWholePath(I), CurlSegPath(I, K), False) = CurlDone;
      if not Result then
        exit;
      Whole := CurlGridStart(I, K + 1);
    end;
end;

{ N = 1 — טווח אחד; אחרת הרשת הקבועה של SegmentsPerFile קטעים, כשהקטעים שהקובץ
  השלם כבר מכסה מתמזגים לאיבר 0 (נקטע באמצע הרכבה, או ירד קודם בחיבור אחד). }
procedure CurlPlanSegments(I, N: Integer);
var
  K, J, M: Integer;
  Whole: Int64;
begin
  Whole := CurlSize(CurlWholePath(I));
  if Whole > QueueSize[I] then
  begin
    DeleteFile(CurlWholePath(I));
    Whole := 0;
  end;
  J := 0;
  if N > 1 then
    while (J < SegmentsPerFile - 1) and (Whole > CurlGridStart(I, J + 1)) do
      J := J + 1;
  if N = 1 then
    M := 1
  else
    M := SegmentsPerFile - J;
  for K := 1 to J do
  begin
    DeleteFile(CurlSegPath(I, K));
    DeleteFile(CurlSegPath(I, K) + '.more');
  end;
  SetArrayLength(SegState, M);
  SetArrayLength(SegStrikes, M);
  SetArrayLength(SegTries, M);
  SetArrayLength(SegStart, M);
  SetArrayLength(SegEnd, M);
  SetArrayLength(SegBefore, M);
  SetArrayLength(SegBest, M);
  SetArrayLength(SegWakeAt, M);
  SetArrayLength(SegStartedAt, M);
  SetArrayLength(SegFile, M);
  SetArrayLength(SegProc, M);
  SetArrayLength(SegMore, M);
  SetArrayLength(SegNet, M);
  for K := 0 to M - 1 do
  begin
    if K = 0 then
    begin
      SegStart[K] := 0;
      SegFile[K] := CurlWholePath(I);
      if N = 1 then
        SegEnd[K] := QueueSize[I] - 1
      else
        SegEnd[K] := CurlGridStart(I, J + 1) - 1;
    end
    else
    begin
      SegStart[K] := CurlGridStart(I, J + K);
      SegEnd[K] := CurlGridStart(I, J + K + 1) - 1;
      SegFile[K] := CurlSegPath(I, J + K);
    end;
    SegState[K] := SegPending;
    SegStrikes[K] := 0;
    SegTries[K] := 0;
    SegProc[K] := 0;
    SegMore[K] := False;
    SegWakeAt[K] := 0;
    DeleteFile(SegFile[K] + '.more');
    if CurlSize(SegFile[K]) > CurlSegLen(K) then
      DeleteFile(SegFile[K]);
    SegBest[K] := CurlSize(SegFile[K]);
    SegBefore[K] := SegBest[K];
    SegNet[K] := 0;
  end;
  CurlSetJoinPending(QueueSize[I] - CurlSegLen(0));
  if M > 1 then
    Log('DownloadAssistant: ' + QueueFile[I] + ' in ' + IntToStr(M) + ' segments, ' +
      IntToStr(CurlItemHave()) + ' bytes already here');
end;

procedure CurlDropSegments(I: Integer);
var
  K: Integer;
begin
  for K := 1 to SegmentsPerFile - 1 do
  begin
    DeleteFile(CurlSegPath(I, K));
    DeleteFile(CurlSegPath(I, K) + '.more');
  end;
end;

{ מחבר את הקטעים לפי הסדר לתוך איבר 0, ומוחק כל קטע מיד אחרי שהתווסף — שיא הדיסק
  הוא הקובץ ועוד קטע אחד. עצירה באמצע משאירה תחילית תקינה והקטע שלם. }
function CurlJoinSegments(): Integer;
var
  K: Integer;
begin
  Result := CurlDone;
  for K := 1 to GetArrayLength(SegFile) - 1 do
  begin
    Result := CurlAppend(SegFile[0], SegFile[K], True);
    if Result <> CurlDone then
      exit;
    CurlSetJoinPending(CurlJoinPending - CurlSegLen(K));
  end;
end;

{ ============================ פריט בתור ============================ }

{ נעילה בלעדית לכל משך הפריט: שני מסייעים לעולם אינם כותבים לאותם קבצים חלקיים.
  1 — ננעל; 0 — מסייע אחר מחזיק אותה; ‎-1‎ — אי אפשר ליצור אותה בכלל. }
function CurlTryLock(I: Integer): Integer;
var
  Err: LongWord;
begin
  { GENERIC_READ | GENERIC_WRITE, בלי שיתוף, OPEN_ALWAYS, FILE_FLAG_DELETE_ON_CLOSE }
  CurlLockHandle := CurlCreateFile(CachePath(QueueFile[I]) + '.partial.lock', $C0000000, 0, 0, 4,
    $04000080, 0);
  if CurlLockHandle <> -1 then
  begin
    Result := 1;
    exit;
  end;
  Err := DLLGetLastError();
  CurlLockHandle := 0;
  { ERROR_SHARING_VIOLATION }
  if Err = 32 then
    Result := 0
  else
  begin
    Log('DownloadAssistant: cannot lock ' + QueueFile[I] + ': ' + SysErrorMessage(Err));
    Result := -1;
  end;
end;

procedure CurlUnlock();
begin
  if CurlLockHandle = 0 then
    exit;
  UiCloseHandle(CurlLockHandle);
  CurlLockHandle := 0;
end;

{ אחרי הורדה של Inno הקבצים החלקיים של אותו נכס מיותרים — אלא אם מסייע אחר עובד עליהם. }
procedure CurlForgetItem(I: Integer);
begin
  if CurlTryLock(I) <> 1 then
    exit;
  CurlDropPartials(QueueFile[I], '');
  CurlUnlock();
end;

{ ההורדה עצמה, כשהנעילה כבר בידינו. }
function CurlFetchLocked(I: Integer): Integer;
var
  Whole: String;
  N, Outcome, Range, Probes: Integer;
  Restarted, ForceSingle, HashOk: Boolean;
  Started: Int64;
begin
  Whole := CurlWholePath(I);
  CurlDropPartials(QueueFile[I], ExtractFileName(CurlBase(I)) + '.');
  Restarted := False;
  ForceSingle := False;
  while True do
  begin
    N := 1;
    if not ForceSingle and not Restarted and (QueueSize[I] >= SegmentMinSize) then
    begin
      Range := CurlProbeRange(I);
      Probes := 1;
      { בדיקה שלא קיבלה תשובה מנוסה שוב: אחרת קטעים מריצה קודמת היו נזנחים. }
      while (Range < 0) and (Probes < 3) and not StopRequested do
      begin
        CurlPause(2000);
        if StopRequested then
          Break;
        Range := CurlProbeRange(I);
        Probes := Probes + 1;
      end;
      if StopRequested then
      begin
        Result := CurlStopped(I);
        exit;
      end;
      { קבצים חלקיים מריצה קודמת הוכיחו שהשרת נגיש; Inno היה מוריד מאפס. }
      if (Range < 0) and not CurlProven and not CurlGridSegExists(I) and
         (CurlSize(CurlWholePath(I)) = 0) then
      begin
        Log('DownloadAssistant: curl cannot reach ' + QueueFile[I] +
          ', falling back to the Inno downloader');
        CurlState := -1;
        Result := CurlFallback;
        exit;
      end;
      { קטעים שכבר קיימים הוכיחו ש-Range עובד כאן. }
      if (Range = 1) or ((Range < 0) and CurlGridSegExists(I)) then
        N := SegmentsPerFile
      else if Range = 0 then
        Log('DownloadAssistant: the server ignores Range, one connection for ' + QueueFile[I]);
      if Range = 0 then
      begin
        if not CurlAbsorb(I) then
        begin
          Result := CurlFailed;
          LoadErrorMsg := CustomMessage('ErrorDownloadDamaged');
          LoadErrorTech := 'cannot join the segments of ' + QueueFile[I];
          exit;
        end;
        CurlDropSegments(I);
      end;
    end;
    if not CurlAbsorb(I) then
    begin
      Result := CurlFailed;
      LoadErrorMsg := CustomMessage('ErrorDownloadDamaged');
      LoadErrorTech := 'cannot join the segments of ' + QueueFile[I];
      exit;
    end;
    CurlPlanSegments(I, N);
    Outcome := CurlRunSegments(I);
    if Outcome = CurlStoppedByUser then
    begin
      Result := CurlStopped(I);
      exit;
    end;
    if Outcome = CurlSingle then
    begin
      Log('DownloadAssistant: continuing ' + QueueFile[I] + ' in one connection');
      ForceSingle := True;
      Continue;
    end;
    if Outcome <> CurlDone then
    begin
      Result := Outcome;
      exit;
    end;

    { החיבור וה-hash נכללים בהערכה; בזמנם מוצג רק שם השלב, כי ה-hash חוסם את התצוגה. }
    VerifyStartTick := NowMs();
    CurrentProgress := QueueSize[I];
    ShowDownloadStatus();
    Log('DownloadAssistant: ' + QueueFile[I] + ' received by curl, joining and verifying');
    Outcome := CurlJoinSegments();
    if Outcome = CurlStoppedByUser then
    begin
      Result := CurlStopped(I);
      exit;
    end;
    if Outcome <> CurlDone then
    begin
      LoadErrorMsg := CustomMessage('ErrorDownloadDamaged');
      LoadErrorTech := 'cannot join the segments of ' + QueueFile[I];
      Result := CurlFailed;
      exit;
    end;
    HashOk := CurlSize(Whole) = QueueSize[I];
    if HashOk then
    begin
      UiUpdateProgress();
      WizardForm.Update;
      Started := NowMs();
      HashOk := HashFile(Whole) = Lowercase(QueueSha[I]);
      HashMsMeasured := HashMsMeasured + NowMs() - Started;
      HashBytesMeasured := HashBytesMeasured + QueueSize[I];
    end;
    HoldShownEta(True);
    VerifyStartTick := 0;
    { עצירה שנלחצה בזמן ה-hash מגיעה רק כשהחלון מעבד הודעות שוב. }
    DownloadPage.SetProgress(DownloadPage.ProgressBar.Position, DownloadPage.ProgressBar.Max);
    if HashOk then
    begin
      if not PromoteToCache(Whole, QueueFile[I], QueueSize[I], QueueSha[I]) then
      begin
        LoadErrorMsg := CustomMessage('ErrorDownloadDamaged');
        LoadErrorTech := 'cannot move ' + QueueFile[I] + ' into the cache';
        Result := CurlFailed;
        exit;
      end;
      CurlDropPartials(QueueFile[I], '');
      if StopRequested then
        Result := CurlStopped(I)
      else
        Result := CurlDone;
      exit;
    end;
    { hash שגוי: הכול נמחק, וניסיון נקי אחד מבית 0 בחיבור אחד. }
    DeleteFile(Whole);
    CurlDropSegments(I);
    if Restarted then
    begin
      LoadErrorMsg := CustomMessage('ErrorDownloadDamaged');
      LoadErrorTech := QueueFile[I] + ': sha256 mismatch after a clean download';
      Result := CurlFailed;
      exit;
    end;
    if StopRequested then
    begin
      Result := CurlStopped(I);
      exit;
    end;
    Log('DownloadAssistant: ' + QueueFile[I] + ' sha256 mismatch, downloading again from 0');
    Restarted := True;
  end;
end;

{ CurlDone — הקובץ אומת ונכנס למטמון. CurlFailed — LoadErrorMsg נקבע (גם בעצירה).
  CurlFallback — הפריט יורד בעמוד ההורדה של Inno. }
function CurlDownloadItem(I: Integer): Integer;
var
  Lock: Integer;
  Waiting: Boolean;
  Free, Total: Int64;
begin
  Result := CurlFallback;
  if not CurlReady() then
    exit;
  ForceDirectories(CacheDir());
  CurlGained := False;
  { נעילה, בדיקת Range והכנת הקטעים אינם רשת: המעריך מושהה עד שהקטעים רצים. }
  SpeedPause();
  CurrentProgress := 0;
  CurrentFileSize := QueueSize[I];
  DownloadPage.SetProgress(ProgressDone div 1024, ProgressTotal div 1024);
  Waiting := False;
  Lock := CurlTryLock(I);
  while Lock = 0 do
  begin
    if not Waiting then
    begin
      Log('DownloadAssistant: ' + QueueFile[I] + ' is being downloaded by another assistant, waiting');
      DownloadPage.SetText(Msg1('WaitingForOtherAssistant', QueueLabel[I]), '');
    end;
    Waiting := True;
    CurlPause(3000);
    if StopRequested then
    begin
      CurlStopped(I);
      Result := CurlFailed;
      exit;
    end;
    Lock := CurlTryLock(I);
  end;
  if Lock < 0 then
    exit;
  try
    { מסייע אחר שסיים בזמן שחיכינו כבר הכניס את הקובץ למטמון. }
    if Waiting and CachedFileIsGood(QueueFile[I], QueueSize[I], QueueSha[I]) then
    begin
      Log('DownloadAssistant: ' + QueueFile[I] + ' was completed by another assistant');
      Result := CurlDone;
      exit;
    end;
    Result := CurlFetchLocked(I);
    if Result = CurlStoppedByUser then
      Result := CurlFailed;
    { Inno מוריד לתיקייה הזמנית מאפס: בדיסק צפוף הקבצים החלקיים מפנים לו מקום. }
    if (Result = CurlFallback) and GetSpaceOnDisk64(CacheDir(), Free, Total) and
       (Free < QueueSize[I] + SegmentMinSize) then
    begin
      Log('DownloadAssistant: low disk space, discarding the curl partials of ' + QueueFile[I]);
      CurlDropPartials(QueueFile[I], '');
    end;
  finally
    CurlUnlock();
    CurlSetJoinPending(0);
    CurrentProgress := 0;
    VerifyStartTick := 0;
  end;
end;
