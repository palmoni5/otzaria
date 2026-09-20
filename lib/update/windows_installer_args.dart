/// ארגומנטים למתקין בהתקנת per-user: /SILENT ישירות (ללא הסלמה), כדי
/// לדלג על ה-self-relaunch של המתקין. /NOLAUNCH=1 מונע פתיחה מחדש של אוצריא
/// (בעת סגירת התוכנה).
String perUserSilentInstallerArguments({required bool relaunchApp}) {
  const base = '/SILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER';
  return relaunchApp ? base : '$base /NOLAUNCH=1';
}

/// בונה שורת פקודה ל-CreateProcessW: כל ארגומנט בגרשיים כפולים, כדי שנתיב
/// עם רווח (למשל `C:\Program Files`) לא יתפצל לשני ארגומנטים.
String windowsCommandLine(String executablePath, List<String> arguments) => [
  '"$executablePath"',
  for (final argument in arguments) '"${argument.replaceAll('"', r'\"')}"',
].join(' ');
