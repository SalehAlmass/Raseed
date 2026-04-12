
import 'package:equatable/equatable.dart';
import '../../../core/models/report_models.dart';

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class LoadReportsEvent extends ReportsEvent {
  final ReportFilter filter;
  const LoadReportsEvent(this.filter);

  @override
  List<Object?> get props => [filter];
}

class ChangeFilterEvent extends ReportsEvent {
  final ReportFilter filter;
  const ChangeFilterEvent(this.filter);

  @override
  List<Object?> get props => [filter];
}
