class_name Inscription
extends Node3D
## Readable lore: interacting shows its text through GameSession's
## notification banner. Also used for points of interest (e.g. the empty
## weapon altar that a later phase will fill).

@export var interactable: Interactable
@export var title: String = "Inscripción"
@export_multiline var text: String = ""


func _ready() -> void:
	if interactable == null:
		push_error("Inscription '%s': no interactable assigned." % get_path())
		return
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_interactor: Node) -> void:
	GameSessionState.instance().notify(title, text)
