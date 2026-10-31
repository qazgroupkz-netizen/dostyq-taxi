/// Тестовые кнопки (ручная машина на карте, демо-поездка). Перед запуском — false.
const kTestMode = true;

/// Название сервиса. Районы (Достык, Ушарал…) показываются отдельно, под ним.
const kBrand = 'ALAKOL TAXI';

/// Своя база в Казахстане (Supabase на alakoltaxi.kz) — основная с 31.10.2026.
/// Старая версия на Firebase: сборка с `--dart-define=SUPABASE=false`.
const kUseSupabase = bool.fromEnvironment('SUPABASE', defaultValue: true);

const kSupabaseUrl = 'https://alakoltaxi.kz';

/// Публичный ключ (anon): его видит любой браузер, права задают правила базы (RLS).
const kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzkzNDI0MDc4LCJleHAiOjE5NTExMDQwNzh9.QepOanT7tsqFeHw8OMjucWzRdkXAN5KZWPeE4H-zvec';
