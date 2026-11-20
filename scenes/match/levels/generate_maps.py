"""Parameterized geometry-only parkour level generator for Godot 4.

Levels contain Geometry + SpawnPoints only. The match shell
(res://scenes/match/match.tscn) loads them at runtime.

Usage:
  python generate_maps.py              # write non-frozen presets
  python generate_maps.py parkour2
  python generate_maps.py parkour1 --force  # overwrites frozen map
  python generate_maps.py --list
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent


@dataclass(frozen=True)
class MapConfig:
	name: str
	display_name: str
	uid: str
	frozen: bool = False
	ground_size: float = 72.0
	rim_height: float = 2.2
	plaza_distance: float = 22.0
	plaza_size: float = 12.0
	mid_height: float = 3.0
	high_height: float = 7.5
	nest_height: float = 9.5
	high_pad_size: float = 5.5
	center_pad_size: float = 14.0
	center_cover_size: float = 1.6
	dj_inner_distance: float = 11.0
	dj_inner_height: float = 4.8
	dj_corner_distance: float = 8.0
	dj_corner_height: float = 5.5
	mast_scale: float = 1.15
	mast_height: float = 14.0
	mast_head_height: float = 12.5
	mast_mid_height: float = 6.5
	enable_tunnels: bool = True
	enable_slides: bool = True
	enable_dj_pads: bool = True
	enable_masts: bool = True
	color_ground: tuple[float, float, float] = (0.28, 0.32, 0.30)
	color_plaza: tuple[float, float, float] = (0.40, 0.44, 0.50)
	color_ramp: tuple[float, float, float] = (0.62, 0.55, 0.35)
	color_dj: tuple[float, float, float] = (0.35, 0.55, 0.70)
	color_high: tuple[float, float, float] = (0.55, 0.40, 0.45)
	color_mast_head: tuple[float, float, float] = (0.85, 0.70, 0.25)
	color_spawn: tuple[float, float, float] = (0.35, 0.55, 0.35)


PRESETS: dict[str, MapConfig] = {
	"parkour1": MapConfig(
		name="parkour1",
		display_name="Parkour 1 - Courtyard",
		uid="uid://bparkour1arena01",
		frozen=True,
	),
	"parkour2": MapConfig(
		name="parkour2",
		display_name="Parkour 2 - High Spire",
		uid="uid://bparkour2arena02",
		ground_size=64.0,
		plaza_distance=18.0,
		plaza_size=10.0,
		mid_height=3.2,
		high_height=9.0,
		nest_height=11.5,
		high_pad_size=5.0,
		center_pad_size=12.0,
		dj_inner_distance=9.5,
		dj_inner_height=5.2,
		dj_corner_distance=7.0,
		dj_corner_height=6.2,
		mast_height=16.0,
		mast_head_height=14.5,
		mast_mid_height=7.5,
		color_ground=(0.22, 0.26, 0.32),
		color_plaza=(0.38, 0.42, 0.55),
		color_ramp=(0.70, 0.50, 0.35),
		color_dj=(0.45, 0.40, 0.75),
		color_high=(0.50, 0.35, 0.55),
		color_mast_head=(0.95, 0.80, 0.35),
		color_spawn=(0.40, 0.55, 0.45),
	),
}


class ArenaBuilder:
	def __init__(self, cfg: MapConfig) -> None:
		self.cfg = cfg
		self.boxes: list[tuple] = []
		self.spawns: list[tuple[float, float, float]] = []

	def add(
		self,
		name: str,
		x: float,
		y_bottom: float,
		z: float,
		sx: float,
		sy: float,
		sz: float,
		color: tuple[float, float, float],
	) -> None:
		self.boxes.append((name, x, y_bottom + sy * 0.5, z, sx, sy, sz, *color))

	def build(self) -> list[tuple]:
		c = self.cfg
		half = c.ground_size * 0.5
		rim = half

		self.add("Ground", 0, -0.5, 0, c.ground_size, 1, c.ground_size, c.color_ground)
		for i, (x, z) in enumerate([(0, rim), (0, -rim), (rim, 0), (-rim, 0)]):
			sx, sz = (c.ground_size + 2, 4) if abs(z) > abs(x) else (4, c.ground_size + 2)
			self.add(f"Rim{i}", x, 0, z, sx, c.rim_height, sz, (0.22, 0.24, 0.26))

		self.add("CenterPad", 0, 0, 0, c.center_pad_size, 0.4, c.center_pad_size, (0.55, 0.42, 0.28))
		cover_off = c.center_pad_size * 0.25
		for i, (x, z) in enumerate(
			[(-cover_off, -cover_off), (cover_off, -cover_off), (-cover_off, cover_off), (cover_off, cover_off)]
		):
			self.add(
				f"CenterCover{i}",
				x,
				0.4,
				z,
				c.center_cover_size,
				1.4,
				c.center_cover_size,
				(0.50, 0.35, 0.25),
			)

		cardinals = {
			"N": (0.0, c.plaza_distance),
			"E": (c.plaza_distance, 0.0),
			"S": (0.0, -c.plaza_distance),
			"W": (-c.plaza_distance, 0.0),
		}
		step_ys = [
			c.mid_height * 0.17,
			c.mid_height * 0.37,
			c.mid_height * 0.57,
			c.mid_height * 0.77,
		]
		inner = c.plaza_distance - c.plaza_size * 0.5 - 1.5

		for tag, (cx, cz) in cardinals.items():
			self.add(f"Plaza{tag}", cx, 0, cz, c.plaza_size, c.mid_height, c.plaza_size, c.color_plaza)
			if tag == "N":
				for step, y in enumerate(step_ys):
					self.add(f"Ramp{tag}Step{step}", 0, y, inner + step * 1.6, 4.0, 0.45, 2.0, c.color_ramp)
			elif tag == "S":
				for step, y in enumerate(step_ys):
					self.add(f"Ramp{tag}Step{step}", 0, y, -inner - step * 1.6, 4.0, 0.45, 2.0, c.color_ramp)
			elif tag == "E":
				for step, y in enumerate(step_ys):
					self.add(f"Ramp{tag}Step{step}", inner + step * 1.6, y, 0, 2.0, 0.45, 4.0, c.color_ramp)
			else:
				for step, y in enumerate(step_ys):
					self.add(f"Ramp{tag}Step{step}", -inner - step * 1.6, y, 0, 2.0, 0.45, 4.0, c.color_ramp)

		corner_d = c.plaza_distance * 0.70
		corners = {
			"NE": (corner_d, corner_d),
			"SE": (corner_d, -corner_d),
			"SW": (-corner_d, -corner_d),
			"NW": (-corner_d, corner_d),
		}
		for tag, (cx, cz) in corners.items():
			self.add(f"BridgePad{tag}", cx, c.mid_height, cz, 6.0, 0.5, 6.0, (0.42, 0.46, 0.52))

		bridge_y = c.mid_height
		bridge_mid = (c.plaza_distance + corner_d) * 0.5
		self.add("Bridge_N_to_NE", 7.5, bridge_y, bridge_mid, 9.0, 0.45, 3.0, (0.48, 0.50, 0.55))
		self.add("Bridge_N_to_NW", -7.5, bridge_y, bridge_mid, 9.0, 0.45, 3.0, (0.48, 0.50, 0.55))
		self.add("Bridge_S_to_SE", 7.5, bridge_y, -bridge_mid, 9.0, 0.45, 3.0, (0.48, 0.50, 0.55))
		self.add("Bridge_S_to_SW", -7.5, bridge_y, -bridge_mid, 9.0, 0.45, 3.0, (0.48, 0.50, 0.55))
		self.add("Bridge_E_to_NE", bridge_mid, bridge_y, 7.5, 3.0, 0.45, 9.0, (0.48, 0.50, 0.55))
		self.add("Bridge_E_to_SE", bridge_mid, bridge_y, -7.5, 3.0, 0.45, 9.0, (0.48, 0.50, 0.55))
		self.add("Bridge_W_to_NW", -bridge_mid, bridge_y, 7.5, 3.0, 0.45, 9.0, (0.48, 0.50, 0.55))
		self.add("Bridge_W_to_SW", -bridge_mid, bridge_y, -7.5, 3.0, 0.45, 9.0, (0.48, 0.50, 0.55))

		if c.enable_dj_pads:
			for i, (x, z) in enumerate(
				[(0, c.dj_inner_distance), (0, -c.dj_inner_distance), (c.dj_inner_distance, 0), (-c.dj_inner_distance, 0)]
			):
				self.add(f"DJPad{i}", x, c.dj_inner_height, z, 3.2, 0.4, 3.2, c.color_dj)
			for i, (x, z) in enumerate(
				[
					(c.dj_corner_distance, c.dj_corner_distance),
					(-c.dj_corner_distance, c.dj_corner_distance),
					(c.dj_corner_distance, -c.dj_corner_distance),
					(-c.dj_corner_distance, -c.dj_corner_distance),
				]
			):
				self.add(f"DJCorner{i}", x, c.dj_corner_height, z, 2.8, 0.4, 2.8, c.color_dj)

		for tag, (cx, cz) in corners.items():
			self.add(f"HighPad{tag}", cx, c.high_height, cz, c.high_pad_size, 0.5, c.high_pad_size, c.color_high)
			for step in range(5):
				y = c.mid_height + 0.5 + step * ((c.high_height - c.mid_height) / 5.0)
				ox = 0.9 * (1 if cx > 0 else -1) * step
				oz = 0.9 * (1 if cz > 0 else -1) * step
				self.add(
					f"HighStair{tag}_{step}",
					cx - ox * 0.35,
					y,
					cz - oz * 0.35,
					2.4,
					0.4,
					2.4,
					c.color_ramp,
				)

		self.add("HighBridge_N", 0, c.high_height, corner_d, corner_d * 2 + 2, 0.4, 2.2, c.color_high)
		self.add("HighBridge_S", 0, c.high_height, -corner_d, corner_d * 2 + 2, 0.4, 2.2, c.color_high)
		self.add("HighBridge_E", corner_d, c.high_height, 0, 2.2, 0.4, corner_d * 2 + 2, c.color_high)
		self.add("HighBridge_W", -corner_d, c.high_height, 0, 2.2, 0.4, corner_d * 2 + 2, c.color_high)

		self.add("CrowsNest", 0, c.nest_height, 0, 6.0, 0.5, 6.0, (0.75, 0.55, 0.30))
		nest_steps = 4
		for step in range(nest_steps):
			t = step / max(nest_steps - 1, 1)
			y = c.high_height + 0.4 + t * (c.nest_height - c.high_height - 0.2)
			z = corner_d * 0.65 - step * (corner_d * 0.65 / nest_steps)
			self.add(f"NestStairN{step}", 0, y, z, 2.5, 0.35, 2.2, c.color_ramp)

		if c.enable_masts:
			for tag, (cx, cz) in cardinals.items():
				mx, mz = cx * c.mast_scale, cz * c.mast_scale
				self.add(f"Mast{tag}", mx, 0, mz, 1.2, c.mast_height, 1.2, (0.25, 0.25, 0.28))
				self.add(f"MastHead{tag}", mx, c.mast_head_height, mz, 3.0, 1.5, 3.0, c.color_mast_head)
				self.add(f"MastMid{tag}", mx, c.mast_mid_height, mz, 3.5, 0.5, 3.5, c.color_mast_head)

		if c.enable_tunnels:
			tunnel_len = c.plaza_distance * 0.9
			self.add("TunnelNS_Roof", 0, 2.2, 0, 4.5, 0.4, tunnel_len, (0.25, 0.27, 0.30))
			self.add("TunnelNS_W", -2.5, 0, 0, 0.5, 2.2, tunnel_len, (0.25, 0.27, 0.30))
			self.add("TunnelNS_E", 2.5, 0, 0, 0.5, 2.2, tunnel_len, (0.25, 0.27, 0.30))
			self.add("TunnelEW_Roof", 0, 2.2, 0, tunnel_len, 0.4, 4.5, (0.25, 0.27, 0.30))
			self.add("TunnelEW_N", 0, 0, 2.5, tunnel_len, 2.2, 0.5, (0.25, 0.27, 0.30))
			self.add("TunnelEW_S", 0, 0, -2.5, tunnel_len, 2.2, 0.5, (0.25, 0.27, 0.30))

		if c.enable_slides:
			slide_color = (0.55, 0.70, 0.40)
			for tag, (cx, cz) in cardinals.items():
				base = c.plaza_distance * 0.65
				for step, y in enumerate(
					[c.mid_height * 0.8, c.mid_height * 0.6, c.mid_height * 0.4, c.mid_height * 0.2]
				):
					if tag == "N":
						self.add(f"Slide{tag}{step}", 4.5, y, base - step * 2.2, 2.5, 0.35, 2.5, slide_color)
					elif tag == "S":
						self.add(f"Slide{tag}{step}", -4.5, y, -base + step * 2.2, 2.5, 0.35, 2.5, slide_color)
					elif tag == "E":
						self.add(f"Slide{tag}{step}", base - step * 2.2, y, 4.5, 2.5, 0.35, 2.5, slide_color)
					else:
						self.add(f"Slide{tag}{step}", -base + step * 2.2, y, -4.5, 2.5, 0.35, 2.5, slide_color)

		ledge_off = c.plaza_size * 0.55
		for tag, (cx, cz) in cardinals.items():
			if tag in ("N", "S"):
				self.add(
					f"Ledge{tag}",
					cx,
					c.mid_height,
					cz + (ledge_off if tag == "N" else -ledge_off),
					8.0,
					1.0,
					1.2,
					(0.45, 0.48, 0.40),
				)
			else:
				self.add(
					f"Ledge{tag}",
					cx + (ledge_off if tag == "E" else -ledge_off),
					c.mid_height,
					cz,
					1.2,
					1.0,
					8.0,
					(0.45, 0.48, 0.40),
				)

		spawn_r = half - 12.0
		self.spawns = [
			(-spawn_r, 0.1, spawn_r),
			(spawn_r, 0.1, spawn_r),
			(spawn_r, 0.1, -spawn_r),
			(-spawn_r, 0.1, -spawn_r),
		]
		for i, (x, _y, z) in enumerate(self.spawns):
			self.add(f"SpawnPad{i}", x, 0, z, 4.0, 0.3, 4.0, c.color_spawn)

		return self.boxes


def write_scene(cfg: MapConfig) -> Path:
	builder = ArenaBuilder(cfg)
	boxes = builder.build()
	spawns = builder.spawns
	out = OUT_DIR / f"{cfg.name}.tscn"

	lines: list[str] = []
	lines.append(f'[gd_scene format=3 uid="{cfg.uid}"]')
	lines.append("")

	for i, (_name, _x, _y, _z, sx, sy, sz, r, g, b) in enumerate(boxes):
		lines.append(f'[sub_resource type="BoxShape3D" id="BoxShape_{i}"]')
		lines.append(f"size = Vector3({sx}, {sy}, {sz})")
		lines.append("")
		lines.append(f'[sub_resource type="BoxMesh" id="BoxMesh_{i}"]')
		lines.append(f"size = Vector3({sx}, {sy}, {sz})")
		lines.append("")
		lines.append(f'[sub_resource type="StandardMaterial3D" id="Mat_{i}"]')
		lines.append(f"albedo_color = Color({r}, {g}, {b}, 1)")
		lines.append("roughness = 0.85")
		lines.append("")

	# Geometry-only root (loaded by match.tscn)
	lines.append(f'[node name="{cfg.name}" type="Node3D"]')
	lines.append("")
	lines.append('[node name="Geometry" type="Node3D" parent="."]')
	lines.append("")

	for i, (name, x, y, z, _sx, _sy, _sz, _r, _g, _b) in enumerate(boxes):
		lines.append(f'[node name="{name}" type="StaticBody3D" parent="Geometry"]')
		lines.append(f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})")
		lines.append("")
		lines.append(f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Geometry/{name}"]')
		lines.append(f'shape = SubResource("BoxShape_{i}")')
		lines.append("")
		lines.append(f'[node name="MeshInstance3D" type="MeshInstance3D" parent="Geometry/{name}"]')
		lines.append(f'mesh = SubResource("BoxMesh_{i}")')
		lines.append(f'surface_material_override/0 = SubResource("Mat_{i}")')
		lines.append("")

	lines.append('[node name="SpawnPoints" type="Node3D" parent="."]')
	lines.append("")
	for i, (x, y, z) in enumerate(spawns):
		lines.append(f'[node name="Spawn{i}" type="Marker3D" parent="SpawnPoints"]')
		lines.append(f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})")
		lines.append("")

	out.write_text("\n".join(lines), encoding="utf-8")
	return out


def main() -> None:
	parser = argparse.ArgumentParser(description="Generate geometry-only parkour level .tscn files")
	parser.add_argument("maps", nargs="*", help="Preset names (default: all non-frozen)")
	parser.add_argument("--list", action="store_true", help="List presets and exit")
	parser.add_argument("--force", action="store_true", help="Allow overwriting frozen maps")
	args = parser.parse_args()

	if args.list:
		for key, cfg in PRESETS.items():
			flag = " [FROZEN]" if cfg.frozen else ""
			print(f"{key}: {cfg.display_name}{flag}")
		return

	names = args.maps or [key for key, cfg in PRESETS.items() if not cfg.frozen]
	if not names:
		print("Nothing to write.")
		return

	for name in names:
		if name not in PRESETS:
			raise SystemExit(f"Unknown preset '{name}'. Use --list.")
		cfg = PRESETS[name]
		if cfg.frozen and not args.force:
			print(f"Skipped {name} (frozen). Pass --force to overwrite.")
			continue
		path = write_scene(cfg)
		print(f"Wrote {path} ({cfg.display_name})")


if __name__ == "__main__":
	main()
