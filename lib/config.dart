/// Тестовые кнопки (ручная машина на карте, демо-поездка). Перед запуском — false.
const kTestMode = true;

/// Название сервиса. Районы (Достык, Ушарал…) показываются отдельно, под ним.
const kBrand = 'ALAKOL TAXI';

/// Своя база в Казахстане (Supabase на alakoltaxi.kz) вместо Firebase.
/// Сборка с `--dart-define=SUPABASE=true` — версия /beta/ на время переезда.
const kUseSupabase = bool.fromEnvironment('SUPABASE');

const kSupabaseUrl = 'https://alakoltaxi.kz';

/// Публичный ключ (anon): его видит любой браузер, права задают правила базы (RLS).
const kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzkzNDI0MDc4LCJleHAiOjE5NTExMDQwNzh9.QepOanT7tsqFeHw8OMjucWzRdkXAN5KZWPeE4H-zvec';
