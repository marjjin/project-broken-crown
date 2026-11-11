class_name RuntimeNavigationRegion
extends NavigationRegion3D
## Bakes its navigation mesh from its children's static colliders when the
## level loads, so test levels stay in sync with their geometry without a
## manual bake step. Put walkable/blocking geometry as children of this node.
##
## For large final levels, bake in the editor instead and disable `bake_on_ready`.

@export var bake_on_ready: bool = true


func _ready() -> void:
	if navigation_mesh == null:
		push_error("RuntimeNavigationRegion '%s': no NavigationMesh assigned; enemies cannot navigate." % get_path())
		return
	if bake_on_ready:
		# Synchronous: the level is small and enemies need the mesh right away.
		bake_navigation_mesh(false)
		if navigation_mesh.get_polygon_count() == 0:
			push_error("RuntimeNavigationRegion '%s': bake produced no polygons; check that children are StaticBody3D on the parsed collision mask." % get_path())
