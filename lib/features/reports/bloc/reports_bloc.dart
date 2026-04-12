
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/report_service.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final ReportService _reportService;

  ReportsBloc(this._reportService) : super(ReportsInitial()) {
    on<LoadReportsEvent>((event, emit) async {
      emit(ReportsLoading());
      try {
        final report = await _reportService.getDashboardReport(event.filter);
        emit(ReportsLoaded(report, event.filter));
      } catch (e) {
        emit(ReportsError(e.toString()));
      }
    });

    on<ChangeFilterEvent>((event, emit) async {
      add(LoadReportsEvent(event.filter));
    });
  }
}
