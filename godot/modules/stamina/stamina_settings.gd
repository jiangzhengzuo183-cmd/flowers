extends Resource
## One shared balance sheet. Scene/player instances may override it in the Inspector.
@export_range(1.0, 1000.0, 1.0) var maximum: float = 100.0
@export_range(0.0, 1000.0, 0.1) var sprint_cost_per_second: float = 18.0
@export_range(0.0, 1000.0, 0.1) var recovery_per_second: float = 14.0
@export_range(0.0, 1000.0, 0.1) var recovery_delay: float = 0.9
@export_range(0.0, 1000.0, 0.1) var exhausted_restart: float = 20.0
@export_range(0.0, 1000.0, 0.1) var zone_recovery_per_second: float = 35.0
@export_range(0.0, 1000.0, 0.1) var zone_recovery_delay: float = 0.15
@export_range(0.0, 1000.0, 0.1) var cake_restore: float = 45.0
@export_range(0.0, 1000.0, 0.1) var barrier_restore: float = 30.0
