class_name DashHud
extends CanvasLayer


@onready var charges_label: Label = (
	$MarginContainer/PanelContainer/VBoxContainer/ChargesLabel
)

@onready var charge_bar: ProgressBar = (
	$MarginContainer/PanelContainer/VBoxContainer/ChargeBar
)


var _dash: DashController


func bind(dash: DashController) -> void:
	_dash = dash

	if not _dash.meter_changed.is_connected(
		_on_meter_changed
	):
		_dash.meter_changed.connect(
			_on_meter_changed
		)

	_on_meter_changed(
		_dash.meter_value(),
		float(_dash.max_charges),
		_dash.max_charges
	)


func _on_meter_changed(
	value: float,
	maximum: float,
	whole_charges: int
) -> void:

	charge_bar.max_value = maximum
	charge_bar.value = value

	charges_label.text = (
		"DASH  %d / %d"
		% [
			whole_charges,
			int(maximum)
		]
	)
