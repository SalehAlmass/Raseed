
import 'package:equatable/equatable.dart';
import '../../../core/models/report_models.dart';

abstract class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  final DashboardReport report;
  final ReportFilter filter;

  const ReportsLoaded(this.report, this.filter);

  @override
  List<Object?> get props => [report, filter];
}

class ReportsError extends ReportsState {
  final String message;
  const ReportsError(this.message);

  @override
  List<Object?> get props => [message];
}
