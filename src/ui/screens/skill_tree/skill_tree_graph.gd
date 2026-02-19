extends Control

var edges: Array = []

func set_edges(new_edges: Array) -> void:
    edges = new_edges
    queue_redraw()

func _draw() -> void:
    for edge in edges:
        if typeof(edge) != TYPE_DICTIONARY:
            continue
        var a: Vector2 = edge.get("from", Vector2.ZERO)
        var b: Vector2 = edge.get("to", Vector2.ZERO)
        draw_line(a, b, Color(0.6, 0.7, 0.9, 0.6), 2.0, true)
