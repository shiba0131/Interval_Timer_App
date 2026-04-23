import 'package:flutter/material.dart';

import 'src/data/repositories/pinpon_repository.dart';
import 'src/features/analysis/analysis_screen.dart';
import 'src/features/history/history_screen.dart';
import 'src/features/register/register_match_screen.dart';

void main() {
  runApp(const PinponRecordApp());
}

class PinponRecordApp extends StatelessWidget {
  const PinponRecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0D1B2A);
    const teal = Color(0xFF1B9AAA);
    const coral = Color(0xFFE76F51);
    const mist = Color(0xFFF4F7FB);

    return MaterialApp(
      title: 'ピンポンの記録',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          brightness: Brightness.light,
        ).copyWith(
          primary: navy,
          secondary: teal,
          tertiary: coral,
          error: coral,
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFE6EDF5),
          onSurface: const Color(0xFF112033),
          onSurfaceVariant: const Color(0xFF546375),
          outlineVariant: const Color(0xFFD5DEE8),
        ),
        scaffoldBackgroundColor: mist,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.92),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFD7E0EA)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: navy,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD4DEE8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: teal, width: 1.6),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF546375),
            fontWeight: FontWeight.w600,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: navy,
            minimumSize: const Size.fromHeight(54),
            side: const BorderSide(color: Color(0xFFC7D3E0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        checkboxTheme: const CheckboxThemeData(
          side: BorderSide(color: Color(0xFF9AA9BA)),
        ),
      ),
      home: const PinponHomePage(),
    );
  }
}

class PinponHomePage extends StatefulWidget {
  const PinponHomePage({super.key});

  @override
  State<PinponHomePage> createState() => _PinponHomePageState();
}

class _PinponHomePageState extends State<PinponHomePage> {
  final PinponRepository _repository = PinponRepository();
  final ValueNotifier<int> _dataVersion = ValueNotifier<int>(0);

  @override
  void dispose() {
    _dataVersion.dispose();
    super.dispose();
  }

  void _notifyDataChanged() {
    _dataVersion.value += 1;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF08131F),
                  Color(0xFF10253E),
                  Color(0xFF16324F),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ピンポンの記録'),
              SizedBox(height: 2),
              Text(
                'Tournament Dashboard',
                style: TextStyle(
                  color: Color(0xFF95D5E1),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            indicator: BoxDecoration(
              color: Color(0xFF1B9AAA),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFA9BED3),
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              Tab(text: '履歴'),
              Tab(text: '分析'),
              Tab(text: '登録'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF4F7FB),
                Color(0xFFEDF3F9),
                Color(0xFFF8FBFD),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B9AAA).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -60,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE76F51).withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              TabBarView(
                children: [
                  HistoryScreen(
                    repository: _repository,
                    refreshSignal: _dataVersion,
                    onDataChanged: _notifyDataChanged,
                  ),
                  AnalysisScreen(
                    repository: _repository,
                    refreshSignal: _dataVersion,
                  ),
                  RegisterMatchScreen(
                    repository: _repository,
                    onDataChanged: _notifyDataChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
